import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Task 3: workout preference accessors, gate-isolated. Weekly frequency, pre-assessment
// completion, route-comparison opt-in and the on-device experience bucket, none of which any
// gate resolution, tag derivation or screening logic ever reads (T-02-25).
@MainActor
@Suite("WorkoutPreferenceTests")
struct WorkoutPreferenceTests {

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

    @Test("loading the weekly frequency with no stored record returns a stated default rather than nil or zero")
    func loadWeeklyFrequencyReturnsStatedDefaultWhenNothingStored() throws {
        let store = try makeStore()
        #expect(try store.loadWeeklyFrequency() == 3)
    }

    @Test("saving a frequency of 3, 5 or 7 persists and reloads that value")
    func savingSupportedFrequenciesRoundTrips() throws {
        let store = try makeStore()
        for frequency in [3, 5, 7] {
            try store.saveWeeklyFrequency(frequency)
            #expect(try store.loadWeeklyFrequency() == frequency)
        }
    }

    @Test("saving a frequency of 4 throws and leaves the stored frequency unchanged")
    func savingUnsupportedFrequencyThrowsAndLeavesStoredValueUnchanged() throws {
        let store = try makeStore()
        try store.saveWeeklyFrequency(5)

        #expect(throws: HealthDataStoreError.unsupportedWeeklyFrequency) {
            try store.saveWeeklyFrequency(4)
        }

        #expect(try store.loadWeeklyFrequency() == 5)
    }

    @Test("loading the pre-assessment completion flag defaults to false, and marking it complete persists true")
    func preAssessmentCompletionDefaultsFalseThenPersistsTrue() throws {
        let store = try makeStore()
        #expect(try store.loadHasCompletedPreAssessment() == false)

        try store.markPreAssessmentCompleted()

        #expect(try store.loadHasCompletedPreAssessment() == true)
    }

    @Test("loading the onboarding completion flag defaults to false, and marking it complete persists true")
    func onboardingCompletionDefaultsFalseThenPersistsTrue() throws {
        let store = try makeStore()
        #expect(try store.loadHasCompletedOnboarding() == false)

        try store.markOnboardingCompleted()

        #expect(try store.loadHasCompletedOnboarding() == true)
    }

    @Test("the onboarding completion flag survives a fresh HealthDataStore instance over the same container, not just the in-memory one that set it")
    func onboardingCompletionSurvivesReloadOverTheSameContainer() throws {
        let container = try RithamModelContainer.make(inMemory: true)
        let writingStore = HealthDataStore(context: ModelContext(container))
        try writingStore.markOnboardingCompleted()

        let readingStore = HealthDataStore(context: ModelContext(container))
        #expect(try readingStore.loadHasCompletedOnboarding() == true)
    }

    @Test("the route-comparison opt-in defaults to false with no stored record")
    func routeComparisonOptInDefaultsFalse() throws {
        let store = try makeStore()
        #expect(try store.loadRouteComparisonOptIn() == false)

        try store.saveRouteComparisonOptIn(true)
        #expect(try store.loadRouteComparisonOptIn() == true)
    }

    @Test("deriving the experience bucket from a measured baseline returns a bucket")
    func experienceLevelFromMeasuredBaselineReturnsABucket() throws {
        let store = try makeStore()
        try store.saveCalibrationBaseline(CalibrationBaseline(
            paceZone: PaceZone(600, 500),
            safeStartingWeightKg: 20,
            source: .measured,
            establishedAt: Date()
        ))

        // Phase 2 does not specify a graduated pace/weight-threshold mapping across all four
        // buckets for a real measurement (see `experienceLevel()`'s own doc comment) -- the
        // behavior this test actually pins down is that a measured baseline is credited above
        // the no-assessment default, not collapsed into the same `.beginner` bucket a skipped
        // calibration returns.
        let level = try store.experienceLevel()
        #expect(level != .beginner)
    }

    @Test("deriving the experience bucket from a provisional baseline returns the least experienced bucket")
    func experienceLevelFromProvisionalBaselineReturnsLeastExperienced() throws {
        let store = try makeStore()
        // No calibration baseline saved -- `loadCalibrationBaseline` materializes a provisional
        // one, per its own "never a blank state" discipline.
        #expect(try store.experienceLevel() == .beginner)
    }

    @Test("writing any workout preference performs no screening write and leaves stored condition tags untouched")
    func preferenceWritesLeaveConditionTagsUntouched() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()
        let seededTags: Set<ConditionTag> = [.osteoarthritis, .kidneyDiseaseOrDialysis]
        try store.saveScreeningResult(makeGateResolutionResult(matchedTags: seededTags), answers: ScreeningAnswers(), now: now)

        let tagsBefore = Set(try store.activeConditionTags(now: now))

        try store.saveWeeklyFrequency(7)
        try store.markPreAssessmentCompleted()
        try store.saveRouteComparisonOptIn(true)

        let tagsAfter = Set(try store.activeConditionTags(now: now))
        #expect(tagsAfter == tagsBefore)
    }
}
