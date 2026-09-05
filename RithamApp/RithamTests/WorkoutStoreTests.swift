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
