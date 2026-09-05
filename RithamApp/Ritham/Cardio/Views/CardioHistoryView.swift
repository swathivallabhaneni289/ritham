import SwiftUI
import RithamCore

// Minimal real stand-in landed in this plan's Task 1 so `CardioRegistration` can register a real
// type immediately. Task 3 rewrites this file in full with the sensor-verified-vs-manual list,
// the date-range filter, the empty state, and the native route map CARDIO-01/CARDIO-03 require,
// plus a new `RouteComparisonView.swift`. Not a "Placeholder"-named stand-in (see
// `CardioRegistration.swift`'s header comment) -- a real, if minimal, presenter for
// `.cardioHistory` that will be replaced wholesale a few tasks later in this same execution.
struct CardioHistoryView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioHistoryView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Cardio history") {
            Text("Training history lands here in this plan's Task 3.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
    }
}
