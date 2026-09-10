import Foundation

/// Registers this plan's one `OnboardingStepPresenting` conformer (`CompletionLoggingView`) under
/// `.completionLogging`, matching `GoalEventsRegistration`/`GroupsRegistration`'s identical
/// one-registrar-per-social-area pattern.
@MainActor
enum CompletionRegistration {
    static func registerAll() {
        StepRegistry.register(CompletionLoggingView.self)
    }
}
