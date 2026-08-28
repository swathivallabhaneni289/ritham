import SwiftUI
import RithamCore

// CROSSGEN-05: there is exactly one navigation container for the whole app, for every user
// regardless of age. This file is the only place that may declare a navigation stack or a
// destination resolver for `OnboardingStep` — age never selects a different root, and no screen
// may wrap itself in its own container. Reaching a step through this container is the UI-level
// expression of being permitted to use whatever that step unlocks (see this plan's threat model).
struct OnboardingRootView: View {
    @State private var flow = OnboardingFlow()

    var body: some View {
        NavigationStack(path: $flow.path) {
            StepRegistry.view(for: .welcome, flow: flow)
                .navigationDestination(for: OnboardingStep.self) { step in
                    StepRegistry.view(for: step, flow: flow)
                }
        }
    }
}
