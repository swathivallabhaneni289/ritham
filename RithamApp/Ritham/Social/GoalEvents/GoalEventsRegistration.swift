import Foundation

/// Registers this plan's two `OnboardingStepPresenting` conformers (`CreateGoalEventView`,
/// `GoalEventRSVPView`) under `.createGoalEvent`/`.goalEventRSVP`, matching `GroupsRegistration`'s
/// identical one-registrar-per-social-area pattern.
@MainActor
enum GoalEventsRegistration {
    static func registerAll() {
        StepRegistry.register(CreateGoalEventView.self)
        StepRegistry.register(GoalEventRSVPView.self)
    }
}
