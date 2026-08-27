import Foundation
import SwiftData
import RithamCore

// The single facade through which every screening read and write passes.
//
// This store deliberately has no gating concept. An earlier design (D-05/D-06/D-13, superseded
// by D-14 — see `01-CONTEXT.md`) enforced a parental-consent gate at exactly this layer: a
// `ConsentGate` type, `.allows(_:)` checks on every accessor, and a `consentRequired` error.
// None of that machinery exists any more, and none of it should be reintroduced — even as an
// always-true stub. Per D-14, Ritham has a permanent 13+ age floor enforced at Q0, before a
// profile is ever created, so a stored `UserProfile` always belongs to a user who is already 13
// or older and gets full, identical access from the moment it exists. There is genuinely nothing
// left to gate (T-01-65) — every accessor below reads and writes the stored profile directly.
@MainActor
public final class HealthDataStore {
    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - Profile

    public func loadProfile() throws -> UserProfile {
        guard let profile = try fetchProfile() else {
            throw HealthDataStoreError.profileMissing
        }
        return profile
    }

    /// Creates or updates the stored profile from `draft`.
    ///
    /// `explanationRegister`/`dietaryPattern` follow "provide to set, `nil` to leave
    /// unchanged" semantics on an existing profile — a caller updating only the register (e.g.
    /// `ExplanationRegisterStepView`, plan 01-13) does not need to first reload and re-supply
    /// the dietary pattern just to avoid silently clearing it. The only way to clear either
    /// field back to unanswered is `invalidateSection`, never a `nil` here.
    ///
    /// Per MINOR-01, once a profile exists its owner already cleared the 13+ floor at
    /// onboarding, and this can never be undone later (e.g. a Settings edit): before writing to
    /// an *existing* profile, the incoming age is compared against the currently stored one — if
    /// it is under 13, this throws `ageBelowFloor` and writes nothing at all, not the age field,
    /// not any other field passed in the same call, so the stored profile is left completely
    /// untouched. This is a whole-update rejection, not a per-field silent drop.
    ///
    /// When no profile is stored yet (the very first write, from onboarding's age step), this
    /// check does not apply — a profile is created normally. `AgeStepView` (plan 01-13) is what
    /// keeps an ineligible value from ever reaching this call in the first place, by
    /// construction. Both mechanisms exist because they close different gaps: plan 01-13 stops
    /// an ineligible age from being submitted at all during onboarding, and this check stops a
    /// confirmed profile's age from being edited back down below the floor afterward (T-01-66).
    public func updateProfile(_ draft: UserProfileDraft) throws {
        let now = Date()

        if let existing = try fetchProfile() {
            guard draft.age >= 13 else {
                throw HealthDataStoreError.ageBelowFloor
            }
            existing.age = draft.age
            if let register = draft.explanationRegister {
                existing.explanationRegisterRaw = register.rawValue
            }
            if let dietaryPattern = draft.dietaryPattern {
                existing.dietaryPatternRaw = dietaryPattern.rawValue
            }
            existing.updatedAt = now
        } else {
            let profile = UserProfile(
                age: draft.age,
                explanationRegisterRaw: draft.explanationRegister?.rawValue,
                dietaryPatternRaw: draft.dietaryPattern?.rawValue,
                edScreenOutcomeRaw: nil,
                createdAt: now,
                updatedAt: now
            )
            context.insert(profile)
        }

        try context.save()
    }

    // MARK: - Screening result

    /// Persists the full resolved screening result: one `ConditionTagRecord` per tag in
    /// `result.matchedTags`, replacing whatever was previously stored — this call represents
    /// the complete resolved result for the current answer set, not a partial patch, matching
    /// how `GateResolution.resolve` itself is always called with the complete current
    /// `ScreeningAnswers`, never a delta. Replacing (rather than diffing) also means a tag's
    /// prior `professionalClearanceGrantedAt` is cleared on re-screen, which matches §1.6's "the
    /// toggle re-prompts at each re-screen point" — this is the mechanism that makes that true,
    /// not a data-loss side effect.
    ///
    /// Only the derived eating-disorder outcome is stored (`profile.edScreenOutcomeRaw`), never
    /// the five individual SCOFF answers — `answers` is accepted for signature/context but no
    /// field of it is ever written to the store; only `result.matchedTags` (already fully
    /// derived) is persisted.
    public func saveScreeningResult(
        _ result: GateResolutionResult,
        answers: ScreeningAnswers,
        now: Date
    ) throws {
        let profile = try loadProfile()

        let existingRecords = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        for record in existingRecords {
            context.delete(record)
        }
        for tag in result.matchedTags {
            context.insert(ConditionTagRecord(tagRaw: tag.rawValue, recordedAt: now))
        }

        if result.matchedTags.contains(.eatingDisorderPositiveScreen) {
            profile.edScreenOutcomeRaw = ConditionTag.eatingDisorderPositiveScreen.rawValue
        } else if result.matchedTags.contains(.eatingDisorderSelfReportedNegativeScreen) {
            profile.edScreenOutcomeRaw = ConditionTag.eatingDisorderSelfReportedNegativeScreen.rawValue
        } else {
            profile.edScreenOutcomeRaw = nil
        }
        profile.updatedAt = now

        try context.save()
    }

    // MARK: - Condition tags

    /// Every stored tag whose validity is `.active` or `.expiredStillApplied`. Per D-08, an
    /// overdue tag is still returned — filtering it out here would silently under-restrict a
    /// user past their re-screen date, which is a safety defect, not an optimization
    /// (T-01-61). `TagValidity` (RithamCore) offers no case that drops the restriction, so this
    /// switch is exhaustive and every case returns the tag; it is written explicitly (rather
    /// than skipping the switch) so this method's safety property stays visible at the call
    /// site, not just implied by the absence of a third case elsewhere.
    public func activeConditionTags(now: Date) throws -> [ConditionTag] {
        _ = try loadProfile()

        let records = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        return records.compactMap { record -> ConditionTag? in
            guard let tag = record.tag else { return nil }
            switch record.validity(now: now, calendar: calendar) {
            case .active, .expiredStillApplied:
                return tag
            }
        }
    }

    /// True when any stored tag is overdue for re-screen. Per D-07 this drives a non-blocking
    /// banner only — no caller may use this to gate access; it says "prompt," never "block."
    public func isReScreenDue(now: Date) throws -> Bool {
        _ = try loadProfile()

        let records = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        return records.contains { $0.isReScreenDue(now: now, calendar: calendar) }
    }

    /// Clears only `section`'s condition-tag records, never the whole questionnaire, per D-09.
    ///
    /// Deletes (rather than stamps `editedAt` on) the matching records: §1.6 is explicit that a
    /// tag holds "for up to 12 months, *or until the user edits an answer, whichever comes
    /// first*" — an edit shortens the window, it never extends it. Stamping `editedAt` on an
    /// already-overdue record here would reset its clock to `now` and silently discharge the
    /// D-07 re-screen banner and the D-08 restriction before the user has actually re-answered
    /// anything, which is the same failure class as under-restricting via the expiry filter
    /// itself. `saveScreeningResult` is what writes fresh records (with `editedAt` left `nil`,
    /// `recordedAt = now`) once the re-answer actually lands.
    public func invalidateSection(_ section: EditableSection, now: Date) throws {
        let profile = try loadProfile()

        switch section {
        case .explanationRegister:
            profile.explanationRegisterRaw = nil
            profile.updatedAt = now

        case .dietaryPattern:
            profile.dietaryPatternRaw = nil
            profile.updatedAt = now

        case .gateSection:
            // G5's immediate MED-1/MED-2 follow-ups are the only gate-section-derived tags.
            try deleteConditionTagRecords(matching: [
                .rateLimitingHeartOrBPMedication,
                .clinicianPrescribedDietOrMealPlan,
            ])

        case .conditionChecklist, .severityFollowUps:
            // The condition checklist (§1.3) and its severity follow-ups (§1.4) jointly derive
            // every condition tag except the two gate-section tags above, the age-derived tags
            // (which come from Q0/U-1, not this section), and the eating-disorder outcome
            // (scoped to its own `.scoff` section below) — clearing either one re-checks
            // exactly that shared derivation surface, without touching dietary pattern,
            // register, or those other tags.
            let excluded: Set<ConditionTag> = [
                .rateLimitingHeartOrBPMedication,
                .clinicianPrescribedDietOrMealPlan,
                .under18Minor,
                .age65PlusOrDeconditioned,
                .eatingDisorderPositiveScreen,
                .eatingDisorderSelfReportedNegativeScreen,
            ]
            try deleteConditionTagRecords(matching: Set(ConditionTag.allCases).subtracting(excluded))

        case .scoff:
            profile.edScreenOutcomeRaw = nil
            profile.updatedAt = now
            try deleteConditionTagRecords(matching: [
                .eatingDisorderPositiveScreen,
                .eatingDisorderSelfReportedNegativeScreen,
            ])
        }

        try context.save()
    }

    /// Deletes every stored `ConditionTagRecord` whose tag is in `tags`. A tag with no matching
    /// stored record is simply not present — this is a no-op for it, not an error.
    private func deleteConditionTagRecords(matching tags: Set<ConditionTag>) throws {
        let records = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        for record in records where record.tag.map(tags.contains) == true {
            context.delete(record)
        }
    }

    // MARK: - Professional clearance

    /// §1.6: the "I've talked to a professional" toggle is not a permanent unlock — it
    /// re-prompts at each re-screen point (`ProfessionalClearance.needsReConfirmation`), rather
    /// than silently persisting forever.
    public func recordProfessionalClearance(for tag: ConditionTag, at date: Date) throws {
        _ = try loadProfile()

        guard let record = try fetchConditionTagRecord(for: tag) else {
            // Reuses `profileMissing` to mean "no stored screening data found for this
            // operation" — the plan defines only two `HealthDataStoreError` cases, and
            // recording clearance for a tag the user was never actually screened into is the
            // same class of "there is nothing here to operate on" as a missing profile.
            throw HealthDataStoreError.profileMissing
        }
        record.professionalClearanceGrantedAt = date
        try context.save()
    }

    public func clearancesNeedingReConfirmation(now: Date) throws -> [ConditionTag] {
        _ = try loadProfile()

        let records = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        return records.compactMap { record -> ConditionTag? in
            guard let tag = record.tag, let grantedAt = record.professionalClearanceGrantedAt else {
                return nil
            }
            let clearance = ProfessionalClearance(grantedAt: grantedAt)
            return clearance.needsReConfirmation(now: now, calendar: calendar) ? tag : nil
        }
    }

    private func fetchConditionTagRecord(for tag: ConditionTag) throws -> ConditionTagRecord? {
        let records = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        return records.first { $0.tag == tag }
    }

    // MARK: - Calibration baseline

    public func saveCalibrationBaseline(_ baseline: CalibrationBaseline) throws {
        let existing = try context.fetch(FetchDescriptor<CalibrationBaselineRecord>())
        for record in existing {
            context.delete(record)
        }
        context.insert(CalibrationBaselineRecord(
            slowestSecondsPerKm: baseline.paceZone.slowestSecondsPerKm,
            fastestSecondsPerKm: baseline.paceZone.fastestSecondsPerKm,
            safeStartingWeightKg: baseline.safeStartingWeightKg,
            sourceRaw: baseline.source.rawValue,
            establishedAt: baseline.establishedAt
        ))
        try context.save()
    }

    /// Per D-03, a skipped calibration must never present as a blank state — when nothing is
    /// stored (or the stored record's raw value no longer decodes, T-01-64), this returns
    /// `CalibrationBaseline.provisional` rather than `nil`.
    public func loadCalibrationBaseline() throws -> CalibrationBaseline? {
        let records = try context.fetch(FetchDescriptor<CalibrationBaselineRecord>())
        guard let baseline = records.first?.baseline else {
            return CalibrationBaseline.provisional(establishedAt: Date())
        }
        return baseline
    }

    // MARK: - Private

    private func fetchProfile() throws -> UserProfile? {
        try context.fetch(FetchDescriptor<UserProfile>()).first
    }
}

/// The writable fields `HealthDataStore.updateProfile` accepts. A plain, non-persisted struct
/// rather than a detached `UserProfile` instance — SwiftData `@Model` instances are tied to a
/// context, and this decouples the write API from that identity/context plumbing.
public struct UserProfileDraft: Sendable, Equatable {
    public var age: Int
    public var explanationRegister: ExplanationRegister?
    public var dietaryPattern: DietaryPattern?

    public init(
        age: Int,
        explanationRegister: ExplanationRegister? = nil,
        dietaryPattern: DietaryPattern? = nil
    ) {
        self.age = age
        self.explanationRegister = explanationRegister
        self.dietaryPattern = dietaryPattern
    }
}

public enum HealthDataStoreError: Error, Equatable {
    /// Thrown by any accessor that needs a stored profile and finds none.
    case profileMissing
    /// Thrown by `updateProfile` when an incoming age under 13 is compared against an existing
    /// 13-or-older stored profile — see that method's doc comment (T-01-66).
    case ageBelowFloor
}
