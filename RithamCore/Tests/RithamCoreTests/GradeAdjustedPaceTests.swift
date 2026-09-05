import Testing
@testable import RithamCore

@Suite("GradeAdjustedPaceTests")
struct GradeAdjustedPaceTests {

    // MARK: - gradePercent

    @Test("gradePercent returns nil for a non-positive distance")
    func gradePercentReturnsNilForNonPositiveDistance() {
        #expect(GradeAdjustedPace.gradePercent(elevationGainMeters: 10, distanceMeters: 0) == nil)
        #expect(GradeAdjustedPace.gradePercent(elevationGainMeters: 10, distanceMeters: -5) == nil)
    }

    @Test("gradePercent computes elevation gain as a percentage of distance")
    func gradePercentComputesElevationOverDistance() {
        #expect(GradeAdjustedPace.gradePercent(elevationGainMeters: 50, distanceMeters: 1_000) == 5)
    }

    // MARK: - adjustedSecondsPerKm: direction of adjustment

    @Test("zero grade returns the input pace unchanged")
    func zeroGradeReturnsInputPaceUnchanged() {
        let adjusted = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 0,
            elevationConfidence: .high
        )
        #expect(adjusted == 300)
    }

    @Test("a +5% grade returns a faster (smaller) adjusted pace than the raw pace")
    func positiveGradeReturnsFasterAdjustedPace() {
        let adjusted = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 5,
            elevationConfidence: .high
        )
        #expect(adjusted != nil)
        #expect(adjusted! < 300)
    }

    @Test("a -5% grade returns a slower (larger) adjusted pace than the raw pace")
    func negativeGradeReturnsSlowerAdjustedPace() {
        let adjusted = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: -5,
            elevationConfidence: .high
        )
        #expect(adjusted != nil)
        #expect(adjusted! > 300)
    }

    @Test("a -20% grade is less favourable (a smaller adjusted number) than a -10% grade, reflecting the curve steepening past -10%")
    func steepDownhillReversesBenefitPastInflection() {
        let atInflection = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: -10,
            elevationConfidence: .high
        )
        let pastInflection = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: -20,
            elevationConfidence: .high
        )
        #expect(atInflection != nil)
        #expect(pastInflection != nil)
        #expect(pastInflection! < atInflection!)
    }

    // MARK: - adjustedSecondsPerKm: elevation-confidence gating

    @Test("adjustedSecondsPerKm returns nil for .unavailable elevation confidence, for every grade including 0")
    func returnsNilForUnavailableConfidenceAtEveryGrade() {
        for grade in [-20.0, -10.0, -5.0, 0.0, 5.0] {
            #expect(GradeAdjustedPace.adjustedSecondsPerKm(
                paceSecondsPerKm: 300,
                gradePercent: grade,
                elevationConfidence: .unavailable
            ) == nil)
        }
    }

    @Test("adjustedSecondsPerKm returns nil for .low elevation confidence, for every grade including 0")
    func returnsNilForLowConfidenceAtEveryGrade() {
        for grade in [-20.0, -10.0, -5.0, 0.0, 5.0] {
            #expect(GradeAdjustedPace.adjustedSecondsPerKm(
                paceSecondsPerKm: 300,
                gradePercent: grade,
                elevationConfidence: .low
            ) == nil)
        }
    }

    @Test("adjustedSecondsPerKm returns a value for .medium elevation confidence")
    func returnsValueForMediumConfidence() {
        #expect(GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 5,
            elevationConfidence: .medium
        ) != nil)
    }

    @Test("adjustedSecondsPerKm returns a value for .high elevation confidence")
    func returnsValueForHighConfidence() {
        #expect(GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 5,
            elevationConfidence: .high
        ) != nil)
    }

    @Test("adjustedSecondsPerKm(paceSecondsPerKm: 300, gradePercent: 0, elevationConfidence: .low) is nil")
    func acceptanceCriterionExactCall() {
        #expect(GradeAdjustedPace.adjustedSecondsPerKm(paceSecondsPerKm: 300, gradePercent: 0, elevationConfidence: .low) == nil)
    }

    // MARK: - adjustedSecondsPerKm: pace validation

    @Test("a non-positive input pace returns nil rather than a computed value")
    func nonPositivePaceReturnsNil() {
        #expect(GradeAdjustedPace.adjustedSecondsPerKm(paceSecondsPerKm: 0, gradePercent: 0, elevationConfidence: .high) == nil)
        #expect(GradeAdjustedPace.adjustedSecondsPerKm(paceSecondsPerKm: -10, gradePercent: 0, elevationConfidence: .high) == nil)
    }
}
