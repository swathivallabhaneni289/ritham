import SwiftUI

// This file has exactly three owners, touched in this order across the phase's wave sequence.
// Each edit is additive — do not restructure what a prior owner added:
//   1. Plan 01-09 (this plan) creates the `@main` entry point and renders `OnboardingRootView`
//      inside a `WindowGroup`.
//   2. Plan 01-11 attaches the SwiftData `ModelContainer` this app persists to.
//   3. Plan 01-18 invokes `StepBootstrap.registerAllSteps()` before the root view is presented,
//      so every `OnboardingStep` resolves through `StepRegistry` by launch time.
// There is no universal-link handler here and none is ever added — Ritham has no parental-consent
// email flow of any kind (D-14), so there is nothing for a deep link to confirm.

@main
struct RithamApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingRootView()
        }
    }
}
