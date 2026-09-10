import Foundation

/// Registers this plan's two `OnboardingStepPresenting` conformers (`GroupFeedView`,
/// `GroupHistoryView`) under `.groupFeed`/`.groupHistory`, matching
/// `GoalEventsRegistration`/`CompletionRegistration`'s identical one-registrar-per-social-area
/// pattern.
@MainActor
enum FeedRegistration {
    static func registerAll() {
        StepRegistry.register(GroupFeedView.self)
        StepRegistry.register(GroupHistoryView.self)
    }
}
