import SwiftUI
import RithamCore

// App-side wrapper around the flow's in-progress answers and navigation path (01-RESEARCH.md's
// Pattern 1). `advance` and `goBack` are the ONLY ways the path changes.
//
// This class must contain no branching logic of its own. Adding an `if` on age, tier, or consent
// state to this class is a defect: it would place a routing decision outside the one function
// (`OnboardingRouter.nextStep`) that plan 01-07's tests exhaustively cover, which is exactly the
// kind of second branching authority CROSSGEN-05 forbids. Every next-step decision delegates
// wholly to the core router.
//
// `@MainActor` because SwiftUI reads `path` and `answers` from the main actor via `@Observable`
// and the single shared navigation container's path binding, and every call site (button actions
// inside step views) already runs on the main actor.
@MainActor
@Observable
final class OnboardingFlow {
    var answers: OnboardingAnswers
    var path: [OnboardingStep]

    init(answers: OnboardingAnswers = OnboardingAnswers(), path: [OnboardingStep] = []) {
        self.answers = answers
        self.path = path
    }

    /// Advances past `step` by delegating entirely to `OnboardingRouter.nextStep`. Appends the
    /// router's answer to `path` — nothing more.
    ///
    /// Two cases intentionally do NOT append, and neither is an age/tier/consent branch: a `nil`
    /// result (nothing follows `.home`) and a result equal to `step` itself. The latter is a pure
    /// step-identity comparison, not a condition on the answers — it exists because
    /// `OnboardingRouter.nextStep(after: .ageIneligible, answers:)` returns `.ageIneligible`
    /// again (the router's own "hold here" signal for a step that isn't going anywhere), and
    /// appending that on every call would grow the path unboundedly if the same "continue" action
    /// were tapped repeatedly.
    func advance(from step: OnboardingStep) {
        guard let next = OnboardingRouter.nextStep(after: step, answers: answers), next != step else {
            return
        }
        path.append(next)
    }

    /// Pops the most recent step. A no-op on an empty path.
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

// Later plans contribute a screen by conforming a type to `OnboardingStepPresenting` and calling
// `StepRegistry.register(_:)` — never by editing this switch-like lookup or adding a branch
// anywhere else. `view(for:flow:)` returns a clearly labelled placeholder for any step not yet
// registered so the app compiles and runs before every screen plan has landed; that fallback is
// not a stand-in for a real screen, and `unregisteredSteps` is asserted empty by the phase's final
// verification plan (01-18).
@MainActor
enum StepRegistry {
    private static var factories: [OnboardingStep: (OnboardingFlow) -> AnyView] = [:]

    /// Registers `type` under its own `step`, overwriting any prior registration for that step.
    static func register<Presenter: OnboardingStepPresenting>(_ type: Presenter.Type) {
        factories[type.step] = { flow in type.makeView(flow: flow) }
    }

    /// Resolves the view for `step`. Never traps: an unregistered step gets a labelled
    /// placeholder instead of crashing the app mid-onboarding.
    static func view(for step: OnboardingStep, flow: OnboardingFlow) -> AnyView {
        if let factory = factories[step] {
            return factory(flow)
        }
        return AnyView(UnimplementedStepView(step: step))
    }

    /// Steps with no registered presenter. Every step will be registered by the end of the
    /// phase; 01-18's `PhaseCoverageTests` asserts this is empty.
    static var unregisteredSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter { factories[$0] == nil }
    }

    /// Test-only: clears every registration so tests can run deterministically regardless of
    /// execution order. Never called from app code.
    static func reset() {
        factories = [:]
    }
}

private struct UnimplementedStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 8) {
            Text("Screen not yet implemented")
                .font(.headline)
            Text(step.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
