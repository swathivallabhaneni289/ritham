import Foundation
import SwiftData
import RithamCore

// The single persisted profile record. Per D-14 (01-CONTEXT.md), Ritham has a permanent 13+
// age floor enforced at Q0, before a profile is ever created — a stored `UserProfile` therefore
// always belongs to a user who is already 13 or older, and there is no consent tier or state to
// model here. `age` continues to drive the unrelated 65+/deconditioned/returning-after-inactivity
// content-adjustment tag elsewhere in the app (`ConditionTag.ageDerivedTags(forAge:)`) — that
// mechanism is untouched by this file.
//
// Enum-valued fields are stored by their `String` raw value (`dietaryPatternRaw`,
// `edScreenOutcomeRaw`) with a computed accessor decoding back to the core type. SwiftData
// persists primitives most predictably, and the raw values are already the stable identifiers
// RithamCore defines. Every computed accessor below returns `nil` rather than force-unwrapping
// an unrecognised raw value, so a future schema/case change cannot crash the app on old data
// (T-01-64).
//
// There is no `explanationRegisterRaw` field -- EXPLAIN-01 no longer has a user-chosen
// explanation register (see `RithamCore/Onboarding/Glossary.swift`'s header comment). This app
// has no `VersionedSchema`/`SchemaMigrationPlan` (see `RithamModelContainer.swift`), so a local
// store created before this change is not guaranteed to open cleanly against this narrower
// schema. Not a production-data risk pre-launch, but a real one for an existing simulator/device
// install with a prior build's data -- see this phase's sign-off report for the remedy.
//
// Resolves the storage question 01-RESEARCH.md flagged for this plan rather than defaulting
// silently: only the *derived* eating-disorder outcome is stored (`edScreenOutcomeRaw`, holding
// one of `ConditionTag.eatingDisorderPositiveScreen` / `.eatingDisorderSelfReportedNegativeScreen`),
// never the five individual SCOFF answers (ED-1 through ED-5). Rationale (T-01-60):
//   - §1.5 states the individual answers are never shown as a score or a label to the user;
//     01-RESEARCH.md recommends extending that framing to storage too.
//   - The answers have no downstream consumer — `GateResolution.resolve` needs only the
//     derived outcome, never the raw SCOFF responses, to compute gates.
//   - Not storing them removes them from the reach of any future data export, debug log, or
//     feature that reads this model.
// The cost: editing this section later means re-answering all five questions, which D-09
// already permits since an edit re-checks that section from scratch.
@Model
public final class UserProfile {
    public var age: Int
    public var dietaryPatternRaw: String?
    public var edScreenOutcomeRaw: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        age: Int,
        dietaryPatternRaw: String? = nil,
        edScreenOutcomeRaw: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.age = age
        self.dietaryPatternRaw = dietaryPatternRaw
        self.edScreenOutcomeRaw = edScreenOutcomeRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Per DIET-01, has no expiry and no re-screen; never derived from age. `nil` when
    /// unanswered or when the stored raw value no longer matches a known case.
    public var dietaryPattern: DietaryPattern? {
        guard let dietaryPatternRaw else { return nil }
        return DietaryPattern(rawValue: dietaryPatternRaw)
    }

    /// The derived eating-disorder screening outcome — either
    /// `.eatingDisorderPositiveScreen` or `.eatingDisorderSelfReportedNegativeScreen` — or `nil`
    /// when the SCOFF screen has never been triggered/completed. See the type header comment
    /// for why only this derived result is stored, never the five raw SCOFF answers.
    public var edScreenOutcome: ConditionTag? {
        guard let edScreenOutcomeRaw else { return nil }
        return ConditionTag(rawValue: edScreenOutcomeRaw)
    }
}
