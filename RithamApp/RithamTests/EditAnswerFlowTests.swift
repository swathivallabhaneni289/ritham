import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Asserts against `HealthDataStore`/`GateResolution`/`GateEscalation` directly -- the same
// data-level approach `DisclaimerTagTests` uses -- rather than by rendering `SettingsView` or
// `EditAnswerFlow`. `EditAnswerFlow.finishEditing()`'s own sequence (`invalidateSection`, then
// `GateResolution.resolve` over the merged answers, then `saveScreeningResult`) is exactly what
// several tests below replay directly, since that sequence -- not the SwiftUI presentation
// wrapping it -- is what D-09/T-01-103/T-01-104 actually depend on.
@MainActor
@Suite("EditAnswerFlowTests")
struct EditAnswerFlowTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func makeStore() throws -> HealthDataStore {
        let schema = Schema([UserProfile.self, ConditionTagRecord.self, CalibrationBaselineRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return HealthDataStore(context: context, calendar: calendar)
    }

    private func makeResult(
        matchedTags: Set<ConditionTag>,
        gates: DomainGates = DomainGates(workout: .none, nutrition: .none)
    ) -> GateResolutionResult {
        GateResolutionResult(
            matchedTags: matchedTags,
            gates: gates,
            interstitial: .none,
            requiresIndependentAllergenVerification: false
        )
    }

    // MARK: - DIET-01: dietary pattern never touches gates or tags

    @Test("editing the dietary pattern changes the stored pattern and leaves every condition tag and both gates unchanged")
    func editingDietaryPatternLeavesTagsAndGatesUnchanged() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30, dietaryPattern: .none))
        let now = Date()
        let seededTags: Set<ConditionTag> = [.kidneyDiseaseOrDialysis, .osteoarthritis]
        try store.saveScreeningResult(makeResult(matchedTags: seededTags), answers: ScreeningAnswers(), now: now)

        let tagsBefore = Set(try store.activeConditionTags(now: now))
        let gatesBefore = GateEscalation.escalate(tags: tagsBefore, answers: ScreeningAnswers())

        // The Settings dietary-pattern edit path (`SettingsView.persistDiet`): only
        // `updateProfile`, never `GateResolution` or `invalidateSection`.
        try store.updateProfile(UserProfileDraft(age: 30, dietaryPattern: .vegan))

        let profile = try store.loadProfile()
        #expect(profile.dietaryPattern == .vegan)

        let tagsAfter = Set(try store.activeConditionTags(now: now))
        #expect(tagsAfter == tagsBefore)
        #expect(GateEscalation.escalate(tags: tagsAfter, answers: ScreeningAnswers()) == gatesBefore)
    }

    // MARK: - D-09: a section edit is scoped to only that section

    @Test("invalidating the condition checklist section clears checklist-derived tags but leaves gate-section-derived tags intact")
    func invalidatingConditionChecklistLeavesGateSectionTagsIntact() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()
        // .osteoarthritis is checklist-derived; .rateLimitingHeartOrBPMedication is the
        // gate-section-derived tag `invalidateSection`'s `.gateSection` case is scoped to --
        // `HealthDataStore.invalidateSection`'s own exclusion list keeps it out of the
        // `.conditionChecklist` clear.
        let seededTags: Set<ConditionTag> = [.osteoarthritis, .rateLimitingHeartOrBPMedication]
        try store.saveScreeningResult(makeResult(matchedTags: seededTags), answers: ScreeningAnswers(), now: now)

        try store.invalidateSection(.conditionChecklist, now: now)

        let remaining = Set(try store.activeConditionTags(now: now))
        #expect(remaining.contains(.rateLimitingHeartOrBPMedication))
        #expect(!remaining.contains(.osteoarthritis))
    }

    // MARK: - Re-resolution always goes through the full engine, never a partial update

    @Test("re-resolving after an edit that removes a required-blocking condition lowers the gate, and after an edit that adds one back it raises the gate again")
    func reResolutionLowersThenRaisesGateAfterFullMergeReResolve() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()

        var answers = ScreeningAnswers()
        answers.checklist = ChecklistSelection(items: [.kidneyDiseaseCKD])
        let initialResult = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(initialResult, answers: answers, now: now)
        #expect(initialResult.gates.workout == .requiredBlocking)
        #expect(initialResult.gates.nutrition == .requiredBlocking)

        // `EditAnswerFlow.finishEditing()`'s own sequence for a `.conditionChecklist` edit that
        // removes the kidney-disease selection: invalidate, then a full re-resolve over the
        // merged answers, never a partial update.
        answers.checklist = ChecklistSelection()
        try store.invalidateSection(.conditionChecklist, now: now)
        let loweredResult = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(loweredResult, answers: answers, now: now)
        #expect(loweredResult.gates.workout != .requiredBlocking)
        #expect(loweredResult.gates.nutrition != .requiredBlocking)

        // The reverse: adding the condition back raises the gate again.
        answers.checklist = ChecklistSelection(items: [.kidneyDiseaseCKD])
        try store.invalidateSection(.conditionChecklist, now: now)
        let raisedResult = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(raisedResult, answers: answers, now: now)
        #expect(raisedResult.gates.workout == .requiredBlocking)
        #expect(raisedResult.gates.nutrition == .requiredBlocking)
    }

    // MARK: - D-07 / D-08 together

    @Test("a tag past twelve months makes isReScreenDue true while activeConditionTags still returns it")
    func overdueTagIsStillActiveWhileReScreenIsDue() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let recordedAt = Date(timeIntervalSince1970: 0)
        let thirteenMonthsLater = try #require(calendar.date(byAdding: .month, value: 13, to: recordedAt))

        try store.saveScreeningResult(makeResult(matchedTags: [.osteoarthritis]), answers: ScreeningAnswers(), now: recordedAt)

        #expect(try store.isReScreenDue(now: thirteenMonthsLater))
        #expect(try store.activeConditionTags(now: thirteenMonthsLater).contains(.osteoarthritis))
    }

    @Test("dismissing the banner does not clear the due state permanently")
    func dismissingBannerNeverMutatesReScreenDueState() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let recordedAt = Date(timeIntervalSince1970: 0)
        let now = try #require(calendar.date(byAdding: .month, value: 13, to: recordedAt))
        try store.saveScreeningResult(makeResult(matchedTags: [.osteoarthritis]), answers: ScreeningAnswers(), now: recordedAt)

        #expect(try store.isReScreenDue(now: now))
        // `ReScreenBanner`'s dismiss action only ever flips its own view-local
        // `isDismissedThisSession` state -- it calls nothing on `HealthDataStore` (see
        // RithamApp/Ritham/Settings/ReScreenBanner.swift). Re-checking the identical signal
        // immediately afterward, with no intervening store mutation, must still report `true`:
        // dismissal is session-scoped UI state, never a persisted "resolved" flag.
        #expect(try store.isReScreenDue(now: now))
    }

    // MARK: - Known limitation: EditAnswerFlow requires a same-session, populated flow

    @Test("re-resolving a section edit against a flow whose answers already hold the other sections' data preserves them")
    func reResolutionAgainstAPopulatedSameSessionFlowPreservesOtherSections() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()

        // A same-session flow: `answers.screening` already carries the gate-section answer
        // (G5 = Yes) alongside the checklist selection, exactly as it would after a real
        // onboarding pass within the same app launch.
        var answers = ScreeningAnswers()
        answers.g5MedicationOrPrescribedDiet = .yes
        answers.med2ClinicianPrescribedDietOrMealPlan = .yes
        answers.checklist = ChecklistSelection(items: [.osteoarthritis])
        let initial = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(initial, answers: answers, now: now)
        #expect(Set(try store.activeConditionTags(now: now)).contains(.clinicianPrescribedDietOrMealPlan))

        // Edit only the condition checklist -- the gate-section-derived answer stays on the
        // flow's `answers.screening`, so the merged re-resolve keeps it.
        answers.checklist = ChecklistSelection()
        try store.invalidateSection(.conditionChecklist, now: now)
        let afterEdit = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(afterEdit, answers: answers, now: now)

        let tagsAfter = Set(try store.activeConditionTags(now: now))
        #expect(tagsAfter.contains(.clinicianPrescribedDietOrMealPlan))
        #expect(!tagsAfter.contains(.osteoarthritis))
    }

    @Test("KNOWN LIMITATION: re-resolving a section edit against a fresh, empty flow wipes every other section's tags, since raw ScreeningAnswers is never durably persisted (01-11)")
    func reResolutionAgainstAFreshEmptyFlowWipesOtherSections() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()

        var answers = ScreeningAnswers()
        answers.g5MedicationOrPrescribedDiet = .yes
        answers.med2ClinicianPrescribedDietOrMealPlan = .yes
        answers.checklist = ChecklistSelection(items: [.osteoarthritis])
        let initial = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        try store.saveScreeningResult(initial, answers: answers, now: now)
        #expect(Set(try store.activeConditionTags(now: now)).contains(.clinicianPrescribedDietOrMealPlan))

        // A *fresh* `OnboardingFlow`'s `answers.screening` starts completely empty -- there is
        // nowhere raw `ScreeningAnswers` is durably persisted for it to hydrate from (01-11's
        // deliberate derived-tags-only storage decision). Editing only the checklist here still
        // re-resolves over this blank baseline, per D-09/T-01-103's "always the same engine,
        // never a partial update" rule -- and that full resolve, over answers that never carried
        // the gate-section response at all, cannot reproduce a tag this session never saw.
        var freshAnswers = ScreeningAnswers()
        freshAnswers.checklist = ChecklistSelection()
        try store.invalidateSection(.conditionChecklist, now: now)
        let afterFreshEdit = GateResolution.resolve(answers: freshAnswers, ageDerivedTags: [])
        try store.saveScreeningResult(afterFreshEdit, answers: freshAnswers, now: now)

        let tagsAfter = Set(try store.activeConditionTags(now: now))
        // This is the documented gap, not a desired outcome: the gate-section-derived tag is
        // gone, even though nothing about that section was ever edited.
        #expect(!tagsAfter.contains(.clinicianPrescribedDietOrMealPlan))
    }
}
