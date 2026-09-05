import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Task 1: SwiftData record models and container registration. `WorkoutSessionStoreTests` (Task
// 2) and `WorkoutPreferenceTests.swift` (Task 3) extend this file's suite family with
// `HealthDataStore`-level coverage; this suite covers only the four new `@Model` types and the
// container that registers them.
@MainActor
@Suite("WorkoutStoreTests")
struct WorkoutStoreTests {

    private func makeContext() throws -> ModelContext {
        let container = try RithamModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    @Test("an in-memory container builds successfully with all eight models registered")
    func containerBuildsWithAllModels() throws {
        _ = try RithamModelContainer.make(inMemory: true)
    }

    @Test("a CardioSessionRecord round-trips to its domain type with every field intact")
    func cardioSessionRoundTripsAllFields() throws {
        let context = try makeContext()

        let split = CardioSplit(
            index: 0,
            distanceMeters: 1000,
            duration: 300,
            averageSecondsPerKm: 300,
            elevationGainMeters: 12
        )
        let progress = CardioProgress(
            continuousDuration: 620,
            distanceMeters: 2000,
            elevationGainMeters: 24,
            splits: [split],
            horizontalConfidence: .high,
            elevationConfidence: .medium,
            wasInterrupted: true
        )
        let original = CardioSession(
            activityType: .run,
            source: .gps,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_620),
            progress: progress,
            notes: "felt good"
        )

        context.insert(CardioSessionRecord(session: original))
        try context.save()

        let records = try context.fetch(FetchDescriptor<CardioSessionRecord>())
        let reloaded = try #require(records.first?.session)

        #expect(reloaded.id == original.id)
        #expect(reloaded.activityType == original.activityType)
        #expect(reloaded.source == original.source)
        #expect(reloaded.startedAt == original.startedAt)
        #expect(reloaded.endedAt == original.endedAt)
        #expect(reloaded.progress.continuousDuration == original.progress.continuousDuration)
        #expect(reloaded.progress.distanceMeters == original.progress.distanceMeters)
        #expect(reloaded.progress.elevationGainMeters == original.progress.elevationGainMeters)
        #expect(reloaded.progress.splits.count == 1)
        #expect(reloaded.progress.splits[0].distanceMeters == split.distanceMeters)
        #expect(reloaded.progress.horizontalConfidence == .high)
        #expect(reloaded.progress.elevationConfidence == .medium)
        #expect(reloaded.progress.wasInterrupted == true)
        #expect(reloaded.notes == "felt good")
    }

    @Test("a CardioSessionRecord with an unrecognized raw value returns nil rather than trapping")
    func cardioSessionRecordReturnsNilForUnrecognizedRawValue() throws {
        let record = CardioSessionRecord(
            id: UUID(),
            activityTypeRaw: ActivityType.run.rawValue,
            sourceRaw: "not-a-real-source",
            startedAt: Date(),
            endedAt: Date(),
            continuousDuration: 600,
            distanceMeters: 1000,
            elevationGainMeters: 0,
            horizontalConfidenceRaw: SignalConfidence.high.rawValue,
            elevationConfidenceRaw: SignalConfidence.high.rawValue,
            wasInterrupted: false
        )

        #expect(record.session == nil)
    }

    @Test("two LiftSetRecords created in the same session have different identifiers")
    func liftSetRecordsHaveDistinctIdentifiersInSameSession() throws {
        let context = try makeContext()
        let sessionID = UUID()

        let first = LiftSetRecord(
            id: UUID(), sessionID: sessionID, exerciseIdentifier: "squat",
            reps: 5, orderIndex: 0, completedAt: Date()
        )
        let second = LiftSetRecord(
            id: UUID(), sessionID: sessionID, exerciseIdentifier: "squat",
            reps: 5, orderIndex: 1, completedAt: Date()
        )
        context.insert(first)
        context.insert(second)
        try context.save()

        #expect(first.id != second.id)

        let records = try context.fetch(FetchDescriptor<LiftSetRecord>())
        #expect(Set(records.map(\.id)).count == 2)
    }

    @Test("reassigning a LiftSetRecord's owning session is a plain field write, not a recreate")
    func liftSetRecordSessionIDReassignmentIsAFieldWrite() throws {
        let context = try makeContext()
        let originalSessionID = UUID()
        let newSessionID = UUID()
        let setID = UUID()

        let record = LiftSetRecord(
            id: setID, sessionID: originalSessionID, exerciseIdentifier: "bench",
            reps: 8, orderIndex: 0, completedAt: Date()
        )
        context.insert(record)
        try context.save()

        record.sessionID = newSessionID
        try context.save()

        let reloaded = try #require(try context.fetch(FetchDescriptor<LiftSetRecord>()).first)
        #expect(reloaded.id == setID)
        #expect(reloaded.sessionID == newSessionID)
    }

    @Test("a WorkoutPreferenceRecord persists the frequency and defaults its two flags to false")
    func workoutPreferenceRecordPersistsAndDefaultsFlags() throws {
        let context = try makeContext()

        let record = WorkoutPreferenceRecord(weeklyFrequency: 5)
        context.insert(record)
        try context.save()

        let reloaded = try #require(try context.fetch(FetchDescriptor<WorkoutPreferenceRecord>()).first)
        #expect(reloaded.weeklyFrequency == 5)
        #expect(reloaded.hasCompletedPreAssessment == false)
        #expect(reloaded.routeComparisonOptIn == false)
    }
}

// Task 2: session persistence accessors on `HealthDataStore`.
@MainActor
@Suite("WorkoutSessionStoreTests")
struct WorkoutSessionStoreTests {

    private func makeStore() throws -> (HealthDataStore, ModelContext) {
        let container = try RithamModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        return (HealthDataStore(context: context), context)
    }

    private func makeCardioSession(startedAt: Date, notes: String? = nil) -> CardioSession {
        CardioSession(
            activityType: .run,
            source: .gps,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(600),
            progress: CardioProgress(continuousDuration: 600, distanceMeters: 1500),
            notes: notes
        )
    }

    private func makeLiftSet(exercise: String, orderIndex: Int, completedAt: Date, isWarmUp: Bool = false) -> LiftSet {
        LiftSet(exerciseIdentifier: exercise, reps: 8, isWarmUp: isWarmUp, orderIndex: orderIndex, completedAt: completedAt)
    }

    @Test("saving then loading all cardio sessions returns every field intact, most recent first")
    func cardioSessionsRoundTripOrderedMostRecentFirst() throws {
        let (store, _) = try makeStore()
        let earlier = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000), notes: "earlier")
        let later = makeCardioSession(startedAt: Date(timeIntervalSince1970: 2_000), notes: "later")

        try store.saveCardioSession(earlier)
        try store.saveCardioSession(later)

        let loaded = try store.loadCardioSessions()
        #expect(loaded.count == 2)
        #expect(loaded[0].id == later.id)
        #expect(loaded[1].id == earlier.id)
        #expect(loaded[0].notes == "later")
    }

    @Test("cardio history can be filtered to a date range")
    func cardioSessionsFilterByDateRange() throws {
        let (store, _) = try makeStore()
        let inRange = makeCardioSession(startedAt: Date(timeIntervalSince1970: 5_000))
        let outOfRange = makeCardioSession(startedAt: Date(timeIntervalSince1970: 50_000))
        try store.saveCardioSession(inRange)
        try store.saveCardioSession(outOfRange)

        let filtered = try store.loadCardioSessions(in: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 10_000))
        #expect(filtered.map(\.id) == [inRange.id])
    }

    @Test("saving a lift session with three sets then loading returns them in ascending order index with identifiers unchanged")
    func liftSessionRoundTripsSetsInOrder() throws {
        let (store, _) = try makeStore()
        let base = Date(timeIntervalSince1970: 10_000)
        let sets = [
            makeLiftSet(exercise: "squat", orderIndex: 2, completedAt: base.addingTimeInterval(20)),
            makeLiftSet(exercise: "squat", orderIndex: 0, completedAt: base),
            makeLiftSet(exercise: "squat", orderIndex: 1, completedAt: base.addingTimeInterval(10)),
        ]
        let session = LiftSession(startedAt: base, sets: sets)

        try store.saveLiftSession(session)

        let loaded = try #require(try store.loadLiftSession(id: session.id))
        #expect(loaded.sets.map(\.orderIndex) == [0, 1, 2])
        #expect(Set(loaded.sets.map(\.id)) == Set(sets.map(\.id)))
    }

    @Test("autoFillSet returns the most recent working set for an exercise, and nil when never logged")
    func autoFillSetReturnsMostRecentWorkingSet() throws {
        let (store, _) = try makeStore()
        let olderSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeLiftSet(exercise: "bench", orderIndex: 0, completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        let newerSet = makeLiftSet(exercise: "bench", orderIndex: 0, completedAt: Date(timeIntervalSince1970: 2_000))
        let newerSession = LiftSession(startedAt: Date(timeIntervalSince1970: 2_000), sets: [newerSet])

        try store.saveLiftSession(olderSession)
        try store.saveLiftSession(newerSession)

        let autoFilled = try store.autoFillSet(forExercise: "bench")
        #expect(autoFilled?.id == newerSet.id)

        #expect(try store.autoFillSet(forExercise: "deadlift") == nil)
    }

    @Test("persisting a merge leaves one session holding the union of both inputs' sets, each identifier appearing exactly once")
    func applyRevisionPersistsMergeWithNoDuplicateSets() throws {
        let (store, _) = try makeStore()
        let base = Date(timeIntervalSince1970: 30_000)
        let first = LiftSession(
            startedAt: base,
            sets: [makeLiftSet(exercise: "squat", orderIndex: 0, completedAt: base)]
        )
        let second = LiftSession(
            startedAt: base.addingTimeInterval(3_600),
            sets: [makeLiftSet(exercise: "bench", orderIndex: 0, completedAt: base.addingTimeInterval(3_600))]
        )
        try store.saveLiftSession(first)
        try store.saveLiftSession(second)

        let merged = try #require(SessionRevision.merge(first, second))
        try store.applyRevision([merged], replacing: [first.id, second.id])

        let allSessions = try store.loadLiftSessions()
        #expect(allSessions.count == 1)
        let mergedSets = allSessions[0].sets
        #expect(mergedSets.count == 2)
        #expect(Set(mergedSets.map(\.id)) == Set([first.sets[0].id, second.sets[0].id]))
    }

    @Test("persisting a split leaves two sessions partitioning the original's sets, with no orphaned set record")
    func applyRevisionPersistsSplitWithNoOrphans() throws {
        let (store, context) = try makeStore()
        let base = Date(timeIntervalSince1970: 40_000)
        let original = LiftSession(
            startedAt: base,
            sets: [
                makeLiftSet(exercise: "squat", orderIndex: 0, completedAt: base),
                makeLiftSet(exercise: "bench", orderIndex: 1, completedAt: base.addingTimeInterval(600)),
            ]
        )
        try store.saveLiftSession(original)

        let (firstHalf, secondHalf) = try #require(SessionRevision.split(original, atSetIndex: 1))
        try store.applyRevision([firstHalf, secondHalf], replacing: [original.id])

        let allSessions = try store.loadLiftSessions()
        #expect(allSessions.count == 2)
        let allSetIDs = Set(allSessions.flatMap { $0.sets.map(\.id) })
        #expect(allSetIDs == Set(original.sets.map(\.id)))
        #expect(allSetIDs.count == 2)

        // No orphaned LiftSetRecord left behind after the split: the total stored count equals
        // the original session's set count exactly.
        let totalSetRecords = try context.fetch(FetchDescriptor<LiftSetRecord>())
        #expect(totalSetRecords.count == original.sets.count)
    }

    @Test("deleting a session deletes its set records too, leaving no orphans")
    func deletingLiftSessionLeavesNoOrphanedSets() throws {
        let (store, context) = try makeStore()
        let session = LiftSession(
            startedAt: Date(timeIntervalSince1970: 50_000),
            sets: [makeLiftSet(exercise: "row", orderIndex: 0, completedAt: Date(timeIntervalSince1970: 50_000))]
        )
        try store.saveLiftSession(session)

        try store.deleteLiftSession(id: session.id)

        #expect(try store.loadLiftSessions().isEmpty)
        let remainingSetRecords = try context.fetch(FetchDescriptor<LiftSetRecord>())
            .filter { $0.sessionID == session.id }
        #expect(remainingSetRecords.isEmpty)
    }
}
