import Foundation

/// Registers this plan's two `OnboardingStepPresenting` conformers (`GroupListView`,
/// `GroupDetailView`) under `.groupList`/`.groupDetail`, matching `FriendsRegistration`'s
/// identical one-registrar-per-social-area pattern.
@MainActor
enum GroupsRegistration {
    static func registerAll() {
        StepRegistry.register(GroupListView.self)
        StepRegistry.register(GroupDetailView.self)
    }
}
