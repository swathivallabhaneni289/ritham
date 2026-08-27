import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Asserts at the routing and data level, per this plan's own instruction, rather than by
// rendering any screen. `.serialized` + `StepRegistry.reset()` in `init()` matches
// `AboutYouStepTests`'s pattern -- `StepRegistry` is shared static state, and running
// registration assertions concurrently with other suites touching it would make them
// order-dependent. `@MainActor` because `OnboardingFlow`/`StepRegistry`/`HealthDataStore` are all
// main-actor isolated.
@Suite("ScreeningFlowTests", .serialized)
@MainActor
struct ScreeningFlowTests {

    init() {
        StepRegistry.reset()
    }

    private static let sevenSteps: [OnboardingStep] = [
        .screeningOpeningDisclaimer, .gateSection, .clearanceInterstitial, .conditionChecklist,
        .severityFollowUps, .scoffFollowUp, .universalFollowUp,
    ]

    private func makeStore() throws -> HealthDataStore {
        let schema = Schema([UserProfile.self, ConditionTagRecord.self, CalibrationBaselineRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return HealthDataStore(context: context)
    }

    // MARK: - Registration

    @Test("registerAll resolves a real view for each of the seven screening steps and shrinks unregisteredSteps by exactly those seven")
    func registerAllResolvesRealViewsAndShrinksUnregisteredSteps() {
        let before = Set(StepRegistry.unregisteredSteps)
        for step in Self.sevenSteps {
            #expect(before.contains(step))
        }

        ScreeningRegistration.registerAll()

        let after = Set(StepRegistry.unregisteredSteps)
        for step in Self.sevenSteps {
            #expect(!after.contains(step))
        }
        #expect(before.subtracting(after) == Set(Self.sevenSteps))

        // Every registered step resolves without trapping -- the same no-trap proof
        // AboutYouStepTests uses for its own step set, proving each resolves through a real
        // registered factory rather than StepRegistry's unimplemented-step fallback.
        let flow = OnboardingFlow()
        for step in Self.sevenSteps {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - Gate branching

    @Test("all seven gate answers 'no' reaches the condition checklist without an interstitial")
    func allGateAnswersNoReachesConditionChecklistWithoutInterstitial() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.g1HeartConditionOrHighBP = .no
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no
        answers.screening.g4OtherOngoingCondition = .no
        answers.screening.g5MedicationOrPrescribedDiet = .no
        answers.screening.g6BoneJointSoftTissueProblem = .no
        answers.screening.g7MedicallySupervisedOnly = .no

        #expect(OnboardingRouter.nextStep(after: .gateSection, answers: answers) == .conditionChecklist)

        let result = GateResolution.resolve(answers: answers.screening, ageDerivedTags: answers.ageDerivedTags)
        #expect(result.interstitial == .none)
    }

    @Test("G1 = yes passes through the routine interstitial and still reaches the checklist")
    func g1YesPassesThroughRoutineInterstitialAndReachesChecklist() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.g1HeartConditionOrHighBP = .yes
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no

        #expect(OnboardingRouter.nextStep(after: .gateSection, answers: answers) == .clearanceInterstitial)

        let result = GateResolution.resolve(answers: answers.screening, ageDerivedTags: answers.ageDerivedTags)
        #expect(result.interstitial == .routine)

        // §1.2: the user proceeds to the checklist after either interstitial variant.
        #expect(OnboardingRouter.nextStep(after: .clearanceInterstitial, answers: answers) == .conditionChecklist)
    }

    @Test("G2 = yes resolves the urgent interstitial variant")
    func g2YesResolvesUrgentVariant() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.g2ChestPainOrBreathlessness = .yes

        let result = GateResolution.resolve(answers: answers.screening, ageDerivedTags: answers.ageDerivedTags)
        #expect(result.interstitial == .urgent)
    }

    // MARK: - SCOFF reachability (D-10)

    @Test("selecting the eating-disorder-history item makes the eating-pattern step reachable")
    func eatingDisorderSelectionMakesScoffReachable() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.checklist.toggle(.eatingDisorderHistory)

        #expect(OnboardingRouter.isReachable(.scoffFollowUp, answers: answers))
    }

    @Test("not selecting the eating-disorder-history item makes the eating-pattern step unreachable")
    func noEatingDisorderSelectionMakesScoffUnreachable() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.checklist.toggle(.noneOfTheAbove)

        #expect(!OnboardingRouter.isReachable(.scoffFollowUp, answers: answers))
    }

    @Test("selecting only the exclusive 'None of the above' option still reaches the universal follow-up")
    func noneOfTheAboveOnlyStillReachesUniversalFollowUp() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.checklist.toggle(.noneOfTheAbove)

        #expect(OnboardingRouter.isReachable(.universalFollowUp, answers: answers))
    }

    // MARK: - Persistence

    @Test("after completing the flow, HealthDataStore.activeConditionTags returns the tags GateResolution.resolve produced")
    func activeConditionTagsMatchesResolvedResult() throws {
        let store = try makeStore()
        try store.updateProfile(UserProfileDraft(age: 30))

        var screening = ScreeningAnswers()
        screening.checklist.toggle(.noneOfTheAbove)
        screening.g1HeartConditionOrHighBP = .no
        screening.g2ChestPainOrBreathlessness = .no
        screening.g3DizzinessOrLossOfConsciousness = .no
        screening.g4OtherOngoingCondition = .no
        screening.g5MedicationOrPrescribedDiet = .no
        screening.g6BoneJointSoftTissueProblem = .no
        screening.g7MedicallySupervisedOnly = .no

        let result = GateResolution.resolve(answers: screening, ageDerivedTags: [])
        try store.saveScreeningResult(result, answers: screening, now: Date())

        let activeTags = Set(try store.activeConditionTags(now: Date()))
        #expect(activeTags == result.matchedTags)
        #expect(!activeTags.isEmpty)
    }
}
