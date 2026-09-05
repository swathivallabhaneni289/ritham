import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Phase 2 Plan 11's strength-logging-UI test suites, at the model/data level per the plan's own
// explicit instruction (not by rendering) -- the same discipline `CardioViewTests` already uses.
// `StrengthSetEntryTests` (Task 1) is followed by `PlateCalculatorScreenTests` (Task 2) and
// `SupersetBuilderTests` (Task 3) as this same file grows across the plan's tasks.
@MainActor
@Suite("StrengthSetEntryTests")
struct StrengthSetEntryTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeLiftSet(
        exerciseIdentifier: String,
        weightKg: Double?,
        reps: Int,
        isWarmUp: Bool = false
    ) -> LiftSet {
        LiftSet(
            exerciseIdentifier: exerciseIdentifier,
            weightKg: weightKg,
            reps: reps,
            isWarmUp: isWarmUp,
            orderIndex: 0,
            completedAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("registers as the strength-session step")
    func registersAsStrengthSessionStep() {
        #expect(StrengthSessionView.step == .strengthSession)
    }

    @Test("the picker lists the seeded exercise catalog")
    func pickerListsSeededCatalog() {
        #expect(ExerciseCatalog.all.map(\.identifier).contains("backSquat"))
        #expect(ExerciseCatalog.all.isEmpty == false)
    }

    @Test("searching the picker by display name narrows the list to matching exercises")
    func searchingNarrowsToMatchingExercises() {
        let results = ExercisePickerFilter.matching("Bench").map(\.displayName)

        #expect(results.contains("Bench Press"))
        #expect(results.contains("Deadlift") == false)
    }

    @Test("an empty search query returns the full seeded catalog")
    func emptySearchReturnsFullCatalog() {
        #expect(ExercisePickerFilter.matching("").count == ExerciseCatalog.all.count)
    }

    @Test("selecting an exercise adds it to the in-progress session's exercise order")
    func selectingExerciseAddsIt() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)

        model.addExercise("backSquat")

        #expect(model.exerciseOrder == ["backSquat"])
    }

    @Test("selecting an already-added exercise does not duplicate its section")
    func selectingAlreadyAddedExerciseIsANoOp() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)

        model.addExercise("backSquat")
        model.addExercise("backSquat")

        #expect(model.exerciseOrder == ["backSquat"])
    }

    @Test("adding a set for a never-logged exercise leaves the pre-fill weight and reps empty")
    func neverLoggedExercisePrefillsNothing() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)

        let draft = model.autoFillDraft(forExercise: "backSquat")

        #expect(draft == nil)
    }

    @Test("adding a set for a previously logged exercise pre-fills from the most recent working set")
    func loggedExercisePrefillsFromMostRecentWorkingSet() throws {
        let store = try makeStore()
        let previous = LiftSession(
            startedAt: Date(timeIntervalSince1970: 0),
            sets: [makeLiftSet(exerciseIdentifier: "backSquat", weightKg: 100, reps: 5)]
        )
        try store.saveLiftSession(previous)
        let model = StrengthSessionModel(store: store)

        let draft = model.autoFillDraft(forExercise: "backSquat")

        #expect(draft?.weightKg == 100)
        #expect(draft?.reps == 5)
    }

    @Test("a warm-up set is not returned as the auto-fill source for a later set of the same exercise")
    func warmUpSetExcludedFromAutoFill() throws {
        let store = try makeStore()
        let warmUpOnly = LiftSession(
            startedAt: Date(timeIntervalSince1970: 0),
            sets: [makeLiftSet(exerciseIdentifier: "backSquat", weightKg: 40, reps: 10, isWarmUp: true)]
        )
        try store.saveLiftSession(warmUpOnly)
        let model = StrengthSessionModel(store: store)

        let draft = model.autoFillDraft(forExercise: "backSquat")

        #expect(draft == nil)
    }

    @Test("each exercise's movement patterns come from the catalog, without user assignment")
    func exercisePatternsComeFromCatalog() {
        #expect(ExerciseCatalog.patterns(for: "thruster") == [.squat, .push])
        #expect(ExerciseCatalog.patterns(for: "backSquat") == [.squat])
    }

    @Test("adding a set stores the edited value, not the pre-fill")
    func editedValueOverridesPrefill() throws {
        let store = try makeStore()
        let previous = LiftSession(
            startedAt: Date(timeIntervalSince1970: 0),
            sets: [makeLiftSet(exerciseIdentifier: "backSquat", weightKg: 100, reps: 5)]
        )
        try store.saveLiftSession(previous)
        let model = StrengthSessionModel(store: store)
        // The screen would use this pre-fill to seed the entry field before the user edits it.
        _ = model.autoFillDraft(forExercise: "backSquat")

        let added = model.addSet(exerciseIdentifier: "backSquat", weightKg: 110, reps: 6, isWarmUp: false)

        #expect(added.weightKg == 110)
        #expect(added.reps == 6)
        #expect(model.sets(for: "backSquat").map(\.id) == [added.id])
    }
}
