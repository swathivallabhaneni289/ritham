import Foundation

// RithamCore cannot import CoreLocation or CoreMotion — grade-adjusted pace is computed from
// plain numbers (a grade percentage and a raw pace), never from a live sensor reading directly.
//
// The adjustment below is grounded in the published Minetti et al. (2002) cost-of-transport-vs-
// grade curve, approximated with the practical percentage figures 02-RESEARCH.md cites (uphill
// ~2.5% additional cost per 1% of positive grade; downhill ~1.5% benefit per 1% of negative
// grade down to -10%, reversing past that point as eccentric braking cost rises again). This is
// deliberately NOT an attempt to reproduce Strava's or any other vendor's undocumented,
// proprietary GAP formula — 02-RESEARCH.md's Alternatives Considered table names that
// reverse-engineering approach explicitly and rejects it in favor of the public research
// grounding used here.

/// Grade-adjusted pace: how a raw pace should be interpreted once uphill/downhill grade is
/// factored in.
///
/// Per CARDIO-02 and 02-RESEARCH.md Pitfall 5, `adjustedSecondsPerKm` returns `nil` — never an
/// approximate number — whenever the elevation signal behind the grade is low confidence. There
/// is deliberately no overload or default argument that skips the confidence parameter: a caller
/// must be structurally unable to render a grade-adjusted number computed from a noisy elevation
/// signal.
public enum GradeAdjustedPace {
    /// Additional metabolic cost, as a fraction of pace, per 1% of positive (uphill) grade.
    private static let uphillCostPerGradePercent: Double = 0.025

    /// Benefit, as a fraction of pace, per 1% of negative (downhill) grade, up to the inflection
    /// point below.
    private static let downhillBenefitPerGradePercent: Double = 0.015

    /// Past this magnitude of negative grade, the downhill benefit reverses and cost rises again
    /// (eccentric braking on steep descents).
    private static let downhillInflectionGradePercent: Double = -10

    /// Additional cost, as a fraction of pace, per 1% of grade beyond the inflection point.
    private static let steepDownhillCostPerGradePercent: Double = 0.020

    /// The grade of a straight-line stretch, as a percentage (positive is uphill). Returns `nil`
    /// for a non-positive distance, since a grade cannot be computed without ground actually
    /// covered.
    public static func gradePercent(elevationGainMeters: Double, distanceMeters: Double) -> Double? {
        guard distanceMeters > 0 else { return nil }
        return (elevationGainMeters / distanceMeters) * 100
    }

    /// Adjusts a raw pace (seconds per kilometre) for grade.
    ///
    /// Returns `nil` when `elevationConfidence` is `.unavailable` or `.low` — the whole point of
    /// this function per 02-RESEARCH.md Pitfall 5 — or when `paceSecondsPerKm` is not positive.
    /// A caller must never see a grade-adjusted number derived from a noisy elevation signal.
    ///
    /// The result is `paceSecondsPerKm` divided by an effort factor derived from grade: climbing
    /// at a given raw pace reflects more work than that pace would on flat ground, so an effort
    /// factor above 1 (uphill) yields a *faster* (smaller) adjusted number — the flat-ground pace
    /// that would take equivalent effort. A moderate descent reduces effort (a factor below 1),
    /// so it yields a *slower* (larger) adjusted number. Per the Minetti-derived curve, that
    /// downhill benefit peaks at `downhillInflectionGradePercent` (-10%) and then reverses —
    /// eccentric braking on steeper descents raises the effort cost again — so a -20% grade
    /// yields a smaller (less generous) adjusted number than -10% does, not a larger one.
    public static func adjustedSecondsPerKm(
        paceSecondsPerKm: Double,
        gradePercent: Double,
        elevationConfidence: SignalConfidence
    ) -> Double? {
        guard elevationConfidence >= .medium else { return nil }
        guard paceSecondsPerKm > 0 else { return nil }

        let costFraction: Double
        if gradePercent > 0 {
            costFraction = gradePercent * uphillCostPerGradePercent
        } else if gradePercent >= downhillInflectionGradePercent {
            costFraction = gradePercent * downhillBenefitPerGradePercent
        } else {
            let inflectionCostFraction = downhillInflectionGradePercent * downhillBenefitPerGradePercent
            let gradePercentBeyondInflection = downhillInflectionGradePercent - gradePercent
            costFraction = inflectionCostFraction + gradePercentBeyondInflection * steepDownhillCostPerGradePercent
        }

        return paceSecondsPerKm / (1 + costFraction)
    }
}
