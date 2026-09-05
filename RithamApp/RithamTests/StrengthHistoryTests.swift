import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Phase 2 Plan 15's strength-history test suites, at the model level per the plan's own explicit
// instruction (not by rendering) -- the same discipline `CardioViewTests.swift` already uses.
// `StrengthHistoryFilterTests` (Task 1) is followed by `YearJumpNavigationTests` (Task 2) and
// `SessionRevisionScreenTests` (Task 3) as this same file grows across the plan's tasks.
@MainActor
@Suite("StrengthHistoryFilterTests")
struct StrengthHistoryFilterTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeSet(
        exercise: String,
        orderIndex: Int = 0,
        completedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> LiftSet {
        LiftSet(exerciseIdentifier: exercise, reps: 5, orderIndex: orderIndex, completedAt: completedAt)
    }

    @Test("registers as the strength-history step")
    func registersAsHistoryStep() {
        #expect(StrengthHistoryView.step == .strengthHistory)
    }

    @Test("an empty store yields the empty-history state rather than an empty list")
    func emptyStoreYieldsEmptyHistoryState() throws {
        let store = try makeStore()
        let model = StrengthHistoryModel(store: store)

        model.load()

        #expect(model.isEmpty)
        #expect(model.hasNoResults == false)
        #expect(model.filteredSessions.isEmpty)
    }

    @Test("loading returns sessions most recent first with the store's own ordering")
    func loadingReturnsSessionsMostRecentFirst() throws {
        let store = try makeStore()
        let earlier = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeSet(exercise: "backSquat", completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        let later = LiftSession(
            startedAt: Date(timeIntervalSince1970: 2_000),
            sets: [makeSet(exercise: "benchPress", completedAt: Date(timeIntervalSince1970: 2_000))]
        )
        try store.saveLiftSession(earlier)
        try store.saveLiftSession(later)

        let model = StrengthHistoryModel(store: store)
        model.load()

        #expect(model.sessions.first?.id == later.id)
        #expect(model.isEmpty == false)
    }

    @Test("a pattern filter narrows to sessions containing at least one selected pattern")
    func filterNarrowsToMatchingPattern() throws {
        let store = try makeStore()
        let squatSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeSet(exercise: "backSquat", completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        let pullSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 2_000),
            sets: [makeSet(exercise: "pullUp", completedAt: Date(timeIntervalSince1970: 2_000))]
        )
        try store.saveLiftSession(squatSession)
        try store.saveLiftSession(pullSession)

        let model = StrengthHistoryModel(store: store)
        model.load()
        model.togglePattern(.squat)

        let matchedIDs = Set(model.filteredSessions.map(\.id))
        #expect(matchedIDs.contains(squatSession.id))
        #expect(matchedIDs.contains(pullSession.id) == false)
    }

    @Test("a session containing a two-pattern compound lift is returned by a filter on each of those patterns independently")
    func compoundLiftMatchesEveryPatternItTrains() throws {
        let store = try makeStore()
        // "thruster" trains both .squat and .push (ExerciseCatalog).
        let session = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeSet(exercise: "thruster", completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        try store.saveLiftSession(session)

        let squatModel = StrengthHistoryModel(store: store)
        squatModel.load()
        squatModel.togglePattern(.squat)
        #expect(squatModel.filteredSessions.map(\.id).contains(session.id))

        let pushModel = StrengthHistoryModel(store: store)
        pushModel.load()
        pushModel.togglePattern(.push)
        #expect(pushModel.filteredSessions.map(\.id).contains(session.id))
    }

    @Test("clearing the filter restores the full list")
    func clearingFilterRestoresFullList() throws {
        let store = try makeStore()
        let squatSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeSet(exercise: "backSquat", completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        let pullSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 2_000),
            sets: [makeSet(exercise: "pullUp", completedAt: Date(timeIntervalSince1970: 2_000))]
        )
        try store.saveLiftSession(squatSession)
        try store.saveLiftSession(pullSession)

        let model = StrengthHistoryModel(store: store)
        model.load()
        model.togglePattern(.squat)
        #expect(model.filteredSessions.count == 1)

        model.clearPatternFilter()

        #expect(model.filteredSessions.count == 2)
    }

    @Test("a filter matching nothing shows the no-results state, distinct from the empty-history state")
    func filterMatchingNothingShowsNoResultsState() throws {
        let store = try makeStore()
        let squatSession = LiftSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            sets: [makeSet(exercise: "backSquat", completedAt: Date(timeIntervalSince1970: 1_000))]
        )
        try store.saveLiftSession(squatSession)

        let model = StrengthHistoryModel(store: store)
        model.load()
        model.togglePattern(.carry)

        #expect(model.hasNoResults)
        #expect(model.isEmpty == false)
        #expect(model.filteredSessions.isEmpty)
    }
}
