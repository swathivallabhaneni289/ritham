import SwiftUI
import RithamCore

// Per D-04, the derived pace zone and safe starting weight exist only to set safe initial
// targets and must never be displayed as a score, a grade, a fitness level, a percentile, a
// rating, or a comparison to anyone. This screen renders only the locked copy and an
// acknowledgement of completion -- no numeric summary, no badge, no tier, no congratulation of
// performance. `CalibrationBaseline` (plan 01-05) deliberately exposes no score-like member and
// no string conversion; a future change must not add a display property to that model in order
// to render one here.
struct CalibrationCompleteView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .calibrationComplete

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CalibrationCompleteView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.calibration,
            headline: OnboardingCopy.Calibration.completeHeadline,
            bodyText: OnboardingCopy.Calibration.completeBody
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                HStack(spacing: RithamSpacing.xs) {
                    Text("Your comfortable")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                    GlossaryTerm(term: "Pace zone")
                    Text("is set.")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                }

                HStack(spacing: RithamSpacing.xs) {
                    Text("So is a safe starting weight, from your")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                    GlossaryTerm(term: "Working set")
                    Text("data.")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                }
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .calibrationComplete)
            }
        }
    }
}
