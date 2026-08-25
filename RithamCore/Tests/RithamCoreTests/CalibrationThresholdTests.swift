import Testing
@testable import RithamCore

@Suite("CalibrationThresholdTests")
struct CalibrationThresholdTests {

    // MARK: - Threshold constants

    @Test("the three threshold constants equal 600, 3, and 2")
    func thresholdConstantsMatchLockedValues() {
        #expect(CalibrationThreshold.qualifyingWalkDuration == 600)
        #expect(CalibrationThreshold.qualifyingWorkingSets == 3)
        #expect(CalibrationThreshold.qualifyingExercises == 2)
    }

    // MARK: - Walk mode

    @Test("a walk at 599 seconds is incomplete")
    func walkAt599SecondsIsIncomplete() {
        let progress = CalibrationProgress.walk(WalkProgress(continuousDuration: 599))
        #expect(CalibrationCompletion.evaluate(progress) == .incomplete)
    }

    @Test("a walk at exactly 600 seconds is complete")
    func walkAt600SecondsIsComplete() {
        let progress = CalibrationProgress.walk(WalkProgress(continuousDuration: 600))
        #expect(CalibrationCompletion.evaluate(progress) == .complete)
    }

    @Test("a walk at 601 seconds is complete")
    func walkAt601SecondsIsComplete() {
        let progress = CalibrationProgress.walk(WalkProgress(continuousDuration: 601))
        #expect(CalibrationCompletion.evaluate(progress) == .complete)
    }

    @Test("a walk that reaches 600 seconds then is interrupted is incomplete afterward, with wasInterrupted true")
    func walkInterruptedAfterQualifyingResetsToIncomplete() {
        var walk = WalkProgress(continuousDuration: 600)
        #expect(CalibrationCompletion.evaluate(.walk(walk)) == .complete)

        walk.recordInterruption()

        #expect(walk.continuousDuration == 0)
        #expect(walk.wasInterrupted == true)
        #expect(CalibrationCompletion.evaluate(.walk(walk)) == .incomplete)
    }

    // MARK: - Lift mode

    @Test("3 sets across 1 exercise is incomplete — the superseded D-01 wording would have wrongly accepted this")
    func threeSetsAcrossOneExerciseIsIncomplete() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "squat")

        #expect(lift.totalWorkingSets == 3)
        #expect(lift.distinctExercises == 1)
        #expect(CalibrationCompletion.evaluate(.lift(lift)) == .incomplete)
    }

    @Test("2 sets across 2 exercises is incomplete")
    func twoSetsAcrossTwoExercisesIsIncomplete() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "bench")

        #expect(lift.totalWorkingSets == 2)
        #expect(lift.distinctExercises == 2)
        #expect(CalibrationCompletion.evaluate(.lift(lift)) == .incomplete)
    }

    @Test("exactly 3 sets across 2 exercises is complete")
    func exactlyThreeSetsAcrossTwoExercisesIsComplete() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "bench")

        #expect(lift.totalWorkingSets == 3)
        #expect(lift.distinctExercises == 2)
        #expect(CalibrationCompletion.evaluate(.lift(lift)) == .complete)
    }

    @Test("4 sets across 3 exercises is complete")
    func fourSetsAcrossThreeExercisesIsComplete() {
        var lift = LiftProgress()
        lift.recordWorkingSet(exercise: "squat")
        lift.recordWorkingSet(exercise: "bench")
        lift.recordWorkingSet(exercise: "row")
        lift.recordWorkingSet(exercise: "squat")

        #expect(lift.totalWorkingSets == 4)
        #expect(lift.distinctExercises == 3)
        #expect(CalibrationCompletion.evaluate(.lift(lift)) == .complete)
    }

    @Test("an empty lift progress is incomplete")
    func emptyLiftProgressIsIncomplete() {
        let lift = LiftProgress()
        #expect(CalibrationCompletion.evaluate(.lift(lift)) == .incomplete)
    }
}
