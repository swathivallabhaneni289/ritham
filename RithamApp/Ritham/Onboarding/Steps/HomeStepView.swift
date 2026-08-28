import SwiftUI
import RithamCore

/// `.home` -- the onboarding flow's terminal step (`OnboardingRouter.nextStep(after: .home)`
/// returns `nil`; nothing follows it).
///
/// This is deliberately NOT the product's real home screen. Phase 1 is onboarding and safety
/// intake only -- PROJECT.md's "3-item default home screen with progressive disclosure" is
/// Phase 4's CROSSGEN/HOUSEHOLD work, which does not exist yet. Rendering something that
/// looked like the finished home screen here would misrepresent what this phase actually
/// built; this view instead states plainly that onboarding is complete and says nothing about
/// what a later phase will add, so it never claims to be a screen it isn't. It carries no CTA:
/// `OnboardingFlow.advance(from: .home)` is already a no-op (`OnboardingRouter.nextStep`
/// returns `nil` here, per `AppShellTests.advanceIsNoOpAfterHome`), so a "Continue" button
/// with nowhere to route to would be a dead control.
///
/// Registered by `OnboardingCompletionRegistration` alongside `.screeningComplete` -- see that
/// file's header comment for why this plan owns both.
struct HomeStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .home

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(HomeStepView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: OnboardingCopy.Home.headline,
            bodyText: OnboardingCopy.Home.body
        ) {
            EmptyView()
        }
    }
}
