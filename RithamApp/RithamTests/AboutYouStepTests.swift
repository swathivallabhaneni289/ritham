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

    private static let fiveSteps: [OnboardingStep] = [
        .welcome, .age, .ageIneligible, .dietaryPattern, .privacyExplainer,
    ]

    // MARK: - Registration

    @Test("registerAll resolves a real view for each of the five steps and shrinks unregisteredSteps by exactly those five")
    func registerAllResolvesRealViewsAndShrinksUnregisteredSteps() {
        let before = Set(StepRegistry.unregisteredSteps)
        for step in Self.fiveSteps {
            #expect(before.contains(step))
        }

        AboutYouRegistration.registerAll()

        let after = Set(StepRegistry.unregisteredSteps)
        for step in Self.fiveSteps {
            #expect(!after.contains(step))
        }
        #expect(before.subtracting(after) == Set(Self.fiveSteps))

        // Every registered step resolves without trapping -- the same no-trap proof
        // AppShellTests uses for the full step set.
        let flow = OnboardingFlow()
        for step in Self.fiveSteps {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - Router walk: welcome -> ... -> privacy explainer

    @Test("walking the router from welcome with a valid adult age, dietary pattern, and privacy acknowledged visits welcome, age, dietary pattern, privacy explainer in order")
    func routerWalkVisitsFirstFourStepsInOrder() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.dietaryPattern = .none
        answers.privacyExplainerAcknowledged = true

        var visited: [OnboardingStep] = [.welcome]
        var current: OnboardingStep = .welcome
        for _ in 0..<3 {
            guard let next = OnboardingRouter.nextStep(after: current, answers: answers) else { break }
            visited.append(next)
            current = next
        }

        #expect(visited == [.welcome, .age, .dietaryPattern, .privacyExplainer])
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
