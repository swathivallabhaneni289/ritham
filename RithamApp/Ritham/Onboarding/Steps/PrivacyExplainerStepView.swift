import SwiftUI
import RithamCore

// CROSSGEN-03: privacy is explained on one screen, in plain language, before anything is
// requested. This screen presents information and an acknowledgement only -- it contains no
// toggle, no permission prompt, no opt-in control, and no request of any kind. The promise
// "nothing is shared or synced with anyone by default" is kept by this phase requesting and
// syncing nothing at all; a later phase that adds a sharing control must place it after this
// explanation, never on it.
struct PrivacyExplainerStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .privacyExplainer

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(PrivacyExplainerStepView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.boundedHeaderOnly, headline: OnboardingCopy.Privacy.headline) {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                Text(OnboardingCopy.Privacy.bulletNothingShared)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                Text(OnboardingCopy.Privacy.bulletAnswersPrivate)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                // CROSSGEN-04's spectrum framing, not a binary public-or-private choice -- no
                // control is added here that would imply one exists yet.
                Text(OnboardingCopy.Privacy.bulletYouChoose)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: OnboardingCopy.Privacy.cta) {
                flow.answers.privacyExplainerAcknowledged = true
                flow.advance(from: .privacyExplainer)
            }
        }
    }
}
