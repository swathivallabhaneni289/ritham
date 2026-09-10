import Foundation

/// Registers this plan's two `OnboardingStepPresenting` conformers (`FriendsListView`,
/// `AddFriendView`) under `.friendsList`/`.addFriend`, matching `SocialIdentityRegistration`'s and
/// `PrivacyZoneRegistration`'s identical one-registrar-per-social-area pattern.
@MainActor
enum FriendsRegistration {
    static func registerAll() {
        StepRegistry.register(FriendsListView.self)
        StepRegistry.register(AddFriendView.self)
    }
}
