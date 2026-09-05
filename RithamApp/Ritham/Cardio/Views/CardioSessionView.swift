import SwiftUI
import RithamCore

// Minimal real stand-in landed in this plan's Task 1 so `CardioRegistration` can register a real
// type immediately (its own action text requires registering all three real screens together).
// Task 2 rewrites this file in full with the live GPS/manual capture, the two independent
// confidence indicators, grade-adjusted pace, and denied-authorization fallback CARDIO-02
// requires. This is not a "Placeholder"-named stand-in (see `CardioRegistration.swift`'s header
// comment for why that distinction matters) -- it is a real, if minimal, presenter for
// `.cardioSession` that will be replaced wholesale a few tasks later in this same execution.
struct CardioSessionView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioSessionView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Cardio session") {
            Text("Session tracking for \(flow.cardioActivityType.displayName) lands here in this plan's Task 2.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
    }
}
