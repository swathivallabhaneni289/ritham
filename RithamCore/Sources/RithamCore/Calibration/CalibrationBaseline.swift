import Foundation

// A CalibrationBaseline exists only to set safe initial targets for cardio pace and strength
// starting weight — it must never be surfaced to the user as an assessment of their fitness. Per
// D-04, these values are never rendered as a score, grade, level, percentile, or rating: this
// type deliberately declares no `CustomStringConvertible`, `displayName`, `level`, `score`,
// `grade`, `rating`, or `tier` property. `CalibrationBaselineTests` enforces this via reflection
// so a future edit cannot silently reintroduce one.

/// A comfortable pace-zone range, in seconds per kilometer.
///
/// This is always an interval, never a single number — a single number reads as a performance
/// figure, which D-04 forbids. `slowest` is always the larger seconds-per-km value (i.e. the
/// slower pace) regardless of the order arguments are supplied in.
public struct PaceZone: Sendable, Equatable {
    public let slowestSecondsPerKm: Double
    public let fastestSecondsPerKm: Double

    /// Orders the pair so `slowestSecondsPerKm` is always >= `fastestSecondsPerKm`, regardless
    /// of which order the two values are passed in.
    public init(_ a: Double, _ b: Double) {
        self.slowestSecondsPerKm = max(a, b)
        self.fastestSecondsPerKm = min(a, b)
    }
}

/// Where a `CalibrationBaseline`'s values came from.
public enum BaselineSource: String, Sendable, CaseIterable {
    /// Derived from a completed calibration session's actual measurements.
    case measured
    /// A conservative default used when calibration was skipped.
    case provisional
}

/// A user's starting cardio pace zone and strength starting weight.
///
/// Per D-04, this type must never expose anything that could be rendered as a score, grade,
/// level, percentile, or rating — see the file header comment.
public struct CalibrationBaseline: Sendable, Equatable {
    public let paceZone: PaceZone
    public let safeStartingWeightKg: Double
    public let source: BaselineSource
    public let establishedAt: Date

    public init(paceZone: PaceZone, safeStartingWeightKg: Double, source: BaselineSource, establishedAt: Date) {
        self.paceZone = paceZone
        self.safeStartingWeightKg = safeStartingWeightKg
        self.source = source
        self.establishedAt = establishedAt
    }

    /// A deliberately conservative, generic-but-usable baseline for a user who skips calibration.
    ///
    /// Per D-03, skipping calibration must still give cardio and strength suggestions something
    /// to work from, and must never block core app use — so this returns real conservative
    /// values, not zeros or optionals. The pace zone corresponds to a comfortable walk and the
    /// starting weight is deliberately light, chosen so that a skipped calibration errs toward
    /// under-loading rather than over-loading a user whose capacity is unknown.
    public static func provisional(establishedAt: Date) -> CalibrationBaseline {
        CalibrationBaseline(
            // A comfortable walking pace band, roughly 4.3-5.5 km/h (840-660 seconds/km) —
            // not a running pace. Chosen deliberately slow so a skipped calibration errs
            // toward under-loading rather than over-loading a user of unknown capacity.
            paceZone: PaceZone(840, 660),
            safeStartingWeightKg: 5, // a light, broadly safe starting load
            source: .provisional,
            establishedAt: establishedAt
        )
    }

    /// Derives a baseline from a calibration session's progress, or `nil` if that session did
    /// not qualify.
    ///
    /// A baseline is only derivable from a session `CalibrationCompletion.evaluate` reports as
    /// `.complete` — an incomplete session tells us nothing trustworthy. Because a walk measures
    /// pace but not strength, and a lift measures strength but not pace, the half of the
    /// baseline the session did not measure is carried forward from `provisional`'s conservative
    /// defaults rather than left blank.
    public static func derive(from progress: CalibrationProgress, establishedAt: Date) -> CalibrationBaseline? {
        guard CalibrationCompletion.evaluate(progress) == .complete else { return nil }

        let fallback = provisional(establishedAt: establishedAt)

        switch progress {
        case .walk(let walk):
            let paceZone: PaceZone
            if walk.distanceMeters > 0 {
                // Real average pace from the measured distance and duration, in seconds/km.
                let averageSecondsPerKm = walk.continuousDuration / (walk.distanceMeters / 1000)
                // Widen the observed average pace into a comfortable +/-10% band around it,
                // rather than exposing the single measured value as a target.
                let band = averageSecondsPerKm * 0.1
                paceZone = PaceZone(averageSecondsPerKm + band, averageSecondsPerKm - band)
            } else {
                // No distance was recorded (e.g. a duration-only stopwatch source) — there is
                // nothing to derive a real pace from, so carry the conservative provisional
                // pace zone forward instead of fabricating one from duration alone.
                paceZone = fallback.paceZone
            }
            return CalibrationBaseline(
                paceZone: paceZone,
                safeStartingWeightKg: fallback.safeStartingWeightKg,
                source: .measured,
                establishedAt: establishedAt
            )
        case .lift(let lift):
            let safeStartingWeightKg: Double
            if let averageLoad = lift.averageWorkingSetLoadKg, averageLoad > 0 {
                // A conservative fraction of the average working-set load actually recorded
                // during calibration, so the safe starting weight under-loads rather than
                // over-loads a user whose true capacity calibration only partially measured.
                safeStartingWeightKg = averageLoad * 0.6
            } else {
                // No load was recorded for any working set (e.g. a bodyweight-only session) —
                // carry the conservative provisional starting weight forward.
                safeStartingWeightKg = fallback.safeStartingWeightKg
            }
            return CalibrationBaseline(
                paceZone: fallback.paceZone,
                safeStartingWeightKg: safeStartingWeightKg,
                source: .measured,
                establishedAt: establishedAt
            )
        }
    }
}
