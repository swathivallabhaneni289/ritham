import Foundation

// The lazy, idempotent, append-only reconciliation fold — Momentum's core mechanic
// (03-RESEARCH.md "Pattern 2: Reconciliation-on-read"). Because Momentum has no server or
// background job (D-01), "shields auto-apply the moment a week is about to be missed" cannot
// literally fire at that instant; instead every read of Momentum state re-enters `reconcile`,
// which folds every fully-elapsed week since the ledger's own `lastReconciledWeekStart` anchor
// and produces the updated ledger.
//
// LOCKED DECISION — guardrail-before-shield ordering: `outcome(for:ledger:guardrails:)` checks a
// Recovery Week flag, then an injury freeze, strictly BEFORE it ever considers shield
// consumption. This is load-bearing, not a style preference: checking the guardrails first is
// what prevents a user who explicitly flagged a Recovery Week (or is mid-injury-freeze) from also
// silently losing a shield for that same week. Reversing this order is a real correctness bug.
//
// LOCKED DECISION — idempotence and append-only: `lastReconciledWeekStart` is the idempotence
// anchor. Any elapsed week at or before it is skipped entirely on every subsequent call, so
// reconciling twice against the same `now` and unchanged session data can never double-consume a
// shield or double-award a milestone. Milestones and comeback windows are only ever appended to,
// never removed or retracted — a milestone is never re-derived from "should this currently be
// true" (which a later retroactive session edit, STRENGTH-05, could flip to false); it is only
// ever looked up as "has this already been awarded," which a retroactive edit can never undo.
//
// Every function here takes `calendar: Calendar` and (where relevant) `now: Date` as required,
// non-defaulted parameters. No `Calendar.current`, no bare `Date()` — matching
// `ConditionTagValidity`'s precedent — because a test fixture must be able to supply the exact
// same `now`/`calendar` across a DST transition and expect a stable, reproducible result.

/// One Momentum week's inputs to the reconciliation fold: its boundary, the session records
/// falling inside it, and its endowed-credit adjustment (D-10). The caller (plan 03-05) builds
/// one of these per week from `HealthDataStore`'s existing date-range queries.
public struct MomentumWeekInput: Sendable, Equatable {
    public var weekStart: Date
    public var weekEnd: Date
    public var cardio: [CardioSession]
    public var lift: [LiftSession]
    public var endowedCredit: Int

    public init(
        weekStart: Date,
        weekEnd: Date,
        cardio: [CardioSession],
        lift: [LiftSession],
        endowedCredit: Int
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.cardio = cardio
        self.lift = lift
        self.endowedCredit = endowedCredit
    }
}

/// The six branches the guardrail-then-target-then-shield precedence can resolve a week to.
/// Returned from `outcome(for:ledger:guardrails:)` so tests can assert the precedence branch
/// actually taken, not merely infer it from side effects.
public enum MomentumWeekOutcome: String, Sendable, Equatable, CaseIterable {
    case met
    case paused
    case frozen
    case protectedMiss
    case shielded
    case missed
}

public enum MomentumReconciliation {

    /// MOMENTUM-04's Comeback Session repair window length, in whole calendar days — always
    /// computed through an injected `Calendar`, never as a fixed-seconds interval, so a window
    /// spanning a DST transition is still exactly 3 calendar days.
    public static let comebackWindowDays: Int = 3

    /// MOMENTUM-01's cross-modality qualifying-session count: one for each cardio session whose
    /// progress the shipped `CardioQualification.evaluate` marks complete, plus one for each lift
    /// session the shipped `LiftQualification.evaluate` marks complete. Neither modality is
    /// weighted above the other, and no duration/set/exercise threshold is re-derived here — both
    /// thresholds live in `CalibrationThreshold` and are already read by the two evaluators this
    /// calls (D-02).
    public static func qualifyingSessionCount(cardio: [CardioSession], lift: [LiftSession]) -> Int {
        let qualifyingCardio = cardio.filter { CardioQualification.evaluate($0.progress) == .complete }
        let qualifyingLift = lift.filter { LiftQualification.evaluate($0) == .complete }
        return qualifyingCardio.count + qualifyingLift.count
    }

    /// Whether any tag in `tags` is one the shipped guidance catalog marks as never triggering
    /// streak loss. This reads `WorkoutGuidanceCatalog.neverTriggersStreakLoss(_:)` directly
    /// rather than restating its five-tag list — that catalog function's own header comment
    /// states Phase 3's Momentum reads it rather than re-deriving the list, and
    /// `GuidanceCatalogTests` already pins the list's size.
    public static func isStreakLossProtected(tags: Set<ConditionTag>) -> Bool {
        tags.contains { WorkoutGuidanceCatalog.neverTriggersStreakLoss($0) }
    }

    /// Resolves a single week's outcome against the ledger and guardrails, in the locked
    /// precedence order: Recovery Week, then injury freeze, then the qualifying-session target,
    /// then streak-loss protection, then shield availability.
    public static func outcome(
        for week: MomentumWeekInput,
        ledger: MomentumLedger,
        guardrails: MomentumGuardrails
    ) -> MomentumWeekOutcome {
        if guardrails.recoveryWeeks.contains(where: { $0.covers(weekStart: week.weekStart) }) {
            return .paused
        }
        if guardrails.injuryFreezes.contains(where: { $0.overlaps(weekStart: week.weekStart, weekEnd: week.weekEnd) }) {
            return .frozen
        }

        let count = qualifyingSessionCount(cardio: week.cardio, lift: week.lift)
        let required = MomentumTarget.requiredQualifyingSessions(
            target: ledger.weeklyTarget,
            endowedCredit: week.endowedCredit
        )
        if count >= required {
            return .met
        }

        if guardrails.streakLossProtected {
            return .protectedMiss
        }

        if ledger.shieldCount > 0 {
            return .shielded
        }

        return .missed
    }

    /// The lazy, idempotent, append-only fold. Sorts `elapsedWeeks` ascending by week start,
    /// skips any week at or before the ledger's own `lastReconciledWeekStart` anchor, and folds
    /// the rest in order.
    ///
    /// Shield accrual/consumption and milestone awards are implemented here, both append-only or
    /// monotonic. Idempotence (03-RESEARCH.md Pitfall 2) is delivered by two mechanisms, neither
    /// replaceable by recomputing state from the current streak: the anchor skip above, and the
    /// contains-check against `ledger.milestones` before appending a new award. A milestone is
    /// never retracted even if a retroactive session edit (STRENGTH-05) later changes a past
    /// week's derived qualifying count — reconciliation only ever asks whether a milestone has
    /// already been awarded, never whether it should currently be true.
    ///
    /// Comeback-window handling (on `missed`) is completed by a later task — see the TODO marker
    /// below; that branch is not stubbed with placeholder behavior a later task would have to
    /// unpick.
    public static func reconcile(
        ledger: MomentumLedger,
        elapsedWeeks: [MomentumWeekInput],
        currentWeek: MomentumWeekInput,
        guardrails: MomentumGuardrails,
        now: Date,
        calendar: Calendar
    ) -> MomentumLedger {
        var ledger = ledger

        let weeksToProcess = elapsedWeeks
            .sorted { $0.weekStart < $1.weekStart }
            .filter { week in
                guard let anchor = ledger.lastReconciledWeekStart else { return true }
                return week.weekStart > anchor
            }

        for week in weeksToProcess {
            let weekOutcome = outcome(for: week, ledger: ledger, guardrails: guardrails)
            switch weekOutcome {
            case .met:
                ledger.currentStreak += 1
                ledger.weeksTowardNextShield += 1
                if ledger.weeksTowardNextShield >= MomentumLedger.weeksPerShield {
                    ledger.weeksTowardNextShield = 0
                    ledger.shieldCount = min(MomentumLedger.maxShields, ledger.shieldCount + 1)
                }
                if MomentumMilestone.tiers.contains(ledger.currentStreak),
                   !ledger.milestones.contains(where: { $0.weekCount == ledger.currentStreak }) {
                    ledger.milestones.append(MilestoneAward(
                        id: UUID(),
                        weekCount: ledger.currentStreak,
                        awardedAt: week.weekEnd
                    ))
                    ledger.shieldCount = min(MomentumLedger.maxShields, ledger.shieldCount + 1)
                }
            case .shielded:
                ledger.shieldCount -= 1
                ledger.weeksTowardNextShield = 0
            case .paused, .frozen, .protectedMiss:
                break
            case .missed:
                // TODO(Task 3): open a Comeback Window guarded on missedWeekStart uniqueness.
                break
            }
            ledger.lastReconciledWeekStart = week.weekStart
        }

        return ledger
    }
}
