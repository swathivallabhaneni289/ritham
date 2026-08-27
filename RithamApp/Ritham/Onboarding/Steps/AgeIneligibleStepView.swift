import SwiftUI
import RithamCore

// MINOR-01's under-13 block screen. This is not a dead end -- it is a single-step-back loop:
// the only way off this screen is back to `.age`, where entering a qualifying value routes
// forward normally through the router. This view has no forward `flow.advance` call of its own
// and selects no destination itself -- `goBack()` is a pure path-pop, not a second branching
// authority alongside OnboardingRouter.nextStep. Nothing about a rejected attempt persists once
// the user leaves this screen: `AgeStepView` never wrote the rejected value to the profile
// store in the first place, so there is nothing here to clear either.
struct AgeIneligibleStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .ageIneligible

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(AgeIneligibleStepView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            // Matches the flat-charcoal-plus-off-white-card treatment 01-UI-SPEC.md's
            // Decorative Surface Inventory gives this row (the same one the Required-blocking
            // message row uses) -- a plain blocking message, never the decorative header
            // surfaces reserved for welcome/register/privacy/calibration.
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                Text(OnboardingCopy.AgeGate.headline)
                    .font(RithamType.display)
                    .foregroundStyle(RithamColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(OnboardingCopy.AgeGate.body)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(RithamSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RithamColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))

            SecondaryCTAButton(title: OnboardingCopy.AgeGate.cta) {
                flow.goBack()
            }
        }
    }
}
