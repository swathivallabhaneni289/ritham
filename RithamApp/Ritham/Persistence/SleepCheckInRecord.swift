import Foundation
import SwiftData
import RithamCore

// RECOVERY-01's daily sleep self-report: one row per calendar day, upserting on a repeat entry
// for the same day (`HealthDataStore.saveSleepCheckIn`). Follows `CardioSessionRecord`'s shape --
// plain stored properties, one raw-value column for the enum, a convenience init from the
// RithamCore domain value, and a computed property returning that domain value or `nil` (never
// trapping) when the raw value no longer decodes.
//
// This record is never read by Momentum reconciliation. No method anywhere in `HealthDataStore`
// reads this record type and writes a `MomentumStateRecord`/`MilestoneAwardRecord`/
// `ComebackWindowRecord`/`RecoveryWeekPeriodRecord`/`InjuryFreezePeriodRecord` field, and this file
// references none of those types by name. Per D-03/D-04, that absence is what makes RECOVERY-01's
// "never auto-consumes a shield" and "never auto-triggers a Recovery Week" invariants structurally
// true, not merely untested.
@Model
public final class SleepCheckInRecord {
    public var id: UUID
    public var day: Date
    public var qualityRaw: String
    public var note: String?

    public init(id: UUID, day: Date, qualityRaw: String, note: String?) {
        self.id = id
        self.day = day
        self.qualityRaw = qualityRaw
        self.note = note
    }

    public convenience init(checkIn: SleepCheckIn) {
        self.init(id: checkIn.id, day: checkIn.day, qualityRaw: checkIn.quality.rawValue, note: checkIn.note)
    }

    /// `nil` when `qualityRaw` no longer matches a known `SleepQuality` case (T-01-64's pattern),
    /// never a trap.
    public var checkIn: SleepCheckIn? {
        guard let quality = SleepQuality(rawValue: qualityRaw) else { return nil }
        return SleepCheckIn(id: id, day: day, quality: quality, note: note)
    }
}
