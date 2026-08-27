import Foundation

// Registers this plan's seven screening screens with `StepRegistry` -- the opening disclaimer,
// gate section, clearance interstitial, condition checklist, severity follow-ups, eating-pattern
// (SCOFF) follow-up, and universal follow-up. NOT invoked from the app entry point -- plan 01-18
// owns the single bootstrap file that calls every registrar, so four wave-7 plans do not all
// append to one shared function. Tests in this plan call `registerAll()` directly in their own
// setup.
@MainActor
enum ScreeningRegistration {
    static func registerAll() {
        StepRegistry.register(ScreeningOpeningDisclaimerView.self)
        StepRegistry.register(GateSectionView.self)
        StepRegistry.register(ClearanceInterstitialView.self)
        StepRegistry.register(ConditionChecklistView.self)
        StepRegistry.register(SeverityFollowUpView.self)
        StepRegistry.register(EatingPatternFollowUpView.self)
        StepRegistry.register(UniversalFollowUpView.self)
    }
}
