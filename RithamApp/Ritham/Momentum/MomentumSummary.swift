import Foundation
import RithamCore

// D-08's standalone queryable read: `MomentumSummary` (the value) and `MomentumSummaryReader`
// (the driver that produces it). Both `HomeHubView` (plan 03-07) and `MomentumView` (plan 03-06)
// call the same reader, satisfying D-08's "not baked into a hub-specific view model" requirement
// and Phase 4's forward reference to reuse the same underlying data.
//
// `MomentumSummary` carries no sleep member of any kind, of any name, anywhere in this file. This
// is RECOVERY-01 invariants 3 and 7 made structural, not merely tested: every Momentum surface
// reads this one value, so a sleep member here would let a screen render differently based on
// check-in history, which those invariants forbid. `momentumSummaryCarriesNoSleepState`
// (MomentumSummaryTests) pins this with a Mirror-based check over a live instance, and a saved
// sleep check-in is asserted to change nothing about the resulting summary.
//
// `summary(now:)` below calls exactly one store write method, `store.saveMomentumLedger(_:)`, and
// only when the reconciled ledger differs from the one just loaded. It calls no Recovery Week or
// injury freeze write method, and no method that touches a sleep check-in record at all -- the
// three user-initiated guardrail actions this file also declares (`flagRecoveryWeek`,
// `flagInjury`, `clearInjury`) are separate methods with their own separate store calls, never
// reachable from `summary(now:)` or from each other.

/// One cardio or lift session, shaped for display in a combined Momentum history list.
///
/// A cardio session's `verificationLabel` is `MomentumCopy.Verification`'s sensor-verified or
/// manually-entered string, chosen from the session's own shipped `isSensorVerified` property. A
/// lift session's `verificationLabel` is always `nil` -- `LiftSessionRecord` has no capture-source
/// field at all (every lift session is manually logged by construction), so a combined history
/// must render a lift row with no label in that column rather than inventing a default
/// "manually entered" label for a field that does not exist on that record type
/// (03-UI-SPEC.md Component 11, 03-RESEARCH.md's Don't Hand-Roll row 3).
public struct MomentumSessionEntry: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var title: String
    public var verificationLabel: String?
    public var qualifies: Bool

    public init(
        id: UUID,
        startedAt: Date,
        title: String,
        verificationLabel: String?,
        qualifies: Bool
    ) {
        self.id = id
        self.startedAt = startedAt
        self.title = title
        self.verificationLabel = verificationLabel
        self.qualifies = qualifies
    }
}

/// D-08's standalone queryable Momentum read. See this file's header for why it carries no
/// self-report member of any kind beyond the two user-initiated guardrail flags it is required to
/// surface (`isRecoveryWeekFlagged`/`isInjuryFrozen`) -- both of those are Momentum's own
/// mechanics (MOMENTUM-03/MOMENTUM-08), not the structurally independent sleep check-in.
public struct MomentumSummary: Sendable, Equatable {
    public var weekStart: Date
    public var weekEnd: Date
    public var weeklyTarget: Int
    public var requiredThisWeek: Int
    public var qualifyingThisWeek: Int
    public var endowedCredit: Int
    public var displayedCount: Int
    public var currentStreak: Int
    public var streakLabelKind: StreakLabelKind
    public var shieldCount: Int
    public var milestones: [MilestoneAward]
    public var openComebackWindow: ComebackWindow?
    public var isRecoveryWeekFlagged: Bool
    public var isInjuryFrozen: Bool
    public var isStreakLossProtected: Bool
    public var visibility: MomentumVisibility
    public var recentSessions: [MomentumSessionEntry]

    public init(
        weekStart: Date,
        weekEnd: Date,
        weeklyTarget: Int,
        requiredThisWeek: Int,
        qualifyingThisWeek: Int,
        endowedCredit: Int,
        displayedCount: Int,
        currentStreak: Int,
        streakLabelKind: StreakLabelKind,
        shieldCount: Int,
        milestones: [MilestoneAward],
        openComebackWindow: ComebackWindow?,
        isRecoveryWeekFlagged: Bool,
        isInjuryFrozen: Bool,
        isStreakLossProtected: Bool,
        visibility: MomentumVisibility,
        recentSessions: [MomentumSessionEntry]
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.weeklyTarget = weeklyTarget
        self.requiredThisWeek = requiredThisWeek
        self.qualifyingThisWeek = qualifyingThisWeek
        self.endowedCredit = endowedCredit
        self.displayedCount = displayedCount
        self.currentStreak = currentStreak
        self.streakLabelKind = streakLabelKind
        self.shieldCount = shieldCount
        self.milestones = milestones
        self.openComebackWindow = openComebackWindow
        self.isRecoveryWeekFlagged = isRecoveryWeekFlagged
        self.isInjuryFrozen = isInjuryFrozen
        self.isStreakLossProtected = isStreakLossProtected
        self.visibility = visibility
        self.recentSessions = recentSessions
    }
}

/// The reconciliation-on-read driver. Constructed with a `HealthDataStore` and a `Calendar`
/// (defaulting to the process calendar at this app-layer call site only -- `RithamCore`'s own
/// functions this reader calls still take `Calendar` as a required parameter, never `.current`
/// internally).
@MainActor
public struct MomentumSummaryReader {
    private let store: HealthDataStore
    private let calendar: Calendar

    /// A long-idle store (a user who has not opened the app in years) must not make a single
    /// `summary(now:)` call fetch an unbounded number of weeks of session data on the main actor
    /// (T-3-10). This bounds the number of *elapsed* weeks folded per read; the current week is
    /// always additionally assembled and is never subject to this cap.
    ///
    /// When the gap between the ledger's anchor (or the user's first session, if no anchor is
    /// stored yet) and the current week exceeds this bound, only the most recent
    /// `maxElapsedWeeksPerRead` weeks are folded -- the older overflow weeks are permanently
    /// skipped, never scored as either a miss or a success, and the ledger's anchor advances past
    /// them as a side effect of folding the retained window. This is a documented tradeoff, not a
    /// bug: it trades a small amount of retroactive precision on an already-abandoned-for-years
    /// streak for a bounded, predictable read cost on every other call.
    private static let maxElapsedWeeksPerRead = 104

    public init(store: HealthDataStore, calendar: Calendar) {
        self.store = store
        self.calendar = calendar
    }

    public func summary(now: Date) throws -> MomentumSummary {
        let ledger = try store.loadMomentumLedger()
        let recoveryWeeks = try store.loadRecoveryWeekPeriods()
        let injuryFreezes = try store.loadInjuryFreezePeriods()

        // Applying the currently-active streak-loss protection to every week being reconciled in
        // this call is the deliberately forgiving direction (see 03-05-PLAN.md): it can only ever
        // protect a week from a miss, never retroactively punish one that already counted.
        //
        // `store.activeConditionTags(now:)` throws `HealthDataStoreError.profileMissing` when no
        // profile has ever been created -- unreachable in the shipped app (Momentum screens are
        // only reachable post-onboarding, once a profile always exists), but a brand-new,
        // profile-less store must still read as "no active tags" rather than crash, matching this
        // method's own "does not throw" requirement for an otherwise-empty store.
        let activeTags = try loadActiveConditionTags(now: now)
        let isStreakLossProtected = MomentumReconciliation.isStreakLossProtected(tags: activeTags)
        let guardrails = MomentumGuardrails(
            recoveryWeeks: recoveryWeeks,
            injuryFreezes: injuryFreezes,
            streakLossProtected: isStreakLossProtected
        )

        let currentWeekStart = MomentumWeek.weekStart(containing: now, calendar: calendar)
        let currentWeekEnd = MomentumWeek.weekEnd(startingAt: currentWeekStart, calendar: calendar)

        let firstSessionStart = try store.earliestSessionStart()
        let firstSessionWeekStart = firstSessionStart.map {
            MomentumWeek.weekStart(containing: $0, calendar: calendar)
        }

        let startWeek: Date
        if let anchor = ledger.lastReconciledWeekStart {
            startWeek = MomentumWeek.nextWeekStart(after: anchor, calendar: calendar)
        } else if let firstSessionWeekStart {
            startWeek = firstSessionWeekStart
        } else {
            startWeek = currentWeekStart
        }

        var elapsedWeekStarts: [Date] = []
        var cursor = startWeek
        while cursor < currentWeekStart {
            elapsedWeekStarts.append(cursor)
            cursor = MomentumWeek.nextWeekStart(after: cursor, calendar: calendar)
        }
        if elapsedWeekStarts.count > Self.maxElapsedWeeksPerRead {
            elapsedWeekStarts = Array(elapsedWeekStarts.suffix(Self.maxElapsedWeeksPerRead))
        }

        let elapsedWeeks = try elapsedWeekStarts.map { weekStart in
            try weekInput(for: weekStart, firstSessionWeekStart: firstSessionWeekStart)
        }
        let currentWeek = try weekInput(for: currentWeekStart, firstSessionWeekStart: firstSessionWeekStart)

        let reconciled = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: elapsedWeeks,
            currentWeek: currentWeek,
            guardrails: guardrails,
            now: now,
            calendar: calendar
        )

        if reconciled != ledger {
            try store.saveMomentumLedger(reconciled)
        }

        let qualifyingThisWeek = MomentumReconciliation.qualifyingSessionCount(
            cardio: currentWeek.cardio, lift: currentWeek.lift
        )
        let requiredThisWeek = MomentumTarget.requiredQualifyingSessions(
            target: reconciled.weeklyTarget, endowedCredit: currentWeek.endowedCredit
        )
        let displayedCount = MomentumTarget.displayedCount(
            qualifying: qualifyingThisWeek, endowedCredit: currentWeek.endowedCredit, target: reconciled.weeklyTarget
        )

        let openComebackWindow = reconciled.comebackWindows
            .filter { $0.isOpen(now: now) }
            .max(by: { $0.opensAt < $1.opensAt })

        let isRecoveryWeekFlagged = recoveryWeeks.contains { $0.covers(weekStart: currentWeekStart) }
        let isInjuryFrozen = injuryFreezes.contains {
            $0.overlaps(weekStart: currentWeekStart, weekEnd: currentWeekEnd)
        }

        return MomentumSummary(
            weekStart: currentWeekStart,
            weekEnd: currentWeekEnd,
            weeklyTarget: reconciled.weeklyTarget,
            requiredThisWeek: requiredThisWeek,
            qualifyingThisWeek: qualifyingThisWeek,
            endowedCredit: currentWeek.endowedCredit,
            displayedCount: displayedCount,
            currentStreak: reconciled.currentStreak,
            streakLabelKind: reconciled.streakLabelKind,
            shieldCount: reconciled.shieldCount,
            milestones: reconciled.milestones,
            openComebackWindow: openComebackWindow,
            isRecoveryWeekFlagged: isRecoveryWeekFlagged,
            isInjuryFrozen: isInjuryFrozen,
            isStreakLossProtected: isStreakLossProtected,
            visibility: reconciled.visibility,
            recentSessions: recentSessions(for: currentWeek)
        )
    }

    // MARK: - User-initiated guardrail actions
    //
    // Three separate methods, each with its own separate store call, no shared code path between
    // them. None of the three is ever invoked from `summary(now:)` or from any other read path in
    // this file, and none calls the other two. MOMENTUM-03 requires a Recovery Week to be
    // user-initiated only, never auto-triggered by the app; RECOVERY-01 requires the sleep feature
    // never to auto-trigger one either. The enforcement is structural, not just a naming
    // convention: `summary(now:)` above calls no write method other than
    // `store.saveMomentumLedger(_:)`, and this file imports no sleep-check-in type at all -- there
    // is nothing in this file able to read a check-in and call one of the three methods below.

    /// Appends a Recovery Week period for the week containing `now`. Per D-12 this pauses that
    /// entire week retroactively for reconciliation purposes regardless of which day within it
    /// this was called on -- it always targets the week containing the flagging instant; there is
    /// no path here for a caller to select an arbitrary earlier week.
    public func flagRecoveryWeek(now: Date) throws {
        let weekStart = MomentumWeek.weekStart(containing: now, calendar: calendar)
        try store.appendRecoveryWeekPeriod(RecoveryWeekPeriod(id: UUID(), weekStart: weekStart, flaggedAt: now))
    }

    /// Appends an open-ended injury freeze starting at `now`. A no-op when one is already open --
    /// `store.appendInjuryFreezePeriod` is itself idempotent on this condition.
    public func flagInjury(now: Date) throws {
        try store.appendInjuryFreezePeriod(InjuryFreezePeriod(id: UUID(), startedAt: now, endedAt: nil))
    }

    /// Closes the open injury freeze, if any, at `now`.
    public func clearInjury(now: Date) throws {
        try store.closeOpenInjuryFreeze(at: now)
    }

    /// A plain read helper the flag rows in plan 03-06 use to pick their label. Reads only
    /// `InjuryFreezePeriodRecord` via `store.loadInjuryFreezePeriods()` -- no other guardrail or
    /// self-report record type.
    public func isInjuryFrozen(now: Date) throws -> Bool {
        try store.loadInjuryFreezePeriods().contains { $0.startedAt <= now && $0.endedAt == nil }
    }

    /// A plain read helper the flag rows in plan 03-06 use to pick their label. Reads only
    /// `RecoveryWeekPeriodRecord` via `store.loadRecoveryWeekPeriods()` -- no other guardrail or
    /// self-report record type.
    public func isRecoveryWeekFlagged(now: Date) throws -> Bool {
        let weekStart = MomentumWeek.weekStart(containing: now, calendar: calendar)
        return try store.loadRecoveryWeekPeriods().contains { $0.covers(weekStart: weekStart) }
    }

    /// See `summary(now:)`'s call site comment: a profile-less store reads as "no active tags"
    /// rather than propagating `HealthDataStoreError.profileMissing`.
    private func loadActiveConditionTags(now: Date) throws -> Set<ConditionTag> {
        do {
            return Set(try store.activeConditionTags(now: now))
        } catch HealthDataStoreError.profileMissing {
            return []
        }
    }

    /// Builds one week's reconciliation input from the store's existing date-range queries.
    private func weekInput(for weekStart: Date, firstSessionWeekStart: Date?) throws -> MomentumWeekInput {
        let weekEnd = MomentumWeek.weekEnd(startingAt: weekStart, calendar: calendar)
        let range = weekStart...(weekEnd.addingTimeInterval(-0.001))
        let cardio = try store.loadCardioSessions(in: range)
        let lift = try store.loadLiftSessions(in: range)
        let endowedCredit = MomentumTarget.endowedCredit(
            weekStart: weekStart, firstSessionWeekStart: firstSessionWeekStart
        )
        return MomentumWeekInput(
            weekStart: weekStart, weekEnd: weekEnd, cardio: cardio, lift: lift, endowedCredit: endowedCredit
        )
    }

    /// The current week's cardio and lift sessions, shaped for display and sorted most-recent-first.
    private func recentSessions(for currentWeek: MomentumWeekInput) -> [MomentumSessionEntry] {
        let cardioEntries = currentWeek.cardio.map { session in
            MomentumSessionEntry(
                id: session.id,
                startedAt: session.startedAt,
                title: session.activityType.displayName,
                verificationLabel: session.source.isSensorVerified
                    ? MomentumCopy.Verification.sensorVerified
                    : MomentumCopy.Verification.manuallyEntered,
                qualifies: CardioQualification.evaluate(session.progress) == .complete
            )
        }
        // `LiftSession` carries no per-exercise-list title of its own kind at the session level
        // (`StrengthSessionView`'s own screen title, "Strength session," is the closest existing
        // precedent, transcribed here rather than drafted anew); its `verificationLabel` is always
        // `nil` per this file's header comment.
        let liftEntries = currentWeek.lift.map { session in
            MomentumSessionEntry(
                id: session.id,
                startedAt: session.startedAt,
                title: "Strength session",
                verificationLabel: nil,
                qualifies: LiftQualification.evaluate(session) == .complete
            )
        }
        return (cardioEntries + liftEntries).sorted { $0.startedAt > $1.startedAt }
    }
}
