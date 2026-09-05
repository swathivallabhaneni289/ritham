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

@MainActor
@Suite("YearJumpNavigationTests")
struct YearJumpNavigationTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeSet(
        exercise: String,
        orderIndex: Int = 0,
        completedAt: Date
    ) -> LiftSet {
        LiftSet(exerciseIdentifier: exercise, reps: 5, orderIndex: orderIndex, completedAt: completedAt)
    }

    private func date(year: Int, month: Int, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    @Test("only years containing stored sessions are offered")
    func onlyYearsWithSessionsAreOffered() {
        let dates = [date(year: 2024, month: 3), date(year: 2026, month: 1)]
        let years = YearJumpDatePicker.availableYears(in: dates)
        #expect(years == [2026, 2024])
    }

    @Test("with no stored sessions, no years are offered")
    func noSessionsOffersNoYears() {
        #expect(YearJumpDatePicker.availableYears(in: []).isEmpty)
    }

    @Test("only months containing stored sessions within the selected year are offered")
    func onlyMonthsWithSessionsAreOffered() {
        let dates = [date(year: 2025, month: 2), date(year: 2025, month: 7), date(year: 2024, month: 7)]
        let months = YearJumpDatePicker.availableMonths(in: dates, year: 2025)
        #expect(months == [2, 7])
    }

    @Test("selecting a month loads that month's sessions through the date-range accessor")
    func selectingMonthLoadsThroughDateRangeAccessor() throws {
        let store = try makeStore()
        let inMonth = LiftSession(
            startedAt: date(year: 2025, month: 5, day: 10),
            sets: [makeSet(exercise: "backSquat", completedAt: date(year: 2025, month: 5, day: 10))]
        )
        let outsideMonth = LiftSession(
            startedAt: date(year: 2025, month: 6, day: 1),
            sets: [makeSet(exercise: "benchPress", completedAt: date(year: 2025, month: 6, day: 1))]
        )
        try store.saveLiftSession(inMonth)
        try store.saveLiftSession(outsideMonth)

        let model = StrengthHistoryModel(store: store)
        model.load()

        let range = try #require(YearJumpDatePicker.range(forYear: 2025, month: 5))
        model.loadDateRange(range)

        #expect(model.sessions.map(\.id) == [inMonth.id])
    }

    @Test("clearing the date selection restores the unfiltered most-recent-first list")
    func clearingDateSelectionRestoresFullList() throws {
        let store = try makeStore()
        let earlier = LiftSession(
            startedAt: date(year: 2025, month: 5, day: 10),
            sets: [makeSet(exercise: "backSquat", completedAt: date(year: 2025, month: 5, day: 10))]
        )
        let later = LiftSession(
            startedAt: date(year: 2025, month: 6, day: 1),
            sets: [makeSet(exercise: "benchPress", completedAt: date(year: 2025, month: 6, day: 1))]
        )
        try store.saveLiftSession(earlier)
        try store.saveLiftSession(later)

        let model = StrengthHistoryModel(store: store)
        model.load()
        let range = try #require(YearJumpDatePicker.range(forYear: 2025, month: 5))
        model.loadDateRange(range)
        #expect(model.sessions.count == 1)

        model.loadDateRange(nil)
        #expect(model.sessions.count == 2)
    }

    @Test("a date selection and a pattern filter applied together return their intersection")
    func dateSelectionAndPatternFilterCompose() throws {
        let store = try makeStore()
        let squatInMay = LiftSession(
            startedAt: date(year: 2025, month: 5, day: 10),
            sets: [makeSet(exercise: "backSquat", completedAt: date(year: 2025, month: 5, day: 10))]
        )
        let pullInMay = LiftSession(
            startedAt: date(year: 2025, month: 5, day: 20),
            sets: [makeSet(exercise: "pullUp", completedAt: date(year: 2025, month: 5, day: 20))]
        )
        let squatInJune = LiftSession(
            startedAt: date(year: 2025, month: 6, day: 5),
            sets: [makeSet(exercise: "backSquat", completedAt: date(year: 2025, month: 6, day: 5))]
        )
        try store.saveLiftSession(squatInMay)
        try store.saveLiftSession(pullInMay)
        try store.saveLiftSession(squatInJune)

        let model = StrengthHistoryModel(store: store)
        model.load()
        model.loadDateRange(YearJumpDatePicker.range(forYear: 2025, month: 5))
        model.togglePattern(.squat)

        #expect(model.filteredSessions.map(\.id) == [squatInMay.id])
    }

    @Test("with no stored sessions, the picker offers nothing and the empty-history state applies")
    func noStoredSessionsOffersNothing() throws {
        let store = try makeStore()
        let model = StrengthHistoryModel(store: store)
        model.load()

        #expect(YearJumpDatePicker.availableYears(in: model.allSessionStartDates).isEmpty)
        #expect(model.isEmpty)
    }
}
