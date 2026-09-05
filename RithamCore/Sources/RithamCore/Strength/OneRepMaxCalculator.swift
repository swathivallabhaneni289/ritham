import Foundation

// This estimator exists because MONETIZE-01's always-free list names a 1RM calculator
// explicitly (PROJECT.md's Business Context: "plate/1RM calculators" are permanently free) —
// without it, that claim would be aspirational rather than truthful. Per D-04's standing rule
// (`Calibration/CalibrationBaseline.swift`'s file header), the result below must be presented as
// an estimate a user can act on, never as a score, grade, level, percentile, or rating: this type
// deliberately declares no property named any of those things.

/// A one-rep-max estimator using the Epley formula.
public enum OneRepMaxCalculator {
    /// The Epley formula's coefficient: `weight * (1 + reps / epleyRepDivisor)`.
    private static let epleyRepDivisor: Double = 30

    /// The rep range this estimator supports. Submaximal-rep formulas are not valid at high rep
    /// counts, so a rep count outside this range returns `nil` rather than silently
    /// extrapolating a number.
    private static let supportedRepRange: ClosedRange<Int> = 1...12

    /// Estimates a one-rep max from a weight lifted for a given rep count, using the Epley
    /// formula.
    ///
    /// Returns `nil` for a non-positive or non-finite weight, or a rep count outside
    /// `supportedRepRange`.
    public static func estimate(weightKg: Double, reps: Int) -> Double? {
        guard weightKg.isFinite, weightKg > 0 else { return nil }
        guard supportedRepRange.contains(reps) else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / epleyRepDivisor)
    }
}
