import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

@MainActor
@Suite("HealthDataStoreTests")
struct HealthDataStoreTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func makeStore() throws -> HealthDataStore {
        let schema = Schema([
            UserProfile.self, ConditionTagRecord.self, CalibrationBaselineRecord.self, FoodAllergenRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return HealthDataStore(context: context, calendar: calendar)
    }

    private func makeGateResolutionResult(matchedTags: Set<ConditionTag>) -> GateResolutionResult {
        GateResolutionResult(
            matchedTags: matchedTags,
            gates: DomainGates(workout: .none, nutrition: .none),
            interstitial: .none,
            requiresIndependentAllergenVerification: false
        )
    }

    // MARK: - Profile creation / update

    @Test("creating the first-ever profile via updateProfile with age 13 succeeds")
    func firstEverProfileCreationSucceeds() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 13))
        let profile = try store.loadProfile()
        #expect(profile.age == 13)
    }

    @Test("updateProfile with an incoming age under 13 against an existing 13+ profile throws ageBelowFloor and leaves the stored profile completely unchanged")
    func updateProfileRejectsAgeBelowFloorWithNoPartialWrite() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30, dietaryPattern: .vegetarian))

        #expect(throws: HealthDataStoreError.ageBelowFloor) {
            try store.updateProfile(UserProfileDraft(age: 12, dietaryPattern: .vegan))
        }

        let profile = try store.loadProfile()
        #expect(profile.age == 30)
        #expect(profile.dietaryPattern == .vegetarian)
    }

    @Test("updateProfile leaves dietaryPattern unchanged when the draft omits it")
    func updateProfilePreservesUnspecifiedFields() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 20, dietaryPattern: .vegan))
        // Only age changes here; dietary pattern is omitted (nil).
        try store.updateProfile(UserProfileDraft(age: 21))

        let profile = try store.loadProfile()
        #expect(profile.age == 21)
        #expect(profile.dietaryPattern == .vegan)
    }

    @Test("every screening accessor succeeds against a stored profile regardless of the profile's age")
    func accessorsSucceedForAnyStoredProfileAge() throws {
        for age in [13, 17, 40, 70] {
            let store = try makeStore()
            try store.updateProfile(UserProfileDraft(age: age))
            let now = Date()

            let result = makeGateResolutionResult(matchedTags: [.osteoarthritis])
            try store.saveScreeningResult(result, answers: ScreeningAnswers(), now: now)

            #expect(try store.activeConditionTags(now: now).contains(.osteoarthritis))
            #expect(try store.isReScreenDue(now: now) == false)
            try store.invalidateSection(.dietaryPattern, now: now)
            #expect(try store.clearancesNeedingReConfirmation(now: now).isEmpty)
            #expect(try store.loadCalibrationBaseline() != nil)
        }
    }

    // MARK: - profileMissing

    @Test("calling a screening accessor with no stored profile throws profileMissing")
    func screeningAccessorThrowsProfileMissingWithNoStoredProfile() throws {
        let store = try makeStore()
        let now = Date()

        #expect(throws: HealthDataStoreError.profileMissing) {
            _ = try store.loadProfile()
        }
        #expect(throws: HealthDataStoreError.profileMissing) {
            try store.saveScreeningResult(makeGateResolutionResult(matchedTags: []), answers: ScreeningAnswers(), now: now)
        }
        #expect(throws: HealthDataStoreError.profileMissing) {
            _ = try store.activeConditionTags(now: now)
        }
        #expect(throws: HealthDataStoreError.profileMissing) {
            _ = try store.isReScreenDue(now: now)
        }
        #expect(throws: HealthDataStoreError.profileMissing) {
            try store.invalidateSection(.conditionChecklist, now: now)
        }
    }

    // MARK: - D-08: overdue tags still returned

    @Test("a stored tag past twelve months is still returned by activeConditionTags and reported by isReScreenDue")
    func overdueTagStillReturnedAndReScreenDue() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))

        let thirteenMonthsAgo = calendar.date(byAdding: .month, value: -13, to: Date())!
        try store.saveScreeningResult(
            makeGateResolutionResult(matchedTags: [.hypertensionManaged]),
            answers: ScreeningAnswers(),
            now: thirteenMonthsAgo
        )

        let now = Date()
        #expect(try store.activeConditionTags(now: now).contains(.hypertensionManaged))
        #expect(try store.isReScreenDue(now: now) == true)
    }

    // MARK: - invalidateSection

    @Test("invalidateSection for the condition checklist leaves the dietary pattern untouched")
    func invalidateConditionChecklistLeavesDietaryPatternUntouched() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 25, dietaryPattern: .vegan))
        let now = Date()
        try store.saveScreeningResult(
            makeGateResolutionResult(matchedTags: [.osteoarthritis, .rateLimitingHeartOrBPMedication]),
            answers: ScreeningAnswers(),
            now: now
        )

        try store.invalidateSection(.conditionChecklist, now: now)

        let profile = try store.loadProfile()
        #expect(profile.dietaryPattern == .vegan)
        // The checklist-derived tag is cleared, but the gate-section-derived tag is untouched.
        #expect(try store.activeConditionTags(now: now).contains(.osteoarthritis) == false)
        #expect(try store.activeConditionTags(now: now).contains(.rateLimitingHeartOrBPMedication))
    }

    @Test("invalidateSection deletes rather than extends an overdue tag's window")
    func invalidateSectionDeletesOverdueTagRatherThanExtendingItsWindow() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 25))
        let thirteenMonthsAgo = calendar.date(byAdding: .month, value: -13, to: Date())!
        try store.saveScreeningResult(
            makeGateResolutionResult(matchedTags: [.osteoarthritis]),
            answers: ScreeningAnswers(),
            now: thirteenMonthsAgo
        )

        try store.invalidateSection(.conditionChecklist, now: Date())

        // The record is gone, not silently refreshed to "active for another 12 months" —
        // an edit shortens the window, it never extends it (§1.6).
        #expect(try store.activeConditionTags(now: Date()).contains(.osteoarthritis) == false)
    }

    @Test("invalidateSection for scoff clears the eating-disorder outcome and its tag")
    func invalidateScoffClearsOutcomeAndTag() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 25))
        let now = Date()
        try store.saveScreeningResult(
            makeGateResolutionResult(matchedTags: [.eatingDisorderPositiveScreen]),
            answers: ScreeningAnswers(),
            now: now
        )
        #expect(try store.loadProfile().edScreenOutcome == .eatingDisorderPositiveScreen)

        try store.invalidateSection(.scoff, now: now)

        #expect(try store.loadProfile().edScreenOutcome == nil)
        #expect(try store.activeConditionTags(now: now).contains(.eatingDisorderPositiveScreen) == false)
    }

    // MARK: - Calibration baseline

    @Test("loadCalibrationBaseline with nothing stored returns a provisional baseline rather than nil")
    func loadCalibrationBaselineReturnsProvisionalWhenNothingStored() throws {
        let store = try makeStore()
        let baseline = try store.loadCalibrationBaseline()
        #expect(baseline?.source == .provisional)
    }

    @Test("saveCalibrationBaseline then loadCalibrationBaseline round-trips a measured baseline")
    func saveThenLoadCalibrationBaselineRoundTrips() throws {
        let store = try makeStore()
        let measured = CalibrationBaseline(
            paceZone: PaceZone(600, 500),
            safeStartingWeightKg: 20,
            source: .measured,
            establishedAt: Date()
        )
        try store.saveCalibrationBaseline(measured)

        let loaded = try store.loadCalibrationBaseline()
        #expect(loaded?.source == .measured)
        #expect(loaded?.safeStartingWeightKg == 20)
    }

    // MARK: - Food allergens

    @Test("loadFoodAllergens with nothing stored returns an empty set")
    func loadFoodAllergensReturnsEmptyWhenNothingStored() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        #expect(try store.loadFoodAllergens().isEmpty)
    }

    @Test("saveFoodAllergens then loadFoodAllergens round-trips the full set")
    func saveThenLoadFoodAllergensRoundTrips() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        try store.saveFoodAllergens([.peanuts, .shellfish])

        #expect(try store.loadFoodAllergens() == [.peanuts, .shellfish])
    }

    @Test("saveFoodAllergens replaces the previously stored set rather than adding to it")
    func saveFoodAllergensReplacesPreviousSet() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        try store.saveFoodAllergens([.peanuts, .shellfish])
        try store.saveFoodAllergens([.milk])

        #expect(try store.loadFoodAllergens() == [.milk])
    }

    @Test("saveFoodAllergens never writes a ConditionTagRecord (DIET-01-style isolation)")
    func saveFoodAllergensNeverWritesAConditionTag() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        try store.saveFoodAllergens([.peanuts])

        #expect(try store.activeConditionTags(now: Date()).isEmpty)
    }

    // MARK: - Professional clearance

    @Test("recordProfessionalClearance then clearancesNeedingReConfirmation reflects an overdue grant")
    func professionalClearanceNeedsReConfirmationWhenOverdue() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()
        try store.saveScreeningResult(
            makeGateResolutionResult(matchedTags: [.hypertensionUncontrolledOrUnsure]),
            answers: ScreeningAnswers(),
            now: now
        )

        let thirteenMonthsAgo = calendar.date(byAdding: .month, value: -13, to: now)!
        try store.recordProfessionalClearance(for: .hypertensionUncontrolledOrUnsure, at: thirteenMonthsAgo)

        let needsReConfirmation = try store.clearancesNeedingReConfirmation(now: now)
        #expect(needsReConfirmation.contains(.hypertensionUncontrolledOrUnsure))
    }
}
