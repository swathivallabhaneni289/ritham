import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Phase 2 Plan 12's guidance-surface test suites, at the model/data level per the plan's own
// explicit instruction (the same "assert at the data level" discipline `DisclaimerTagTests`/
// `CardioViewTests` already use, not by rendering any view). `GuidanceContextTests` (Task 1) is
// followed by `InlineGuidanceTests` (Task 2) and `NutritionGuidanceTests` (Task 3) as this same
// file grows across the plan's tasks.
@MainActor
@Suite("GuidanceContextTests")
struct GuidanceContextTests {

    private func makeContainerContext() throws -> ModelContext {
        let container = try RithamModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// Creates a profile, resolves and saves `tags` as the full screening result, then builds a
    /// `GuidanceContext` reading from that same store -- the same store-driven reconstruction
    /// `GuidanceContext` itself performs against a real app store, never a mocked-out context.
    private func makeScreenedContext(tags: Set<ConditionTag>) throws -> GuidanceContext {
        let modelContext = try makeContainerContext()
        let store = HealthDataStore(context: modelContext)
        try store.updateProfile(UserProfileDraft(age: 30))
        let result = GateResolutionResult(
            matchedTags: tags,
            gates: GateEscalation.escalate(tags: tags, answers: ScreeningAnswers()),
            interstitial: .none,
            requiresIndependentAllergenVerification: GateEscalation.requiresIndependentAllergenVerification(tags: tags)
        )
        try store.saveScreeningResult(result, answers: ScreeningAnswers(), now: Date())
        return GuidanceContext(context: modelContext)
    }

    @Test("with no stored profile, the context reports unscreened and the resolved workout permission is the zero-content value")
    func noStoredProfileIsUnscreenedWithZeroContentPermission() throws {
        let modelContext = try makeContainerContext()

        let context = GuidanceContext(context: modelContext)

        #expect(context.isScreened == false)
        #expect(context.matchedTags.isEmpty)
        #expect(context.permission(for: .workout) == .none)
        #expect(context.permission(for: .nutrition) == .none)
        #expect(context.governingTag(for: .workout) == nil)
    }

    @Test("a screened user with a full-permission workout tag resolves to full content with that tag governing")
    func fullPermissionTagResolvesToFullContent() throws {
        let context = try makeScreenedContext(tags: [.noneOfTheAboveBaseline])

        #expect(context.isScreened)
        #expect(context.permission(for: .workout) == .full)
        #expect(context.governingTag(for: .workout) == .noneOfTheAboveBaseline)
    }

    @Test("a screened user with a zero-content workout tag resolves to the zero-content permission")
    func zeroContentTagResolvesToNonePermission() throws {
        let context = try makeScreenedContext(tags: [.kidneyDiseaseOrDialysis])

        #expect(context.permission(for: .workout) == .none)
        #expect(context.governingTag(for: .workout) == .kidneyDiseaseOrDialysis)
    }

    @Test("two tags of differing restrictiveness resolve to the more restrictive one as governing (HEALTH-06)")
    func twoTagsResolveToMoreRestrictiveGoverning() throws {
        let context = try makeScreenedContext(tags: [.noneOfTheAboveBaseline, .heartDiseaseRecentEventOrSymptomatic])

        #expect(context.permission(for: .workout) == .none)
        #expect(context.governingTag(for: .workout) == .heartDiseaseRecentEventOrSymptomatic)
    }

    @Test("the reconstructed result names every matched condition, not only the governing one (D-12)")
    func resultNamesEveryMatchedCondition() throws {
        let context = try makeScreenedContext(tags: [.osteoarthritis, .kidneyDiseaseOrDialysis])

        let names = context.result.disclaimerConditionNames
        #expect(names.contains(ConditionTag.osteoarthritis.displayName))
        #expect(names.contains(ConditionTag.kidneyDiseaseOrDialysis.displayName))
    }

    @Test("an education-only nutrition tag resolves to educationOnly, neither full nor zero-content")
    func educationOnlyNutritionTagResolvesCorrectly() throws {
        let context = try makeScreenedContext(tags: [.hypertensionManaged])

        #expect(context.permission(for: .nutrition) == .educationOnly)
    }
}

// Task 2: inline guidance at logging time in both session screens.
@MainActor
@Suite("InlineGuidanceTests")
struct InlineGuidanceTests {

    private func makeContainerContext() throws -> ModelContext {
        let container = try RithamModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func saveScreening(_ tags: Set<ConditionTag>, store: HealthDataStore) throws {
        try store.updateProfile(UserProfileDraft(age: 40))
        try store.saveScreeningResult(
            GateResolutionResult(
                matchedTags: tags,
                gates: GateEscalation.escalate(tags: tags, answers: ScreeningAnswers()),
                interstitial: .none,
                requiresIndependentAllergenVerification: GateEscalation.requiresIndependentAllergenVerification(tags: tags)
            ),
            answers: ScreeningAnswers(),
            now: Date()
        )
    }

    @Test("a cardio session can be finished and saved while the workout permission is the zero-content value, increasing the stored count by exactly one")
    func cardioSessionSavesUnderZeroContentWorkoutPermission() throws {
        let modelContext = try makeContainerContext()
        let store = HealthDataStore(context: modelContext)
        try saveScreening([.kidneyDiseaseOrDialysis], store: store)

        let guidanceContext = GuidanceContext(context: modelContext)
        #expect(guidanceContext.permission(for: .workout) == .none)

        let countBefore = try store.loadCardioSessions().count
        let sessionModel = CardioSessionModel(activityType: .run, gpsSession: nil)
        sessionModel.start()
        let session = sessionModel.finish()
        try store.saveCardioSession(session)

        let countAfter = try store.loadCardioSessions().count
        #expect(countAfter == countBefore + 1)
    }

    @Test("a strength session can be finished and saved while the workout permission is the zero-content value, increasing the stored count by exactly one")
    func strengthSessionSavesUnderZeroContentWorkoutPermission() throws {
        let modelContext = try makeContainerContext()
        let store = HealthDataStore(context: modelContext)
        try saveScreening([.otherSeriousConditionOrActiveCancerTreatment], store: store)

        let guidanceContext = GuidanceContext(context: modelContext)
        #expect(guidanceContext.permission(for: .workout) == .none)

        let countBefore = try store.loadLiftSessions().count
        let sessionModel = StrengthSessionModel(store: store)
        sessionModel.addSet(exerciseIdentifier: "backSquat", weightKg: 60, reps: 5, isWarmUp: false)
        try sessionModel.finish()

        let countAfter = try store.loadLiftSessions().count
        #expect(countAfter == countBefore + 1)
    }

    @Test("a tag flagged as never-triggers-streak-loss reads true even though its own workout permission is zero-content")
    func neverTriggersStreakLossReadsTrueUnderZeroContentPermission() throws {
        let tag = ConditionTag.heartDiseaseRecentEventOrSymptomatic

        #expect(WorkoutGuidanceCatalog.neverTriggersStreakLoss(tag))
        #expect(GuidanceCatalog.contentPermission(for: tag, domain: .workout) == .none)
    }

    @Test("both session screens resolve to their real registered steps, not a placeholder")
    func sessionScreensResolveToRealSteps() {
        #expect(CardioSessionView.step == .cardioSession)
        #expect(StrengthSessionView.step == .strengthSession)
    }
}
