import Foundation

/// Registers `PrivacyZonesView` under `.privacyZones`. `SocialStepRegistration` calls this
/// alongside `SocialIdentityRegistration.registerAll()`, matching that file's own
/// one-registrar-call-per-social-area pattern -- `StepRegistry.unregisteredSteps` requires every
/// `OnboardingStep` case to have a registered presenter, including `.privacyZones`, even though
/// this screen is reached only from `SettingsView`'s own sheet presentation, never from
/// `OnboardingRouter` or `OnboardingFlow.open(_:)` -- `SocialIdentityRegistration`'s own
/// registration of `.signInWithApple` already establishes this identical shape.
@MainActor
enum PrivacyZoneRegistration {
    static func registerAll() {
        StepRegistry.register(PrivacyZonesView.self)
    }
}
