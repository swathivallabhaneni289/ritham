import Foundation

// Registers the two steps that close out the onboarding flow: `.screeningComplete` (the
// acknowledgement shown right after the universal follow-up saves) and `.home` (the flow's
// terminal step). Neither belongs to any of the phase's three screen-group plans (About You,
// Calibration, Screening) -- `deferred-items.md`'s "From 01-17" entry documents that gap and
// flags it as this plan's own Rule 3 fix, since `PhaseCoverageTests`'s own
// `unregisteredSteps`-is-empty acceptance gate cannot pass without a registrar for both.
//
// Like the other three registrars, this is NOT invoked from the app entry point directly --
// `StepBootstrap` (this same plan) owns the single call site that calls every registrar,
// including this one.
@MainActor
enum OnboardingCompletionRegistration {
    static func registerAll() {
        StepRegistry.register(ScreeningCompleteStepView.self)
        StepRegistry.register(HomeStepView.self)
    }
}
