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

@MainActor
@Suite("SessionRevisionScreenTests")
struct SessionRevisionScreenTests {

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

    private func date(day: Int = 1) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
    }

    private func totalSetCount(in store: HealthDataStore) throws -> Int {
        try store.loadLiftSessions().reduce(0) { $0 + $1.sets.count }
    }

    @Test("editing a set's fields mutates values on the existing set, preserving its id")
    func editingSetPreservesIdentity() throws {
        let store = try makeStore()
        let originalSetID = UUID()
        let session = LiftSession(
            startedAt: date(),
            sets: [LiftSet(id: originalSetID, exerciseIdentifier: "backSquat", weightKg: 60, reps: 5, orderIndex: 0, completedAt: date())]
        )
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.updateSet(at: 0, weightKg: 70, reps: 8, isWarmUp: true)

        #expect(model.session.sets[0].id == originalSetID)
        #expect(model.session.sets[0].weightKg == 70)
        #expect(model.session.sets[0].reps == 8)
        #expect(model.session.sets[0].isWarmUp == true)
    }

    @Test("saving an edit persists the changed values")
    func savingEditPersistsChangedValues() throws {
        let store = try makeStore()
        let session = LiftSession(
            startedAt: date(),
            sets: [LiftSet(exerciseIdentifier: "benchPress", weightKg: 40, reps: 5, orderIndex: 0, completedAt: date())]
        )
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.updateSet(at: 0, weightKg: 45, reps: 6, isWarmUp: false)
        try model.save()

        let reloaded = try #require(try store.loadLiftSession(id: session.id))
        #expect(reloaded.sets[0].weightKg == 45)
        #expect(reloaded.sets[0].reps == 6)
        #expect(reloaded.sets[0].id == session.sets[0].id)
    }

    @Test("merging two sessions produces one session containing every set from both, each once")
    func mergingProducesUnionOfSets() throws {
        let store = try makeStore()
        let first = LiftSession(startedAt: date(day: 1), sets: [makeSet(exercise: "backSquat", completedAt: date(day: 1))])
        let second = LiftSession(startedAt: date(day: 2), sets: [makeSet(exercise: "benchPress", completedAt: date(day: 2))])
        try store.saveLiftSession(first)
        try store.saveLiftSession(second)

        let model = SessionEditModel(session: first, store: store)
        model.requestMerge(with: second)
        try model.confirmRevision()

        let remaining = try store.loadLiftSessions()
        #expect(remaining.count == 1)
        let mergedSetIDs = Set(remaining[0].sets.map(\.id))
        #expect(mergedSetIDs == Set(first.sets.map(\.id) + second.sets.map(\.id)))
    }

    @Test("splitting a session partitions its sets exactly across the two results")
    func splittingPartitionsSetsExactly() throws {
        let store = try makeStore()
        let sets = (0..<4).map { i in makeSet(exercise: "backSquat", orderIndex: i, completedAt: date(day: i + 1)) }
        let session = LiftSession(startedAt: date(day: 1), sets: sets)
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.requestSplit(atSetIndex: 2)
        try model.confirmRevision()

        let remaining = try store.loadLiftSessions()
        #expect(remaining.count == 2)
        let allIDs = Set(remaining.flatMap { $0.sets.map(\.id) })
        #expect(allIDs == Set(sets.map(\.id)))
        #expect(remaining.reduce(0) { $0 + $1.sets.count } == sets.count)
    }

    @Test("splitting at the first set is refused and writes nothing")
    func splittingAtFirstSetIsRefused() throws {
        let store = try makeStore()
        let sets = (0..<3).map { i in makeSet(exercise: "backSquat", orderIndex: i, completedAt: date(day: i + 1)) }
        let session = LiftSession(startedAt: date(day: 1), sets: sets)
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.requestSplit(atSetIndex: 0)

        #expect(model.pendingRevision == nil)
        #expect(model.refusalMessage != nil)

        let remaining = try store.loadLiftSessions()
        #expect(remaining.count == 1)
        #expect(remaining[0].sets.count == 3)
    }

    @Test("splitting past the last set is refused")
    func splittingPastLastSetIsRefused() throws {
        let store = try makeStore()
        let sets = (0..<3).map { i in makeSet(exercise: "backSquat", orderIndex: i, completedAt: date(day: i + 1)) }
        let session = LiftSession(startedAt: date(day: 1), sets: sets)
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.requestSplit(atSetIndex: sets.count)

        #expect(model.pendingRevision == nil)
        #expect(model.refusalMessage != nil)
    }

    @Test("merging a session with itself is refused")
    func mergingSessionWithItselfIsRefused() throws {
        let store = try makeStore()
        let session = LiftSession(startedAt: date(), sets: [makeSet(exercise: "backSquat", completedAt: date())])
        try store.saveLiftSession(session)

        let model = SessionEditModel(session: session, store: store)
        model.requestMerge(with: session)

        #expect(model.pendingRevision == nil)
        #expect(model.refusalMessage != nil)
    }

    @Test("abandoning the merge confirmation leaves the stored session count unchanged")
    func abandoningMergeConfirmationWritesNothing() throws {
        let store = try makeStore()
        let first = LiftSession(startedAt: date(day: 1), sets: [makeSet(exercise: "backSquat", completedAt: date(day: 1))])
        let second = LiftSession(startedAt: date(day: 2), sets: [makeSet(exercise: "benchPress", completedAt: date(day: 2))])
        try store.saveLiftSession(first)
        try store.saveLiftSession(second)

        let model = SessionEditModel(session: first, store: store)
        model.requestMerge(with: second)
        #expect(model.pendingRevision != nil)

        model.abandonRevision()
        #expect(model.pendingRevision == nil)

        let remaining = try store.loadLiftSessions()
        #expect(remaining.count == 2)
    }

    @Test("the total stored set count is unchanged before and after a merge, and before and after a split")
    func totalSetCountUnchangedAcrossRevisions() throws {
        let store = try makeStore()
        let first = LiftSession(startedAt: date(day: 1), sets: [makeSet(exercise: "backSquat", completedAt: date(day: 1))])
        let second = LiftSession(startedAt: date(day: 2), sets: [makeSet(exercise: "benchPress", completedAt: date(day: 2))])
        try store.saveLiftSession(first)
        try store.saveLiftSession(second)

        let beforeMerge = try totalSetCount(in: store)
        let mergeModel = SessionEditModel(session: first, store: store)
        mergeModel.requestMerge(with: second)
        try mergeModel.confirmRevision()
        #expect(try totalSetCount(in: store) == beforeMerge)

        let merged = try #require(try store.loadLiftSessions().first)
        let beforeSplit = try totalSetCount(in: store)
        let splitModel = SessionEditModel(session: merged, store: store)
        splitModel.requestSplit(atSetIndex: 1)
        try splitModel.confirmRevision()
        #expect(try totalSetCount(in: store) == beforeSplit)
    }
}
