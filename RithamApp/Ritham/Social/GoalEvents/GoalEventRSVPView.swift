import SwiftUI
import RithamCore

/// Task 2's minimal stub, registered under `.goalEventRSVP` purely so
/// `StepRegistry.unregisteredSteps` stays empty once that case exists -- matching this codebase's
/// own established stub-then-extend precedent (`04.1-11-SUMMARY.md`'s `LeaveGroupSheet.swift`).
/// Task 3 of this same plan replaces this file wholesale with the real RSVP screen (the headcount,
/// the "I'm in" CTA, and the three load-bearing non-comparative constraints its own header comment
/// states).
struct GoalEventRSVPView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .goalEventRSVP

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GoalEventRSVPView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.GoalEvent.createHeadline) {
            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
    }
}
