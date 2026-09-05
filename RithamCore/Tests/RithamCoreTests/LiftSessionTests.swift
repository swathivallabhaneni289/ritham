import Testing
import Foundation
@testable import RithamCore

@Suite("LiftSessionTests")
struct LiftSessionTests {

    private static let minute: TimeInterval = 60

    // MARK: - LiftSet identity

    @Test("two LiftSet values with identical field values other than id are not equal")
    func identicalFieldValuesDifferentIDsAreNotEqual() {
        let completedAt = Date()
        let first = LiftSet(exerciseIdentifier: "backSquat", weightKg: 100, reps: 5, orderIndex: 0, completedAt: completedAt)
        let second = LiftSet(exerciseIdentifier: "backSquat", weightKg: 100, reps: 5, orderIndex: 0, completedAt: completedAt)

        #expect(first.id != second.id)
        #expect(first != second)
    }

    // MARK: - mostRecentSet auto-fill

    @Test("mostRecentSet returns the set from the latest-dated session containing the exercise")
    func mostRecentSetReturnsLatestSessionContainingExercise() {
        let now = Date()
        let olderSession = LiftSession(
            startedAt: now.addingTimeInterval(-2 * 86400),
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", weightKg: 90, reps: 5, orderIndex: 0, completedAt: now.addingTimeInterval(-2 * 86400))
            ]
        )
        let newerSessionWithoutExercise = LiftSession(
            startedAt: now.addingTimeInterval(-1 * 86400),
            sets: [
                LiftSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 5, orderIndex: 0, completedAt: now.addingTimeInterval(-1 * 86400))
            ]
        )

        let result = LiftSession.mostRecentSet(forExercise: "backSquat", in: [olderSession, newerSessionWithoutExercise])

        #expect(result?.weightKg == 90)
    }

    @Test("mostRecentSet returns nil when the exercise has never been logged")
    func mostRecentSetReturnsNilForNeverLoggedExercise() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [LiftSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 5, orderIndex: 0, completedAt: now)]
        )

        #expect(LiftSession.mostRecentSet(forExercise: "backSquat", in: [session]) == nil)
    }

    @Test("mostRecentSet returns the highest-orderIndex working set, excluding warm-ups")
    func mostRecentSetExcludesWarmUpSets() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", weightKg: 40, reps: 8, isWarmUp: true, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "backSquat", weightKg: 100, reps: 5, isWarmUp: false, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute))
            ]
        )

        let result = LiftSession.mostRecentSet(forExercise: "backSquat", in: [session])

        #expect(result?.weightKg == 100)
    }

    @Test("mostRecentSet returns nil when only warm-up sets exist for the exercise")
    func mostRecentSetReturnsNilWhenOnlyWarmUpSetsExist() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [LiftSet(exerciseIdentifier: "backSquat", weightKg: 40, reps: 8, isWarmUp: true, orderIndex: 0, completedAt: now)]
        )

        #expect(LiftSession.mostRecentSet(forExercise: "backSquat", in: [session]) == nil)
    }

    @Test("mostRecentSet never falls back to a different exercise")
    func mostRecentSetNeverFallsBackToADifferentExercise() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [LiftSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 5, orderIndex: 0, completedAt: now)]
        )

        #expect(LiftSession.mostRecentSet(forExercise: "overheadPress", in: [session]) == nil)
    }

    // MARK: - Working-set aggregates

    @Test("workingSetCount and distinctWorkingExercises exclude warm-up sets")
    func workingSetCountExcludesWarmUps() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 8, isWarmUp: true, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute)),
                LiftSet(exerciseIdentifier: "benchPress", reps: 5, orderIndex: 2, completedAt: now.addingTimeInterval(2 * Self.minute))
            ]
        )

        #expect(session.workingSetCount == 2)
        #expect(session.distinctWorkingExercises == 2)
    }

    @Test("movementPatterns unions patterns across every working set")
    func movementPatternsUnionsAcrossWorkingSets() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "benchPress", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute))
            ]
        )

        #expect(session.movementPatterns == [.squat, .push])
    }

    // MARK: - LiftQualification

    @Test("a session with enough working sets and exercises is complete")
    func qualifyingSessionIsComplete() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute)),
                LiftSet(exerciseIdentifier: "benchPress", reps: 5, orderIndex: 2, completedAt: now.addingTimeInterval(2 * Self.minute))
            ]
        )

        #expect(LiftQualification.evaluate(session) == .complete)
    }

    @Test("enough working sets but only one exercise is incomplete")
    func enoughSetsButOneExerciseIsIncomplete() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute)),
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 2, completedAt: now.addingTimeInterval(2 * Self.minute))
            ]
        )

        #expect(LiftQualification.evaluate(session) == .incomplete)
    }

    @Test("enough exercises but too few working sets is incomplete")
    func enoughExercisesButTooFewSetsIsIncomplete() {
        let now = Date()
        let session = LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "benchPress", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(Self.minute))
            ]
        )

        #expect(LiftQualification.evaluate(session) == .incomplete)
    }

    @Test("an empty session is incomplete")
    func emptySessionIsIncomplete() {
        let session = LiftSession(startedAt: Date(), sets: [])

        #expect(LiftQualification.evaluate(session) == .incomplete)
    }
}
