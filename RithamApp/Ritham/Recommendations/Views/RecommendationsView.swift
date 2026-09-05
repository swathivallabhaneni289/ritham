import SwiftData
import SwiftUI
import RithamCore

// D-03's dedicated Recommendations surface: the user opens this explicitly from the hub
// (`HomeHubView`'s "Recommendations" action, already wired) and asks for a plan here, rather than
// the pre-assessment being triggered by an inferred moment elsewhere in the app.
//
// On request, this gates on the pre-assessment-completion flag: the first request opens
// `PreAssessmentView` instead of calling the network at all; once that flag is true, a request
// goes straight to `WorkoutPlanClient`. The workout gate is resolved the same store-driven way
// `HealthProfileView` already does -- `activeConditionTags(now:)` through
// `GateEscalation.escalate(tags:answers:)` with an empty answers value, since no raw answer state
// is persisted after onboarding (the one known gap that re-derivation already carries: the G2/G3
// answer-driven escalation rule cannot be reconstructed from stored tags alone). This screen never
// re-derives gating logic of its own.
//
// No frequency or experience-level control lives on this screen: frequency is a Settings
// preference (plan 02-14) and the experience bucket is derived from the stored baseline --
// letting a user type either value here would reintroduce exactly the self-reported dropdown
// ONBOARD-01 forbids.
//
// STUB (TDD RED): `requestPlan` always opens the pre-assessment and never calls the client, so
// `RecommendationsScreenTests` fails meaningfully before the real gating/fetch/render behavior
// lands.

/// The screen's rendering state, driven entirely by `RecommendationsModel` so
/// `RecommendationsScreenTests` can assert every behavior without rendering the view.
enum RecommendationsState: Equatable {
    case idle
    case loading
    case plan(WorkoutPlan)
    case error(WorkoutPlanClientError)
}

@MainActor
@Observable
final class RecommendationsModel {
    private(set) var state: RecommendationsState = .idle

    init(store: HealthDataStore, client: WorkoutPlanClient = WorkoutPlanClient()) {}

    func requestPlan(flow: OnboardingFlow, now: Date = Date()) async {
        flow.open(.preAssessment)
    }
}

struct RecommendationsView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .recommendations

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(RecommendationsView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Recommendations") {
            EmptyView()
        }
    }
}
