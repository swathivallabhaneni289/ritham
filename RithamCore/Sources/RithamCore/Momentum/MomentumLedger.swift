import Foundation

// The Momentum ledger value types plan 03-03's reconciliation fold produces and plan 03-04's
// SwiftData records persist. Mirrors `ConditionTagValidity.ProfessionalClearance`'s "dated grant,
// not a standing boolean" shape (RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift
// lines 76-90): every type here is a `public`, `Sendable`, `Equatable` struct or enum with dated
// fields and pure query methods — never a mutable class, never a computed boolean baked into
// shared state.
//
// A field added here without a matching column in plan 03-04's SwiftData records is a silent
// data-loss bug — see 03-01-PLAN.md's key_links.

/// MOMENTUM-06/D-07: streak/shield visibility. Exactly one v1 case (private-to-device) so Phase 4
/// can add a `.household` case later without a data migration. The Swift case is named
/// `privateToDevice` rather than the backticked keyword `private`, while the persisted raw value
/// stays the plain, stable string `"private"`.
public enum MomentumVisibility: String, CaseIterable, Sendable, Equatable, Codable {
    case privateToDevice = "private"
}

/// Whether the current streak is a fresh (never-interrupted) one or one rebuilt after a comeback
/// window closed unclaimed. `rebuilt` drives MOMENTUM-05's non-threat-framed display copy ("Week
/// 1 of your rebuilt streak") rather than any reset-to-zero framing.
public enum StreakLabelKind: String, Sendable, Equatable, Codable {
    case fresh
    case rebuilt
}

/// MOMENTUM-05's milestone week-count tiers, in ascending order. A milestone is awarded once per
/// tier, ever — the tiers themselves never change per user state.
public enum MomentumMilestone {
    public static let tiers: [Int] = [4, 12, 26, 52]
}

/// An append-only record of one milestone badge having been awarded. Reconciliation only ever
/// asks "has this milestone already been awarded?" (a lookup against existing awards) before
/// deciding whether to award it again (never) — it never re-derives whether a milestone "should"
/// currently be true, so a later retroactive session edit can never claw back an already-shown
/// badge.
public struct MilestoneAward: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var weekCount: Int
    public var awardedAt: Date

    public init(id: UUID, weekCount: Int, awardedAt: Date) {
        self.id = id
        self.weekCount = weekCount
        self.awardedAt = awardedAt
    }
}

/// MOMENTUM-04's 3-day Comeback Session repair window, opened when a week is missed with no
/// shield available. Half-open: covers `[opensAt, closesAt)`.
public struct ComebackWindow: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var missedWeekStart: Date
    public var opensAt: Date
    public var closesAt: Date
    public var claimedAt: Date?
    public var claimingSessionID: UUID?
    public var streakBeforeMiss: Int
    /// Set exactly once, either at claim time or at unclaimed-expiry time, by
    /// `MomentumReconciliation.reconcile`'s post-fold resolution pass — never re-derived from
    /// `now`/`closesAt` on a later call. This is what makes the unclaimed-expiry transition
    /// idempotent: once set, the resolution pass never re-applies the `currentStreak = 0`
    /// side effect for this window again, no matter how many times `reconcile` runs afterward.
    public var resolvedAt: Date?

    public init(
        id: UUID,
        missedWeekStart: Date,
        opensAt: Date,
        closesAt: Date,
        claimedAt: Date?,
        claimingSessionID: UUID?,
        streakBeforeMiss: Int,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.missedWeekStart = missedWeekStart
        self.opensAt = opensAt
        self.closesAt = closesAt
        self.claimedAt = claimedAt
        self.claimingSessionID = claimingSessionID
        self.streakBeforeMiss = streakBeforeMiss
        self.resolvedAt = resolvedAt
    }

    /// Whether the Comeback CTA should be visible right now: unclaimed and `now` is strictly
    /// before `closesAt`. Deliberately does not check `opensAt` — the window is meant to be
    /// immediately actionable from the moment the miss is reconciled, not gated on a separate
    /// open time reached later.
    public func isOpen(now: Date) -> Bool {
        claimedAt == nil && now < closesAt
    }

    /// Whether `instant` falls within the window's half-open `[opensAt, closesAt)` range,
    /// independent of claim state.
    public func covers(_ instant: Date) -> Bool {
        instant >= opensAt && instant < closesAt
    }
}

/// MOMENTUM-03: a user-initiated flag pausing one specific week's target for reconciliation
/// purposes, per D-12 — fully pausing that entire week regardless of what day of the week the
/// flag was set. Never auto-triggered by the app (D-03).
public struct RecoveryWeekPeriod: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var weekStart: Date
    public var flaggedAt: Date

    public init(id: UUID, weekStart: Date, flaggedAt: Date) {
        self.id = id
        self.weekStart = weekStart
        self.flaggedAt = flaggedAt
    }

    /// True only when `weekStart` is exactly this period's own flagged week start.
    public func covers(weekStart: Date) -> Bool {
        self.weekStart == weekStart
    }
}

/// MOMENTUM-08: a self-reported pain/injury freeze, open-ended until the user clears it — unlike
/// `RecoveryWeekPeriod`, this is not scoped to a single week. Its own distinct self-report action,
/// per D-03's structural independence.
public struct InjuryFreezePeriod: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    public init(id: UUID, startedAt: Date, endedAt: Date?) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Whether this freeze overlaps the half-open week range `[weekStart, weekEnd)`. With a `nil`
    /// `endedAt` (still active), overlaps every week whose end is after this freeze's start. With
    /// a non-nil `endedAt`, overlaps only weeks intersecting `[startedAt, endedAt)`.
    public func overlaps(weekStart: Date, weekEnd: Date) -> Bool {
        guard let endedAt else {
            return weekEnd > startedAt
        }
        return weekEnd > startedAt && weekStart < endedAt
    }
}

/// D-03: the three self-report guardrail state machines, kept as structurally independent
/// members — never one shared "recovery state" enum or flag — so "the sleep check-in never
/// auto-triggers a Recovery Week and never auto-consumes a shield" and "a Recovery Week is only
/// ever user-initiated, never auto-triggered by the app" are structurally true, not merely
/// untested.
public struct MomentumGuardrails: Sendable, Equatable {
    public var recoveryWeeks: [RecoveryWeekPeriod]
    public var injuryFreezes: [InjuryFreezePeriod]
    public var streakLossProtected: Bool

    public init(
        recoveryWeeks: [RecoveryWeekPeriod],
        injuryFreezes: [InjuryFreezePeriod],
        streakLossProtected: Bool
    ) {
        self.recoveryWeeks = recoveryWeeks
        self.injuryFreezes = injuryFreezes
        self.streakLossProtected = streakLossProtected
    }
}

/// The persisted Momentum ledger: everything reconciliation (plan 03-03) cannot re-derive from
/// session records alone. Per 03-RESEARCH.md's Data Model Shape, the current streak length and
/// this week's qualifying count are *derived* at read time — this struct is the append-only /
/// cached-scalar state reconciliation folds over time, never a second source of truth for
/// anything a session-record query can answer directly.
public struct MomentumLedger: Sendable, Equatable {
    public var currentStreak: Int
    public var streakLabelKind: StreakLabelKind
    public var shieldCount: Int
    public var weeksTowardNextShield: Int
    public var lastReconciledWeekStart: Date?
    public var weeklyTarget: Int
    public var visibility: MomentumVisibility
    public var milestones: [MilestoneAward]
    public var comebackWindows: [ComebackWindow]

    public init(
        currentStreak: Int,
        streakLabelKind: StreakLabelKind,
        shieldCount: Int,
        weeksTowardNextShield: Int,
        lastReconciledWeekStart: Date?,
        weeklyTarget: Int,
        visibility: MomentumVisibility,
        milestones: [MilestoneAward],
        comebackWindows: [ComebackWindow]
    ) {
        self.currentStreak = currentStreak
        self.streakLabelKind = streakLabelKind
        self.shieldCount = shieldCount
        self.weeksTowardNextShield = weeksTowardNextShield
        self.lastReconciledWeekStart = lastReconciledWeekStart
        self.weeklyTarget = weeklyTarget
        self.visibility = visibility
        self.milestones = milestones
        self.comebackWindows = comebackWindows
    }

    /// MOMENTUM-02: a shield is granted per this many consecutive successful weeks.
    public static let weeksPerShield: Int = 4

    /// MOMENTUM-02: shields stack up to this many, never more.
    public static let maxShields: Int = 3

    /// A brand-new user's ledger: no streak, no shields, no history, the default weekly target,
    /// and private-to-device visibility.
    public static let empty = MomentumLedger(
        currentStreak: 0,
        streakLabelKind: .fresh,
        shieldCount: 0,
        weeksTowardNextShield: 0,
        lastReconciledWeekStart: nil,
        weeklyTarget: MomentumTarget.defaultTarget,
        visibility: .privateToDevice,
        milestones: [],
        comebackWindows: []
    )
}
