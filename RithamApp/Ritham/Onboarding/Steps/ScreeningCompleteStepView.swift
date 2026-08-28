import SwiftUI
import RithamCore

/// `.screeningComplete` -- reached immediately after `UniversalFollowUpView` saves the
/// resolved screening result, and immediately before the flow's terminal `.home` step
/// (`OnboardingRouter.nextStep(after: .screeningComplete) == .home`).
///
/// Neither 01-16 nor 01-17 registered this step -- `deferred-items.md`'s "From 01-17" entry
/// flagged it as a gap that would trip this plan's own `PhaseCoverageTests.unregisteredSteps`
/// acceptance gate. It is registered here, alongside `.home`, by
/// `OnboardingCompletionRegistration` (Rule 2/3 deviation: this plan's own acceptance gate
/// cannot pass without a real screen for every `OnboardingStep` case).
///
/// Kept as a brief acknowledgement, not a data-display screen: it names no condition tag,
/// gate, or score -- that surface belongs to `HealthProfileView` (plan 01-17), reachable
/// later from Settings.
struct ScreeningCompleteStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .screeningComplete

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(ScreeningCompleteStepView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: OnboardingCopy.ScreeningComplete.headline,
            bodyText: OnboardingCopy.ScreeningComplete.body
        ) {
            PrimaryCTAButton(title: OnboardingCopy.ScreeningComplete.cta) {
                flow.advance(from: .screeningComplete)
            }
        }
    }
}
