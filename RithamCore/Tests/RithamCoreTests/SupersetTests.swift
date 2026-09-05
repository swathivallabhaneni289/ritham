import Testing
import Foundation
@testable import RithamCore

@Suite("SupersetTests")
struct SupersetTests {

    private static let minute: TimeInterval = 60

    private static func session(now: Date = Date()) -> LiftSession {
        LiftSession(
            startedAt: now,
            sets: [
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 0, completedAt: now),
                LiftSet(exerciseIdentifier: "backSquat", reps: 5, orderIndex: 1, completedAt: now.addingTimeInterval(minute)),
                LiftSet(exerciseIdentifier: "benchPress", reps: 5, orderIndex: 2, completedAt: now.addingTimeInterval(2 * minute)),
                LiftSet(exerciseIdentifier: "deadlift", reps: 5, orderIndex: 3, completedAt: now.addingTimeInterval(3 * minute))
            ]
        )
    }

    // MARK: - join

    @Test("joining two exercises assigns the same group ID to every working set of both, leaving others nil")
    func joinAssignsSameGroupIDToBothExercisesOnly() {
        let groupID = SupersetGroupID()
        let joined = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: Self.session(), groupID: groupID)

        let backSquatSets = joined.sets.filter { $0.exerciseIdentifier == "backSquat" }
        let benchSets = joined.sets.filter { $0.exerciseIdentifier == "benchPress" }
        let deadliftSets = joined.sets.filter { $0.exerciseIdentifier == "deadlift" }

        #expect(backSquatSets.allSatisfy { $0.supersetGroupID == groupID })
        #expect(benchSets.allSatisfy { $0.supersetGroupID == groupID })
        #expect(deadliftSets.allSatisfy { $0.supersetGroupID == nil })
    }

    @Test("joining preserves every set's id")
    func joinPreservesSetIDs() {
        let original = Self.session()
        let originalIDs = original.sets.map(\.id)

        let joined = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: original, groupID: SupersetGroupID())

        #expect(joined.sets.map(\.id) == originalIDs)
    }

    @Test("joining an exercise already in a different group moves it into the target group")
    func joinMovesExerciseFromAnotherGroupIntoTargetGroup() {
        let firstGroupID = SupersetGroupID()
        let secondGroupID = SupersetGroupID()

        let firstJoin = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "deadlift"], in: Self.session(), groupID: firstGroupID)
        let secondJoin = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: firstJoin, groupID: secondGroupID)

        let backSquatSets = secondJoin.sets.filter { $0.exerciseIdentifier == "backSquat" }
        let deadliftSets = secondJoin.sets.filter { $0.exerciseIdentifier == "deadlift" }
        let benchSets = secondJoin.sets.filter { $0.exerciseIdentifier == "benchPress" }

        #expect(backSquatSets.allSatisfy { $0.supersetGroupID == secondGroupID })
        #expect(benchSets.allSatisfy { $0.supersetGroupID == secondGroupID })
        // Deadlift never joined the second group, and its original group membership (first
        // group) is unaffected by an unrelated join elsewhere.
        #expect(deadliftSets.allSatisfy { $0.supersetGroupID == firstGroupID })
    }

    // MARK: - ungroup

    @Test("ungrouping clears the group ID on exactly the sets in that group and nothing else")
    func ungroupClearsOnlyThatGroup() {
        let targetGroupID = SupersetGroupID()
        let otherGroupID = SupersetGroupID()

        let joined = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: Self.session(), groupID: targetGroupID)
        let doubleJoined = SupersetGrouping.join(exerciseIdentifiers: ["deadlift"], in: joined, groupID: otherGroupID)

        let ungrouped = SupersetGrouping.ungroup(targetGroupID, in: doubleJoined)

        let backSquatSets = ungrouped.sets.filter { $0.exerciseIdentifier == "backSquat" }
        let benchSets = ungrouped.sets.filter { $0.exerciseIdentifier == "benchPress" }
        let deadliftSets = ungrouped.sets.filter { $0.exerciseIdentifier == "deadlift" }

        #expect(backSquatSets.allSatisfy { $0.supersetGroupID == nil })
        #expect(benchSets.allSatisfy { $0.supersetGroupID == nil })
        #expect(deadliftSets.allSatisfy { $0.supersetGroupID == otherGroupID })
    }

    @Test("ungrouping preserves every set's id")
    func ungroupPreservesSetIDs() {
        let joined = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: Self.session(), groupID: SupersetGroupID())
        let originalIDs = joined.sets.map(\.id)

        let ungrouped = SupersetGrouping.ungroup(SupersetGroupID(), in: joined)

        #expect(ungrouped.sets.map(\.id) == originalIDs)
    }

    // MARK: - groups(in:)

    @Test("groups(in:) returns an empty array for a session with no grouped sets")
    func groupsReturnsEmptyArrayForUngroupedSession() {
        #expect(SupersetGrouping.groups(in: Self.session()).isEmpty)
    }

    @Test("groups(in:) returns one entry per distinct non-nil group ID, in first-appearance order")
    func groupsReturnsOneEntryPerDistinctGroupIDInFirstAppearanceOrder() {
        let now = Date()
        let benchGroupID = SupersetGroupID()
        let deadliftGroupID = SupersetGroupID()

        var session = Self.session(now: now)
        session = SupersetGrouping.join(exerciseIdentifiers: ["benchPress"], in: session, groupID: benchGroupID)
        session = SupersetGrouping.join(exerciseIdentifiers: ["deadlift"], in: session, groupID: deadliftGroupID)

        let groups = SupersetGrouping.groups(in: session)

        #expect(groups.map(\.id) == [benchGroupID, deadliftGroupID])
    }

    @Test("groups(in:) includes every set id belonging to that group")
    func groupsIncludesEverySetIDInGroup() {
        let groupID = SupersetGroupID()
        let session = SupersetGrouping.join(exerciseIdentifiers: ["backSquat", "benchPress"], in: Self.session(), groupID: groupID)
        let expectedSetIDs = Set(session.sets.filter { $0.supersetGroupID == groupID }.map(\.id))

        let groups = SupersetGrouping.groups(in: session)

        #expect(groups.count == 1)
        #expect(Set(groups[0].setIDs) == expectedSetIDs)
    }

    // MARK: - Not an owning entity

    @Test("a superset is never modeled as a class or a persistence-owning entity")
    func supersetIsNeverAnOwningEntity() {
        // Structural assertion lives in the acceptance-criteria grep
        // (`class Superset\|@Model` must be absent from Superset.swift); this test documents
        // the same invariant at the value level: SupersetGroup is a plain value type.
        let group = SupersetGroup(id: SupersetGroupID(), setIDs: [])
        #expect(group.setIDs.isEmpty)
    }
}
