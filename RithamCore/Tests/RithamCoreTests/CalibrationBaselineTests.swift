import Foundation
import Testing
@testable import RithamCore

@Suite("CalibrationBaselineTests")
struct CalibrationBaselineTests {

    // MARK: - PaceZone normalisation

    @Test("PaceZone normalises reversed arguments so slowest is always the larger seconds-per-km value")
    func paceZoneNormalisesReversedArguments() {
        let ascending = PaceZone(360, 420)
        let descending = PaceZone(420, 360)

        #expect(ascending.slowestSecondsPerKm == 420)
        #expect(ascending.fastestSecondsPerKm == 360)
        #expect(descending.slowestSecondsPerKm == 420)
        #expect(descending.fastestSecondsPerKm == 360)
    }

    // MARK: - provisional

    @Test("provisional returns source == .provisional with a non-zero pace zone and starting weight")
    func provisionalIsNeverBlank() {
        let baseline = CalibrationBaseline.provisional(establishedAt: Date())

        #expect(baseline.source == .provisional)
        #expect(baseline.paceZone.slowestSecondsPerKm > 0)
        #expect(baseline.paceZone.fastestSecondsPerKm > 0)
        #expect(baseline.safeStartingWeightKg > 0)
    }

    // MARK: - derive: incomplete sessions

    @Test("derive returns nil for an incomplete walk")
    func deriveReturnsNilForIncompleteWalk() {
        let progress = CalibrationProgress.walk(WalkProgress(continuousDuration: 100, distanceMeters: 200))
        #expect(CalibrationBaseline.derive(from: progress, establishedAt: Date()) == nil)
    }

    @Test("derive returns nil for an incomplete lift")
    func deriveReturnsNilForIncompleteLift() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat", loadKg: 20)
        let progress = CalibrationProgress.lift(lift)
        #expect(CalibrationBaseline.derive(from: progress, establishedAt: Date()) == nil)
    }

    // MARK: - derive: completed sessions

    @Test("derive returns source == .measured for a completed walk")
    func deriveReturnsMeasuredForCompletedWalk() {
        let progress = CalibrationProgress.walk(
            WalkProgress(continuousDuration: 600, distanceMeters: 800)
        )
        let baseline = CalibrationBaseline.derive(from: progress, establishedAt: Date())

        #expect(baseline?.source == .measured)
    }

    @Test("derive returns source == .measured for a completed lift")
    func deriveReturnsMeasuredForCompletedLift() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat", loadKg: 20)
        lift.recordWorkingSet(exercise: "squat", loadKg: 20)
        lift.recordWorkingSet(exercise: "bench", loadKg: 15)
        let baseline = CalibrationBaseline.derive(from: .lift(lift), establishedAt: Date())

        #expect(baseline?.source == .measured)
    }

    @Test("a derived walk baseline has a pace zone whose slowest value is strictly greater than its fastest")
    func derivedWalkPaceZoneIsAStrictInterval() {
        let progress = CalibrationProgress.walk(
            WalkProgress(continuousDuration: 600, distanceMeters: 800)
        )
        let baseline = CalibrationBaseline.derive(from: progress, establishedAt: Date())

        #expect(baseline != nil)
        if let baseline {
            #expect(baseline.paceZone.slowestSecondsPerKm > baseline.paceZone.fastestSecondsPerKm)
        }
    }

    @Test("a walk covering more distance in the same duration derives a faster (lower) pace than one covering less")
    func fasterMeasuredWalkDerivesALowerPace() {
        let slowerWalk = CalibrationProgress.walk(
            WalkProgress(continuousDuration: 600, distanceMeters: 600)
        )
        let fasterWalk = CalibrationProgress.walk(
            WalkProgress(continuousDuration: 600, distanceMeters: 1200)
        )

        let slowerBaseline = CalibrationBaseline.derive(from: slowerWalk, establishedAt: Date())
        let fasterBaseline = CalibrationBaseline.derive(from: fasterWalk, establishedAt: Date())

        #expect(slowerBaseline != nil)
        #expect(fasterBaseline != nil)
        if let slowerBaseline, let fasterBaseline {
            #expect(fasterBaseline.paceZone.fastestSecondsPerKm < slowerBaseline.paceZone.fastestSecondsPerKm)
        }
    }

    @Test("a lift recording higher average load derives a higher safe starting weight than one recording lower load")
    func higherLoadedLiftDerivesAHigherStartingWeight() {
        var lightLift = LiftProgress()
        lightLift.recordWorkingSet(exercise: "squat", loadKg: 10)
        lightLift.recordWorkingSet(exercise: "squat", loadKg: 10)
        lightLift.recordWorkingSet(exercise: "bench", loadKg: 10)

        var heavyLift = LiftProgress()
        heavyLift.recordWorkingSet(exercise: "squat", loadKg: 40)
        heavyLift.recordWorkingSet(exercise: "squat", loadKg: 40)
        heavyLift.recordWorkingSet(exercise: "bench", loadKg: 40)

        let lightBaseline = CalibrationBaseline.derive(from: .lift(lightLift), establishedAt: Date())
        let heavyBaseline = CalibrationBaseline.derive(from: .lift(heavyLift), establishedAt: Date())

        #expect(lightBaseline != nil)
        #expect(heavyBaseline != nil)
        if let lightBaseline, let heavyBaseline {
            #expect(heavyBaseline.safeStartingWeightKg > lightBaseline.safeStartingWeightKg)
        }
    }

    // MARK: - D-04 guard: no score-like member

    @Test("CalibrationBaseline has no member whose name contains score, grade, level, or rating")
    func noScoreLikeMemberExists() {
        let baseline = CalibrationBaseline.provisional(establishedAt: Date())
        let forbiddenSubstrings = ["score", "grade", "level", "rating"]

        let mirror = Mirror(reflecting: baseline)
        for child in mirror.children {
            guard let label = child.label else { continue }
            let lowered = label.lowercased()
            for forbidden in forbiddenSubstrings {
                #expect(
                    !lowered.contains(forbidden),
                    "CalibrationBaseline member '\(label)' contains forbidden substring '\(forbidden)'"
                )
            }
        }
    }
}
