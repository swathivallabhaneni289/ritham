import Foundation

// This file exists here, in the phase's last wave, on purpose. Plans 01-13, 01-15, and 01-16
// all run in the same wave and each contributes a registrar (`AboutYouRegistration`,
// `CalibrationRegistration`, `ScreeningRegistration`); if each of them also appended its call
// to a shared bootstrap function, that one file would be a write conflict between parallel
// executors. Owning the call site in a single later plan removes the conflict without
// serialising the screen work. A later phase adding a new screen group should extend this
// file's call list rather than reintroduce per-plan wiring at the app-entry-point level.
//
// `.screeningComplete` and `.home` belong to no screen-group plan from wave 7 -- neither
// `AboutYouRegistration`, `CalibrationRegistration`, nor `ScreeningRegistration` covers them
// (see `deferred-items.md`'s "From 01-17" entry, which flagged this as a gap this plan's own
// `PhaseCoverageTests.unregisteredSteps` acceptance gate would trip on if left unresolved).
// `OnboardingCompletionRegistration` closes that gap and is called here alongside the other
// three, so `registerAllSteps()` genuinely registers every `OnboardingStep` case by the time
// it returns.
//
// Calling `registerAllSteps()` more than once is safe: `StepRegistry.register` overwrites any
// prior registration for the same step with an equivalent factory closure, so repeated calls
// (every test suite in this phase calls it in its own `init()`) never produce a duplicate or
// divergent registration -- the registry ends in the same state regardless of call count.
@MainActor
enum StepBootstrap {
    static func registerAllSteps() {
        AboutYouRegistration.registerAll()
        CalibrationRegistration.registerAll()
        ScreeningRegistration.registerAll()
        OnboardingCompletionRegistration.registerAll()
    }
}
