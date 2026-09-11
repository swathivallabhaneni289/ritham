import Foundation

/// Registers this plan's two `OnboardingStepPresenting` conformers (`CertificateRevealView`,
/// `CertificateArchiveView`) under `.certificate`/`.certificateArchive`, matching
/// `FeedRegistration`/`CompletionRegistration`'s identical one-registrar-per-social-area pattern.
@MainActor
enum CertificateRegistration {
    static func registerAll() {
        StepRegistry.register(CertificateRevealView.self)
        StepRegistry.register(CertificateArchiveView.self)
    }
}
