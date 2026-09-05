import SwiftUI
import RithamCore

/// `.home` -- the onboarding flow's terminal step (`OnboardingRouter.nextStep(after: .home)`
/// returns `nil`; nothing follows it).
///
/// D-05's deliberately interim hub, not CROSSGEN-01's polished three-item home -- that remains
/// Phase 4's scope. This view exists so Phase 2's own features (cardio, strength, guidance,
/// recommendations, and -- via Settings -- the diet plan screen) are reachable and testable in
/// the running app now, rather than staying unreachable outside debug routing until Phase 4.
/// Phase 4 is expected to replace `HomeHubView` outright rather than extend it.
///
/// Registered by `OnboardingCompletionRegistration` alongside `.screeningComplete` -- see that
/// file's header comment for why that plan owns both. `HomeHubView` itself carries the
/// navigation contract (see its own header comment); this type is only the `StepRegistry`
/// factory binding `.home` to it.
struct HomeStepView: OnboardingStepPresenting {
    static let step: OnboardingStep = .home

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(HomeHubView(flow: flow))
    }
}
