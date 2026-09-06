import Foundation
import SwiftData
import RithamCore

// The four append-only Momentum ledger records, each following `CardioSessionRecord`'s
// independently-addressable-row shape: a plain stored-property `@Model`, a convenience init
// taking the matching RithamCore domain value, and a computed property returning that domain
// value (or `nil` on an undecodable raw value, never trapping) rather than a second copy of the
// same data.
//
// D-03 (see 03-CONTEXT.md): the daily sleep check-in, the user-initiated Recovery Week flag
// (`RecoveryWeekPeriodRecord`) and the self-reported pain/injury freeze (`InjuryFreezePeriodRecord`)
// are three structurally independent state machines with zero automatic transitions between them.
// None of the five Momentum records in this phase declares a SwiftData relationship attribute, a
// foreign key, or any other cross-reference between them -- the absence of any link is what makes
// "never auto-triggers the other" structurally true rather than merely untested. `HealthDataStore`'s
// Momentum section (plan 03-04) must not add a method that reads one of these record types and
// writes another.

/// An append-only record of one milestone badge having been awarded (MOMENTUM-05). Reconciliation
/// only ever appends a new row here -- it is never deleted or mutated by a later fold, so a
/// retroactive session edit changing a past week's derived count can never claw back an
/// already-shown badge.
@Model
public final class MilestoneAwardRecord {
    public var id: UUID
    public var weekCount: Int
    public var awardedAt: Date

    public init(id: UUID, weekCount: Int, awardedAt: Date) {
        self.id = id
        self.weekCount = weekCount
        self.awardedAt = awardedAt
    }

    public convenience init(award: MilestoneAward) {
        self.init(id: award.id, weekCount: award.weekCount, awardedAt: award.awardedAt)
    }

    /// This record has no raw enum column that can fail to decode, so this never actually
    /// returns `nil` in practice -- it stays `Optional`-typed to match the uniform,
    /// never-trapping accessor shape every record in this file exposes.
    public var award: MilestoneAward? {
        MilestoneAward(id: id, weekCount: weekCount, awardedAt: awardedAt)
    }
}

/// MOMENTUM-04's 3-day Comeback Session repair window, appended once per missed week. Reconciliation
/// never deletes a stored row -- an already-stored, unclaimed window has its claim fields updated
/// in place (`HealthDataStore.saveMomentumLedger`), never replaced.
@Model
public final class ComebackWindowRecord {
    public var id: UUID
    public var missedWeekStart: Date
    public var opensAt: Date
    public var closesAt: Date
    public var claimedAt: Date?
    public var claimingSessionID: UUID?
    public var streakBeforeMiss: Int
    /// Mirrors `ComebackWindow.resolvedAt` -- set once, either on claim or on unclaimed expiry,
    /// by `HealthDataStore.saveMomentumLedger`'s in-place-update branch. Without this column, the
    /// domain-level resolved marker would be recomputed as "unresolved" on every fresh load from
    /// `loadMomentumLedger`, reintroducing the permanent-streak-zero bug after the next app
    /// relaunch.
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

    public convenience init(window: ComebackWindow) {
        self.init(
            id: window.id,
            missedWeekStart: window.missedWeekStart,
            opensAt: window.opensAt,
            closesAt: window.closesAt,
            claimedAt: window.claimedAt,
            claimingSessionID: window.claimingSessionID,
            streakBeforeMiss: window.streakBeforeMiss,
            resolvedAt: window.resolvedAt
        )
    }

    /// No raw enum column here either -- see `MilestoneAwardRecord.award`'s doc comment for why
    /// this stays `Optional`-typed regardless.
    public var window: ComebackWindow? {
        ComebackWindow(
            id: id,
            missedWeekStart: missedWeekStart,
            opensAt: opensAt,
            closesAt: closesAt,
            claimedAt: claimedAt,
            claimingSessionID: claimingSessionID,
            streakBeforeMiss: streakBeforeMiss,
            resolvedAt: resolvedAt
        )
    }
}

/// MOMENTUM-03: a user-initiated flag pausing one specific week's target for reconciliation
/// purposes (D-12). Structurally independent of `InjuryFreezePeriodRecord` -- no relationship, no
/// foreign key, no shared column.
@Model
public final class RecoveryWeekPeriodRecord {
    public var id: UUID
    public var weekStart: Date
    public var flaggedAt: Date

    public init(id: UUID, weekStart: Date, flaggedAt: Date) {
        self.id = id
        self.weekStart = weekStart
        self.flaggedAt = flaggedAt
    }

    public convenience init(period: RecoveryWeekPeriod) {
        self.init(id: period.id, weekStart: period.weekStart, flaggedAt: period.flaggedAt)
    }

    public var period: RecoveryWeekPeriod? {
        RecoveryWeekPeriod(id: id, weekStart: weekStart, flaggedAt: flaggedAt)
    }
}

/// MOMENTUM-08: a self-reported pain/injury freeze, open-ended until the user clears it.
/// Structurally independent of `RecoveryWeekPeriodRecord` -- no relationship, no foreign key, no
/// shared column.
@Model
public final class InjuryFreezePeriodRecord {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    public init(id: UUID, startedAt: Date, endedAt: Date?) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public convenience init(period: InjuryFreezePeriod) {
        self.init(id: period.id, startedAt: period.startedAt, endedAt: period.endedAt)
    }

    public var period: InjuryFreezePeriod? {
        InjuryFreezePeriod(id: id, startedAt: startedAt, endedAt: endedAt)
    }
}
