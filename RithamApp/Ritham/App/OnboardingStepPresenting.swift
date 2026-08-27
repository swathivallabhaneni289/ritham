import SwiftUI
import RithamCore

// The contract a later plan implements to contribute a screen without ever editing the shared
// root or its own navigation container. Adding a screen means conforming a type to this protocol
// and registering it with `StepRegistry` — never adding a branch to a shared switch statement,
// which would become exactly the kind of merge point (and, worse, potential age-based fork) this
// plan structurally forbids.
//
// `@MainActor` because registration happens at launch (main actor) and resolution happens inside
// SwiftUI's `navigationDestination` (also main actor) — there is no concurrent access to guard
// against, so isolating to the main actor is correct rather than a workaround.
@MainActor
protocol OnboardingStepPresenting {
    /// The single `OnboardingStep` this type presents. Used as the registry key.
    static var step: OnboardingStep { get }

    /// Builds the view for this step, given the shared `OnboardingFlow`.
    static func makeView(flow: OnboardingFlow) -> AnyView
}
