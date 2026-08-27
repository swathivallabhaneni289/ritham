import Testing
import RithamCore
@testable import Ritham

// `.serialized` because `StepRegistry` is shared static state (same reason AppShellTests uses
// it) -- running registration assertions concurrently with other suites touching the registry
// would make them order-dependent. `@MainActor` because `OnboardingFlow`/`StepRegistry` are
// both main-actor isolated.
@Suite("AboutYouStepTests", .serialized)
@MainActor
struct AboutYouStepTests {

    init() {
        StepRegistry.reset()
    }

    private static let sixSteps: [OnboardingStep] = [
        .welcome, .explanationRegister, .age, .ageIneligible, .dietaryPattern, .privacyExplainer,
    ]

    // MARK: - Registration

    @Test("registerAll resolves a real view for each of the six steps and shrinks unregisteredSteps by exactly those six")
    func registerAllResolvesRealViewsAndShrinksUnregisteredSteps() {
        let before = Set(StepRegistry.unregisteredSteps)
        for step in Self.sixSteps {
            #expect(before.contains(step))
        }

        AboutYouRegistration.registerAll()

        let after = Set(StepRegistry.unregisteredSteps)
        for step in Self.sixSteps {
            #expect(!after.contains(step))
        }
        #expect(before.subtracting(after) == Set(Self.sixSteps))

        // Every registered step resolves without trapping -- the same no-trap proof
        // AppShellTests uses for the full step set.
        let flow = OnboardingFlow()
        for step in Self.sixSteps {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - Router walk: welcome -> ... -> privacy explainer

    @Test("walking the router from welcome with a valid adult age, dietary pattern, and privacy acknowledged visits welcome, explanation register, age, dietary pattern, privacy explainer in order")
    func routerWalkVisitsFirstFiveStepsInOrder() {
        var answers = OnboardingAnswers()
        answers.register = .plainLanguage
        answers.age = 30
        answers.dietaryPattern = .none
        answers.privacyExplainerAcknowledged = true

        var visited: [OnboardingStep] = [.welcome]
        var current: OnboardingStep = .welcome
        for _ in 0..<4 {
            guard let next = OnboardingRouter.nextStep(after: current, answers: answers) else { break }
            visited.append(next)
            current = next
        }

        #expect(visited == [.welcome, .explanationRegister, .age, .dietaryPattern, .privacyExplainer])
        // Dietary pattern immediately follows age.
        let ageIndex = visited.firstIndex(of: .age)!
        #expect(visited[ageIndex + 1] == .dietaryPattern)
    }

    // MARK: - Router walk: under-13 reaches .ageIneligible and goes no further

    @Test("walking the router with an under-13 age reaches .ageIneligible and goes no further, with the age answer unchanged")
    func routerWalkUnderThirteenReachesAgeIneligibleAndGoesNoFurther() {
        var answers = OnboardingAnswers()
        answers.age = 8

        let next = OnboardingRouter.nextStep(after: .age, answers: answers)
        #expect(next == .ageIneligible)

        // `.ageIneligible` is a self-loop -- the router's own "hold here" signal -- rather than
        // nil, which is what "goes no further" means for this step.
        let afterIneligible = OnboardingRouter.nextStep(after: .ageIneligible, answers: answers)
        #expect(afterIneligible == .ageIneligible)

        #expect(answers.age == 8)
    }
}
