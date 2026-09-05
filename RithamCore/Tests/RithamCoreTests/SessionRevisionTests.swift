import Testing
import Foundation
@testable import RithamCore

@Suite("SessionRevisionTests")
struct SessionRevisionTests {

    private static let minute: TimeInterval = 60

    /// Builds a session with `count` sets, each with a distinct `completedAt` (offset by
    /// `startOffsetMinutes` + one minute per set) so ordering assertions are never dependent on
    /// sort stability for ties.
    private static func session(
        startedAt: Date,
        startOffsetMinutes: Double = 0,
        count: Int,
        exercisePrefix: String = "exercise",
        groupID: SupersetGroupID? = nil
    ) -> LiftSession {
        let sets = (0..<count).map { index in
            LiftSet(
                exerciseIdentifier: "\(exercisePrefix)\(index)",
                reps: 5,
                supersetGroupID: index == 0 ? groupID : nil,
                orderIndex: index,
                completedAt: startedAt.addingTimeInterval((startOffsetMinutes + Double(index)) * minute)
            )
        }
        return LiftSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval((startOffsetMinutes + Double(count)) * minute), sets: sets)
    }

    // MARK: - merge

    @Test("merging two sessions yields a set count equal to the sum of the inputs, with every original id present exactly once")
    func mergeSetCountEqualsSumWithEveryIDOnce() {
        let now = Date()
        let first = Self.session(startedAt: now, count: 2, exercisePrefix: "a")
        let second = Self.session(startedAt: now, startOffsetMinutes: 10, count: 3, exercisePrefix: "b")

        let merged = SessionRevision.merge(first, second)

        #expect(merged?.sets.count == 5)
        let mergedIDs = Set(merged?.sets.map(\.id) ?? [])
        let originalIDs = Set(first.sets.map(\.id) + second.sets.map(\.id))
        #expect(mergedIDs == originalIDs)
        #expect(merged?.sets.count == mergedIDs.count)
    }

    @Test("supersetGroupID values are identical before and after merge for every set")
    func mergePreservesSupersetGroupID() {
        let now = Date()
        let groupID = SupersetGroupID()
        let first = Self.session(startedAt: now, count: 2, exercisePrefix: "a", groupID: groupID)
        let second = Self.session(startedAt: now, startOffsetMinutes: 10, count: 2, exercisePrefix: "b")

        guard let merged = SessionRevision.merge(first, second) else {
            Issue.record("expected a merged session")
            return
        }

        let originalGroupIDsByID = Dictionary(uniqueKeysWithValues: (first.sets + second.sets).map { ($0.id, $0.supersetGroupID) })
        for set in merged.sets {
            #expect(set.supersetGroupID == originalGroupIDsByID[set.id]!)
        }
    }

    @Test("after a merge, orderIndex values are contiguous from zero with no duplicates, ordered by completedAt")
    func mergeOrderIndexIsContiguousOrderedByCompletedAt() {
        let now = Date()
        let first = Self.session(startedAt: now, count: 2, exercisePrefix: "a")
        let second = Self.session(startedAt: now, startOffsetMinutes: 10, count: 3, exercisePrefix: "b")

        guard let merged = SessionRevision.merge(first, second) else {
            Issue.record("expected a merged session")
            return
        }

        let orderIndexes = merged.sets.map(\.orderIndex)
        #expect(orderIndexes == Array(0..<merged.sets.count))

        let sortedByCompletedAt = merged.sets.sorted { $0.completedAt < $1.completedAt }
        #expect(sortedByCompletedAt.map(\.id) == merged.sets.map(\.id))
    }

    @Test("merging a session with itself returns nil")
    func mergingSessionWithItselfReturnsNil() {
        let session = Self.session(startedAt: Date(), count: 2)

        #expect(SessionRevision.merge(session, session) == nil)
    }

    // MARK: - split

    @Test("splitting a session partitions its sets exactly — no loss, no duplication, every id preserved")
    func splitPartitionsSetsExactly() {
        let session = Self.session(startedAt: Date(), count: 5)

        guard let (first, second) = SessionRevision.split(session, atSetIndex: 2) else {
            Issue.record("expected a split result")
            return
        }

        #expect(first.sets.count == 2)
        #expect(second.sets.count == 3)

        let firstIDs = Set(first.sets.map(\.id))
        let secondIDs = Set(second.sets.map(\.id))
        #expect(firstIDs.isDisjoint(with: secondIDs))
        #expect(firstIDs.union(secondIDs) == Set(session.sets.map(\.id)))
    }

    @Test("split preserves the original session id in the first half and assigns a fresh id to the second half")
    func splitPreservesFirstHalfIDAndAssignsFreshSecondHalfID() {
        let session = Self.session(startedAt: Date(), count: 4)

        guard let (first, second) = SessionRevision.split(session, atSetIndex: 2) else {
            Issue.record("expected a split result")
            return
        }

        #expect(first.id == session.id)
        #expect(second.id != session.id)
    }

    @Test("split renumbers orderIndex contiguously within each result and preserves supersetGroupID")
    func splitRenumbersOrderIndexAndPreservesSupersetGroupID() {
        let groupID = SupersetGroupID()
        let session = Self.session(startedAt: Date(), count: 4, groupID: groupID)

        guard let (first, second) = SessionRevision.split(session, atSetIndex: 2) else {
            Issue.record("expected a split result")
            return
        }

        #expect(first.sets.map(\.orderIndex) == [0, 1])
        #expect(second.sets.map(\.orderIndex) == [0, 1])
        // groupID was assigned to the first set (index 0), which lands in the first half.
        #expect(first.sets[0].supersetGroupID == groupID)
        #expect(second.sets.allSatisfy { $0.supersetGroupID == nil })
    }

    @Test("split(session, atSetIndex: 0) returns nil")
    func splitAtIndexZeroReturnsNil() {
        let session = Self.session(startedAt: Date(), count: 3)

        #expect(SessionRevision.split(session, atSetIndex: 0) == nil)
    }

    @Test("split at the set count returns nil")
    func splitAtSetCountReturnsNil() {
        let session = Self.session(startedAt: Date(), count: 3)

        #expect(SessionRevision.split(session, atSetIndex: 3) == nil)
    }

    @Test("split on an empty session returns nil")
    func splitOnEmptySessionReturnsNil() {
        let session = LiftSession(startedAt: Date(), sets: [])

        #expect(SessionRevision.split(session, atSetIndex: 0) == nil)
    }
}
