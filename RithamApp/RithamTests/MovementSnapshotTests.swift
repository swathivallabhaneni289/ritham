import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("MovementSnapshotTests", .serialized)
    struct MovementSnapshotTests {

        private let calendar = Calendar(identifier: .gregorian)

        /// Builds an in-memory container over the full `RithamModelContainer` model list, the
        /// same helper shape `MomentumStoreTests` uses.
        private func makeStore() throws -> (store: HealthDataStore, context: ModelContext) {
            let container = try RithamModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            return (HealthDataStore(context: context, calendar: calendar), context)
        }

        // MARK: - Movement Snapshot opt-in

        @Test("the Movement Snapshot opt-in defaults to false on an empty store")
        func snapshotOptInDefaultsFalse() throws {
            let (store, _) = try makeStore()
            #expect(try store.loadMovementSnapshotOptIn() == false)
        }

        @Test("the Movement Snapshot opt-in round-trips both ways")
        func snapshotOptInRoundTripsBothWays() throws {
            let (store, _) = try makeStore()

            try store.saveMovementSnapshotOptIn(true)
            #expect(try store.loadMovementSnapshotOptIn() == true)

            try store.saveMovementSnapshotOptIn(false)
            #expect(try store.loadMovementSnapshotOptIn() == false)
        }

        // MARK: - Sleep check-in round trip

        @Test("a sleep check-in round-trips including its optional note")
        func sleepCheckInRoundTripsWithNote() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())
            let checkIn = SleepCheckIn(day: day, quality: .poor, note: "Woke up twice")

            try store.saveSleepCheckIn(checkIn)

            #expect(try store.loadSleepCheckIn(on: day) == checkIn)
        }

        @Test("a sleep check-in round-trips with a nil note")
        func sleepCheckInRoundTripsWithNilNote() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())
            let checkIn = SleepCheckIn(day: day, quality: .great, note: nil)

            try store.saveSleepCheckIn(checkIn)

            #expect(try store.loadSleepCheckIn(on: day) == checkIn)
        }

        @Test("saving a second check-in for the same calendar day replaces the first")
        func savingSecondCheckInForSameDayReplacesFirst() throws {
            let (store, context) = try makeStore()
            let day = calendar.startOfDay(for: Date())

            try store.saveSleepCheckIn(SleepCheckIn(day: day, quality: .great, note: "First"))
            let second = SleepCheckIn(day: day, quality: .poor, note: "Second")
            try store.saveSleepCheckIn(second)

            let stored = try context.fetch(FetchDescriptor<SleepCheckInRecord>())
            #expect(stored.count == 1)
            #expect(try store.loadSleepCheckIn(on: day) == second)
        }

        @Test("saving check-ins for two different days stores two rows")
        func savingCheckInsForTwoDifferentDaysStoresTwoRows() throws {
            let (store, context) = try makeStore()
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

            try store.saveSleepCheckIn(SleepCheckIn(day: today, quality: .ok, note: nil))
            try store.saveSleepCheckIn(SleepCheckIn(day: yesterday, quality: .poor, note: nil))

            let stored = try context.fetch(FetchDescriptor<SleepCheckInRecord>())
            #expect(stored.count == 2)
        }

        // MARK: - movementSnapshotDays(in:)

        @Test("movementSnapshotDays marks a day containing a stored cardio session")
        func movementSnapshotDaysMarksCardioDay() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())
            try store.saveCardioSession(CardioSession(
                activityType: .run,
                source: .gps,
                startedAt: day.addingTimeInterval(3_600),
                endedAt: day.addingTimeInterval(5_400),
                progress: CardioProgress(continuousDuration: 1_800, distanceMeters: 5_000)
            ))

            let range = day...calendar.date(byAdding: .day, value: 1, to: day)!
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.hasLoggedActivity == true)
        }

        @Test("movementSnapshotDays marks a day containing a stored lift session")
        func movementSnapshotDaysMarksLiftDay() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())
            try store.saveLiftSession(LiftSession(startedAt: day.addingTimeInterval(3_600), sets: []))

            let range = day...calendar.date(byAdding: .day, value: 1, to: day)!
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.hasLoggedActivity == true)
        }

        @Test("movementSnapshotDays leaves a day with neither modality unmarked")
        func movementSnapshotDaysLeavesEmptyDayUnmarked() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())

            let range = day...calendar.date(byAdding: .day, value: 1, to: day)!
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.allSatisfy { $0.hasLoggedActivity == false })
        }

        @Test("movementSnapshotDays marks a day containing a session that does not clear the qualification bar")
        func movementSnapshotDaysMarksNonQualifyingSessionDay() throws {
            let (store, _) = try makeStore()
            let day = calendar.startOfDay(for: Date())
            // Well under CalibrationThreshold.qualifyingWalkDuration (600s) -- logged, but not
            // qualifying. The snapshot has no target of its own, so it still marks the day.
            try store.saveCardioSession(CardioSession(
                activityType: .run,
                source: .gps,
                startedAt: day.addingTimeInterval(3_600),
                endedAt: day.addingTimeInterval(3_720),
                progress: CardioProgress(continuousDuration: 120, distanceMeters: 300)
            ))

            let range = day...calendar.date(byAdding: .day, value: 1, to: day)!
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.hasLoggedActivity == true)
        }

        @Test("movementSnapshotDayCarriesNoMomentumState")
        func movementSnapshotDayCarriesNoMomentumState() {
            let day = HealthDataStore.MovementSnapshotDay(date: Date(), hasLoggedActivity: true)
            let mirror = Mirror(reflecting: day)
            let labels = Set(mirror.children.compactMap(\.label))
            #expect(labels == ["date", "hasLoggedActivity"])
        }
    }
}
