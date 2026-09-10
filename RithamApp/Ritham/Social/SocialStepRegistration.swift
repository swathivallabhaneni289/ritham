import Foundation

/// The single aggregate registrar for every Phase 4.1 social feature area, calling each area's own
/// registrar exactly once -- `StepBootstrap` calls only this file, the same single-call-site
/// pattern `Phase2StepRegistration`/`Phase3StepRegistration` already established, so later social
/// plans (friends, groups, goal-events, feed, certificates) each append their own registrar call
/// here without ever touching `StepBootstrap` or each other's files.
@MainActor
enum SocialStepRegistration {
    static func registerAll() {
        SocialIdentityRegistration.registerAll()
        PrivacyZoneRegistration.registerAll()
        FriendsRegistration.registerAll()
        GroupsRegistration.registerAll()
        GoalEventsRegistration.registerAll()
        CompletionRegistration.registerAll()
        FeedRegistration.registerAll()
    }
}
