import Foundation

// Registers this file group's four screens with `StepRegistry` -- one registrar file per screen
// group, per plan 01-09/01-12's contract, so wave 7's plans (01-13, 01-15, 01-16) can each
// register their own screens without any of them editing a shared function. This file is never
// invoked from the app entry point itself: plan 01-18 owns the single bootstrap file that calls
// every registrar. Tests in this plan call `registerAll()` directly in their own setup.
//
// DIET-01's dietary-pattern question is deliberately not registered here (or anywhere in
// onboarding) -- per direct product feedback (2026-08-29) it moved to `SettingsView`, which
// edits `flow.answers.dietaryPattern` directly rather than through a registered
// `OnboardingStep`. See `OnboardingRouter`'s doc comment and `01-CONTEXT.md`'s
// dietary-pattern-placement note.
@MainActor
enum AboutYouRegistration {
    static func registerAll() {
        StepRegistry.register(WelcomeStepView.self)
        StepRegistry.register(AgeStepView.self)
        StepRegistry.register(AgeIneligibleStepView.self)
        StepRegistry.register(PrivacyExplainerStepView.self)
    }
}
