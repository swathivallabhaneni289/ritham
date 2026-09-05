import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// MONETIZE-01: the visible always-free capability list. Asserted directly against the declared
// `AlwaysFreeCapability.all` collection -- the same source `AlwaysFreeListView` renders -- rather
// than by rendering the view itself, the same data-level approach `EditAnswerFlowTests` uses for
// `SettingsView`/`DietPlanView`.
@Suite("AlwaysFreeListTests")
struct AlwaysFreeListTests {

    @Test("the declared capability collection has at least 7 entries")
    func capabilityCollectionHasAtLeastSevenEntries() throws {
        #expect(AlwaysFreeCapability.all.count >= 7)
    }

    @Test("the capability collection names every capability this build actually ships free")
    func capabilityCollectionNamesExpectedCapabilities() throws {
        let combined = AlwaysFreeCapability.all.map { "\($0.title) \($0.detail)".lowercased() }

        func namesCapability(containing fragment: String) -> Bool {
            combined.contains { $0.contains(fragment) }
        }

        #expect(namesCapability(containing: "stopwatch"))
        #expect(namesCapability(containing: "gps"))
        #expect(namesCapability(containing: "history"))
        #expect(namesCapability(containing: "plate"))
        #expect(namesCapability(containing: "one-rep-max") || namesCapability(containing: "1rm"))
        #expect(namesCapability(containing: "superset"))
        #expect(namesCapability(containing: "movement-pattern") || namesCapability(containing: "movement pattern"))
    }

    @Test("no capability entry names heart-rate display, the one capability this build lacks")
    func capabilityCollectionNamesNoHeartRateDisplay() throws {
        let namesHeartRate = AlwaysFreeCapability.all.contains {
            $0.title.localizedCaseInsensitiveContains("heart rate")
                || $0.detail.localizedCaseInsensitiveContains("heart rate")
                || $0.title.localizedCaseInsensitiveContains("heart-rate")
                || $0.detail.localizedCaseInsensitiveContains("heart-rate")
        }
        #expect(!namesHeartRate)
    }

    @Test("no capability entry exposes a purchase, subscribe, or upgrade action -- descriptive text only")
    func capabilityEntriesExposeNoPurchaseAction() throws {
        for capability in AlwaysFreeCapability.all {
            let mirror = Mirror(reflecting: capability)
            for child in mirror.children {
                #expect(!(child.value is () -> Void))
            }

            let text = "\(capability.title) \(capability.detail)".lowercased()
            #expect(!text.contains("purchase"))
            #expect(!text.contains("subscribe"))
            #expect(!text.contains("upgrade"))
        }
    }

    @Test("the forgiveness statement documents that shields/comeback repair/injury guardrail are never monetized, and arrive with Momentum")
    func forgivenessStatementDocumentsMomentumTiming() throws {
        let statement = AlwaysFreeCapability.forgivenessStatement.lowercased()
        #expect(statement.contains("momentum"))
        #expect(statement.contains("never monetized"))
    }
}

// The weekly workout-frequency preference (`WorkoutFrequencyView`). Asserted against
// `HealthDataStore` directly, in-memory, the same data-level approach `EditAnswerFlowTests`/
// `WorkoutPreferenceTests` use rather than rendering the view -- `WorkoutFrequencyView`'s own
// `persist`/`currentWeeklyFrequency` both defer entirely to the store accessors these tests
// exercise directly.
@MainActor
@Suite("WorkoutFrequencyTests")
struct WorkoutFrequencyTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeGateResolutionResult(matchedTags: Set<ConditionTag>) -> GateResolutionResult {
        GateResolutionResult(
            matchedTags: matchedTags,
            gates: DomainGates(workout: .none, nutrition: .none),
            interstitial: .none,
            requiresIndependentAllergenVerification: false
        )
    }

    @Test("WeeklyFrequencyOption.all matches HealthDataStore.supportedWeeklyFrequencies exactly, ascending")
    func weeklyFrequencyOptionsMatchSupportedFrequencies() throws {
        let expected = HealthDataStore.supportedWeeklyFrequencies.sorted()
        #expect(WeeklyFrequencyOption.all.map(\.daysPerWeek) == expected)
    }

    @Test("opening with no stored preference selects the stated default")
    func openingWithNoStoredValueSelectsStatedDefault() throws {
        let store = try makeStore()
        // `SettingsView.currentWeeklyFrequency()` -- the value `WorkoutFrequencyView` is
        // initialized with -- is exactly `HealthDataStore.loadWeeklyFrequency()`'s own result.
        let loaded = try store.loadWeeklyFrequency()
        #expect(loaded == 3)
        #expect(WeeklyFrequencyOption(daysPerWeek: loaded) == WeeklyFrequencyOption(daysPerWeek: 3))
    }

    @Test("selecting a value persists it and reloads as selected on reopen")
    func selectingAValuePersistsAndReloadsAsSelectedOnReopen() throws {
        let store = try makeStore()
        try store.saveWeeklyFrequency(5)
        #expect(try store.loadWeeklyFrequency() == 5)
    }

    @Test("changing the value later persists the new value, with no confirmation step involved")
    func changingTheValueLaterPersistsTheNewValue() throws {
        let store = try makeStore()
        try store.saveWeeklyFrequency(5)
        #expect(try store.loadWeeklyFrequency() == 5)

        try store.saveWeeklyFrequency(7)
        #expect(try store.loadWeeklyFrequency() == 7)
    }

    @Test("a frequency write leaves stored condition tags and the stored dietary pattern byte-identical")
    func frequencyWriteLeavesConditionTagsAndDietaryPatternUnchanged() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30, dietaryPattern: .vegan))
        let now = Date()
        let seededTags: Set<ConditionTag> = [.osteoarthritis, .kidneyDiseaseOrDialysis]
        try store.saveScreeningResult(makeGateResolutionResult(matchedTags: seededTags), answers: ScreeningAnswers(), now: now)

        let tagsBefore = Set(try store.activeConditionTags(now: now))
        let dietaryPatternBefore = try store.loadProfile().dietaryPattern

        try store.saveWeeklyFrequency(7)

        let tagsAfter = Set(try store.activeConditionTags(now: now))
        let dietaryPatternAfter = try store.loadProfile().dietaryPattern
        #expect(tagsAfter == tagsBefore)
        #expect(dietaryPatternAfter == dietaryPatternBefore)
    }
}
