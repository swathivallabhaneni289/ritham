import Foundation
import SwiftData
import RithamCore

// The persisted calibration baseline. Per D-04, this exposes nothing that reads as a score,
// grade, level, or rating — the stored fields are exactly `CalibrationBaseline`'s own fields,
// nothing added. Per D-03, a skipped calibration is stored with the provisional source rather
// than left absent, so cardio/strength suggestions always have a floor to work from
// (`HealthDataStore.loadCalibrationBaseline` is what materializes the provisional record when
// none is stored yet).
@Model
public final class CalibrationBaselineRecord {
    public var slowestSecondsPerKm: Double
    public var fastestSecondsPerKm: Double
    public var safeStartingWeightKg: Double
    public var sourceRaw: String
    public var establishedAt: Date

    public init(
        slowestSecondsPerKm: Double,
        fastestSecondsPerKm: Double,
        safeStartingWeightKg: Double,
        sourceRaw: String,
        establishedAt: Date
    ) {
        self.slowestSecondsPerKm = slowestSecondsPerKm
        self.fastestSecondsPerKm = fastestSecondsPerKm
        self.safeStartingWeightKg = safeStartingWeightKg
        self.sourceRaw = sourceRaw
        self.establishedAt = establishedAt
    }

    /// `nil` rather than a trap when `sourceRaw` no longer matches a known `BaselineSource`
    /// case (T-01-64). `PaceZone.init(_:_:)` re-orders its two arguments internally (the
    /// larger seconds-per-km value always becomes `slowestSecondsPerKm`), so passing the
    /// stored pair back through it can never construct an inverted zone.
    public var baseline: CalibrationBaseline? {
        guard let source = BaselineSource(rawValue: sourceRaw) else { return nil }
        return CalibrationBaseline(
            paceZone: PaceZone(slowestSecondsPerKm, fastestSecondsPerKm),
            safeStartingWeightKg: safeStartingWeightKg,
            source: source,
            establishedAt: establishedAt
        )
    }
}
