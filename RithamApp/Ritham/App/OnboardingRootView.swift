import SwiftUI
import RithamCore

// CROSSGEN-05: there is exactly one navigation container for the whole app, for every user
// regardless of age. This file is the only place that may declare a navigation stack or a
// destination resolver for `OnboardingStep` — age never selects a different root, and no screen
// may wrap itself in its own container. Reaching a step through this container is the UI-level
// expression of being permitted to use whatever that step unlocks (see this plan's threat model).
//
// Root-step resolution: before `hasCompletedOnboarding` existed, this container always rooted at
// `.welcome`, so a returning user who had already finished onboarding was made to re-answer every
// question on every relaunch — there was no persisted completion signal of any kind.
// `resolvedRootStep` reads the one signal `ScreeningCompleteStepView` now writes
// (`HealthDataStore.markOnboardingCompleted`) and roots at `.home` instead once it is set.
//
// `rootStep` is determined exactly once per app launch, in `.task`, and cached in `@State` —
// never recomputed reactively off `flow.path`. `flow` is `@Observable`, and `$flow.path` is read
// inside `body`; recomputing the root on every `flow.path` mutation would flip a still-onboarding
// user's NavigationStack root out from under them the instant `markOnboardingCompleted()` runs
// mid-session (their `path` already holds `.screeningComplete` → `.home`, so the root and the
// path's own last element would both become `.home` at once), reshuffling the stack they are
// actively standing in. A one-shot read at launch avoids that entirely: for the remainder of any
// single session, this container behaves exactly as it always has.
struct OnboardingRootView: View {
    @State private var flow = OnboardingFlow()
    @State private var rootStep: OnboardingStep?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let rootStep {
                NavigationStack(path: $flow.path) {
                    StepRegistry.view(for: rootStep, flow: flow)
                        .navigationDestination(for: OnboardingStep.self) { step in
                            StepRegistry.view(for: step, flow: flow)
                        }
                }
            }
        }
        .task {
            guard rootStep == nil else { return }
            let store = HealthDataStore(context: modelContext)
            let hasCompletedOnboarding = (try? store.loadHasCompletedOnboarding()) ?? false
            rootStep = Self.resolvedRootStep(hasCompletedOnboarding: hasCompletedOnboarding)
        }
    }

    /// Pure, testable derivation — the real `.task` above calls this exact function, not a
    /// parallel copy, matching `HomeHubView.showsMovementSnapshotEntry`'s own precedent for
    /// making a routing decision assertable without rendering a view.
    nonisolated static func resolvedRootStep(hasCompletedOnboarding: Bool) -> OnboardingStep {
        hasCompletedOnboarding ? .home : .welcome
    }
}
