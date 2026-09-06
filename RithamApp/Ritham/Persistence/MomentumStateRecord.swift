import Foundation
import SwiftData
import RithamCore

// The single upserted scalar row for Momentum state. Follows `WorkoutPreferenceRecord`'s
// single-row-upsert shape exactly (see that file). `HealthDataStore.upsertMomentumState`
// (plan 03-04) is this record's only write path -- create on first write, mutate in place
// afterwards, never delete-then-reinsert.
//
// `weeklyTarget` deliberately carries no instantiation default -- `HealthDataStore
// .loadMomentumTarget` supplies the stated default (`MomentumTarget.defaultTarget`) when no row
// exists, matching `loadWeeklyFrequency`'s documented "never bake a default into the model"
// discipline (see `WorkoutPreferenceRecord`'s own header comment for the precedent this mirrors).
//
// `visibilityScopeRaw` exists from day one per D-07 so Phase 4 can add a household scope later
// without a data migration -- the only value ever written in v1 is `MomentumVisibility
// .privateToDevice`'s raw value ("private").
@Model
public final class MomentumStateRecord {
    public var currentStreak: Int
    public var streakLabelKindRaw: String
    public var shieldCount: Int
    public var weeksTowardNextShield: Int
    public var lastReconciledWeekStart: Date?
    public var weeklyTarget: Int
    public var visibilityScopeRaw: String

    public init(
        currentStreak: Int,
        streakLabelKindRaw: String,
        shieldCount: Int,
        weeksTowardNextShield: Int,
        lastReconciledWeekStart: Date?,
        weeklyTarget: Int,
        visibilityScopeRaw: String
    ) {
        self.currentStreak = currentStreak
        self.streakLabelKindRaw = streakLabelKindRaw
        self.shieldCount = shieldCount
        self.weeksTowardNextShield = weeksTowardNextShield
        self.lastReconciledWeekStart = lastReconciledWeekStart
        self.weeklyTarget = weeklyTarget
        self.visibilityScopeRaw = visibilityScopeRaw
    }

    /// `nil` rather than a trap when `streakLabelKindRaw` no longer matches a known case
    /// (`CardioSessionRecord`'s undecodable-raw-value pattern, T-01-64) -- `HealthDataStore
    /// .loadMomentumLedger` falls back to `.fresh` when this is `nil`, never trapping.
    public var streakLabelKind: StreakLabelKind? {
        StreakLabelKind(rawValue: streakLabelKindRaw)
    }

    /// Same never-trapping discipline for `visibilityScopeRaw`. Per D-07 the only value ever
    /// written in v1 is `MomentumVisibility.privateToDevice`'s raw value.
    public var visibilityScope: MomentumVisibility? {
        MomentumVisibility(rawValue: visibilityScopeRaw)
    }
}
