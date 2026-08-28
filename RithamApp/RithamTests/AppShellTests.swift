import SwiftUI
import Testing
import RithamCore
@testable import Ritham

/// A minimal conforming presenter used only to test `StepRegistry.register`'s effect on
/// `unregisteredSteps`. Registered to `.welcome` — an arbitrary but fixed choice.
private struct DummyWelcomePresenter: OnboardingStepPresenting {
    static var step: OnboardingStep { .welcome }
    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(Text("dummy welcome"))
    }
}

// `.serialized` because every test in this suite reads/writes `StepRegistry`'s shared static
// state; running them concurrently (Swift Testing's default) would make registration tests
// order-dependent. `@MainActor` because `OnboardingFlow` and `StepRegistry` are both main-actor
// isolated.
@Suite("AppShellTests", .serialized)
@MainActor
struct AppShellTests {

    init() {
        StepRegistry.reset()
    }

    // MARK: - StepRegistry never traps

    @Test("StepRegistry.view resolves every OnboardingStep without trapping")
    func viewResolvesEveryStepWithoutTrapping() {
        let flow = OnboardingFlow()
        for step in OnboardingStep.allCases {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        // Reaching this line means no unregistered step crashed the app.
        #expect(true)
    }

    // MARK: - Registration shrinks unregisteredSteps by exactly one step

    @Test("registering a conforming type shrinks unregisteredSteps by exactly that step")
    func registeringShrinksUnregisteredStepsByExactlyOneStep() {
        let before = Set(StepRegistry.unregisteredSteps)
        #expect(before.contains(.welcome))

        StepRegistry.register(DummyWelcomePresenter.self)

        let after = Set(StepRegistry.unregisteredSteps)
        #expect(!after.contains(.welcome))
        #expect(before.subtracting(after) == [.welcome])
        #expect(before.count - after.count == 1)
    }

    // MARK: - OnboardingFlow.advance delegates wholly to OnboardingRouter.nextStep

    @Test("advance appends exactly what OnboardingRouter.nextStep returns")
    func advanceAppendsExactlyWhatRouterReturns() {
        let flow = OnboardingFlow(answers: OnboardingAnswers())
        let expected = OnboardingRouter.nextStep(after: .welcome, answers: flow.answers)

        flow.advance(from: .welcome)

        #expect(flow.path == [expected].compactMap { $0 })
    }

    @Test("advance appends the router's answer for an age-eligible user past the age fork")
    func advanceAppendsForEligibleAge() {
        var answers = OnboardingAnswers()
        answers.age = 15
        let flow = OnboardingFlow(answers: answers)
        let expected = OnboardingRouter.nextStep(after: .age, answers: answers)

        flow.advance(from: .age)

        #expect(flow.path == [expected].compactMap { $0 })
    }

    @Test("advance does not grow the path when the router holds at the same step (under-13)")
    func advanceDoesNotGrowPathWhenRouterHoldsAtSameStep() {
        var answers = OnboardingAnswers()
        answers.age = 8
        let flow = OnboardingFlow(answers: answers)

        // The router itself returns `.ageIneligible` again for `.ageIneligible` when the age is
        // still under 13 — confirm that premise, then confirm `advance` does not append it.
        #expect(OnboardingRouter.nextStep(after: .ageIneligible, answers: answers) == .ageIneligible)

        flow.advance(from: .ageIneligible)
        #expect(flow.path.isEmpty)

        // Repeated taps of the same "continue" action must not grow the path unboundedly.
        flow.advance(from: .ageIneligible)
        flow.advance(from: .ageIneligible)
        #expect(flow.path.isEmpty)
    }

    @Test("advance is a no-op after .home, where nextStep returns nil")
    func advanceIsNoOpAfterHome() {
        let flow = OnboardingFlow(answers: OnboardingAnswers())
        #expect(OnboardingRouter.nextStep(after: .home, answers: flow.answers) == nil)

        flow.advance(from: .home)
        #expect(flow.path.isEmpty)
    }

    // MARK: - goBack

    @Test("goBack removes the last path element")
    func goBackRemovesLastPathElement() {
        let flow = OnboardingFlow(answers: OnboardingAnswers())
        flow.path = [.welcome, .age]

        flow.goBack()

        #expect(flow.path == [.welcome])
    }

    @Test("goBack is a no-op on an empty path")
    func goBackIsNoOpOnEmptyPath() {
        let flow = OnboardingFlow(answers: OnboardingAnswers())
        #expect(flow.path.isEmpty)

        flow.goBack()

        #expect(flow.path.isEmpty)
    }
}
