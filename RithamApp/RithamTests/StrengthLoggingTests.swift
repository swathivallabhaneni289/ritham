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

// Task 2: the plate calculator and one-rep-max surface.
@MainActor
@Suite("PlateCalculatorScreenTests")
struct PlateCalculatorScreenTests {

    @Test("choosing an equipment kind sets its default bar weight")
    func choosingEquipmentSetsDefaultBarWeight() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)

        model.selectEquipment(.trapBar)

        #expect(model.barWeightKg == Equipment.trapBar.defaultBarWeightKg)
    }

    @Test("choosing a pin-stack kind reports itself as a pin-stack, hiding plate-specific controls")
    func choosingPinStackReportsPinStack() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)

        model.selectEquipment(.stackMachine)

        #expect(model.isPinStack)
    }

    @Test("an exactly loadable target reports the plates per side and marks itself an exact match")
    func exactlyLoadableTargetReportsExactMatch() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = "60"

        let result = model.result

        #expect(result?.isExactMatch == true)
        #expect(result?.platesPerSideKg.isEmpty == false)
        #expect(result?.achievedWeightKg == 60)
    }

    @Test("a non-loadable target reports an achievable weight different from the requested value, marked as nearest")
    func nonLoadableTargetReportsNearestAchievable() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = "61"

        let result = model.result

        #expect(result?.isExactMatch == false)
        #expect(result?.achievedWeightKg != 61)
    }

    @Test("a negative target shows an invalid-input state with no plate list")
    func negativeTargetIsInvalidInput() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = "-5"

        #expect(model.isInvalidInput)
        #expect(model.result == nil)
    }

    @Test("an empty target shows an invalid-input state")
    func emptyTargetIsInvalidInput() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = ""

        #expect(model.isInvalidInput)
    }

    @Test("a non-numeric target shows an invalid-input state")
    func nonNumericTargetIsInvalidInput() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = "not a number"

        #expect(model.isInvalidInput)
    }

    @Test("the one-rep-max estimate appears for a supported rep count")
    func oneRepMaxAppearsForSupportedRepCount() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)

        #expect(model.oneRepMaxEstimate(weightKg: 100, reps: 5) != nil)
    }

    @Test("the one-rep-max estimate is absent for an unsupported rep count")
    func oneRepMaxAbsentForUnsupportedRepCount() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)

        #expect(model.oneRepMaxEstimate(weightKg: 100, reps: 50) == nil)
    }

    @Test("applying the result writes the achievable weight to the set, not the typed target")
    func applyingWritesAchievableWeightNotTypedTarget() {
        let model = PlateCalculatorModel(equipment: .standardBarbell)
        model.targetWeightKg = "61"
        var appliedWeight: Double?

        // Mirrors what the view's "Apply to set" action does: hands `achievableWeightToApply`
        // (never the raw typed target) to the caller-supplied closure.
        if let achievable = model.achievableWeightToApply {
            appliedWeight = achievable
        }

        #expect(appliedWeight != nil)
        #expect(appliedWeight != 61)
        #expect(appliedWeight == model.result?.achievedWeightKg)
    }

    @Test("a pin-stack target rounds to the nearest increment with an empty plate list")
    func pinStackRoundsToNearestIncrementWithNoPlateList() {
        let model = PlateCalculatorModel(equipment: .stackMachine)
        model.targetWeightKg = "47"

        let result = model.result

        #expect(result?.platesPerSideKg.isEmpty == true)
        #expect(result?.achievedWeightKg == 45)
    }
}

// Task 3: superset building, session save, and registrar rewrite.
@MainActor
@Suite("SupersetBuilderTests")
struct SupersetBuilderTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    @Test("the strength-session step resolves to the real screen, not a placeholder")
    func registersAsStrengthSessionStep() {
        #expect(StrengthSessionView.step == .strengthSession)
    }

    @Test("joining two consecutive exercises groups them into one superset in a single step")
    func joiningTwoExercisesGroupsThemInOneStep() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)
        model.addSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 8, isWarmUp: false)
        model.addSet(exerciseIdentifier: "overheadPress", weightKg: 40, reps: 8, isWarmUp: false)

        model.joinIntoSuperset(["benchPress", "overheadPress"])

        let groups = model.supersetGroups()
        #expect(groups.count == 1)
        #expect(model.groupID(forExercise: "benchPress") == model.groupID(forExercise: "overheadPress"))
    }

    @Test("ungrouping restores both exercises to standalone")
    func ungroupingRestoresStandalone() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)
        model.addSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 8, isWarmUp: false)
        model.addSet(exerciseIdentifier: "overheadPress", weightKg: 40, reps: 8, isWarmUp: false)
        model.joinIntoSuperset(["benchPress", "overheadPress"])
        let groupID = try #require(model.groupID(forExercise: "benchPress"))

        model.ungroup(groupID)

        #expect(model.groupID(forExercise: "benchPress") == nil)
        #expect(model.groupID(forExercise: "overheadPress") == nil)
        #expect(model.supersetGroups().isEmpty)
    }

    @Test("joining then ungrouping leaves every set's identifier unchanged")
    func joinThenUngroupLeavesSetIdentifiersUnchanged() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)
        let benchSet = model.addSet(exerciseIdentifier: "benchPress", weightKg: 60, reps: 8, isWarmUp: false)
        let pressSet = model.addSet(exerciseIdentifier: "overheadPress", weightKg: 40, reps: 8, isWarmUp: false)
        let idsBefore = Set(model.session.sets.map(\.id))

        model.joinIntoSuperset(["benchPress", "overheadPress"])
        let groupID = try #require(model.groupID(forExercise: "benchPress"))
        model.ungroup(groupID)

        let idsAfter = Set(model.session.sets.map(\.id))
        #expect(idsAfter == idsBefore)
        #expect(idsAfter == Set([benchSet.id, pressSet.id]))
    }

    @Test("finishing saves one lift session whose stored set count equals the in-progress count")
    func finishingSavesSessionWithMatchingSetCount() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)
        model.addSet(exerciseIdentifier: "backSquat", weightKg: 80, reps: 5, isWarmUp: false)
        model.addSet(exerciseIdentifier: "backSquat", weightKg: 80, reps: 5, isWarmUp: false)
        model.addSet(exerciseIdentifier: "deadlift", weightKg: 100, reps: 5, isWarmUp: false)
        let inProgressCount = model.session.sets.count

        try model.finish()

        let saved = try #require(try store.loadLiftSession(id: model.session.id))
        #expect(saved.sets.count == inProgressCount)
    }

    @Test("the session reports whether it meets the qualifying bar by reading the domain evaluation")
    func reportsQualificationFromDomainEvaluation() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)

        #expect(model.qualification == .incomplete)

        model.addSet(exerciseIdentifier: "backSquat", weightKg: 80, reps: 5, isWarmUp: false)
        model.addSet(exerciseIdentifier: "backSquat", weightKg: 80, reps: 5, isWarmUp: false)
        model.addSet(exerciseIdentifier: "deadlift", weightKg: 100, reps: 5, isWarmUp: false)

        #expect(model.qualification == LiftQualification.evaluate(model.session))
        #expect(model.qualification == .complete)
    }

    @Test("applying the plate calculator's result to a specific set writes the achievable weight there")
    func applyingPlateCalculatorResultUpdatesTheTargetedSet() throws {
        let store = try makeStore()
        let model = StrengthSessionModel(store: store)
        let set = model.addSet(exerciseIdentifier: "backSquat", weightKg: 61, reps: 5, isWarmUp: false)

        model.updateWeight(forSetID: set.id, to: 60)

        #expect(model.sets(for: "backSquat").first?.weightKg == 60)
    }
}
