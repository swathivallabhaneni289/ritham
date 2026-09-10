import SwiftUI
import RithamCore

/// Stub-then-extend (matching this codebase's own precedent, e.g. `02-03-SUMMARY.md`'s
/// `SupersetGroupID`): Task 2 adds `.addFriend` to `OnboardingStep` and
/// `StepRegistry.unregisteredSteps` requires a registered presenter for every case, but the real
/// three-connection-path screen is Task 3's own scope. This minimal body is replaced in full by
/// Task 3 -- nothing here is meant to survive this plan's execution.
struct AddFriendView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .addFriend

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(AddFriendView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Add a friend") {
            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
    }
}
