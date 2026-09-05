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

    private let store: HealthDataStore
    private let client: WorkoutPlanClient

    init(store: HealthDataStore, client: WorkoutPlanClient = WorkoutPlanClient()) {
        self.store = store
        self.client = client
    }

    /// The single entry point for "request a plan." When the pre-assessment has not yet been
    /// completed, this opens it and returns without touching the network at all -- the first
    /// request must route to the pre-assessment before any plan is shown. Once the flag is true,
    /// this proceeds straight to fetching a plan every time it is called, including on retry.
    func requestPlan(flow: OnboardingFlow, now: Date = Date()) async {
        guard (try? store.loadHasCompletedPreAssessment()) == true else {
            flow.open(.preAssessment)
            return
        }
        await fetchPlan(now: now)
    }

    private func fetchPlan(now: Date) async {
        state = .loading
        do {
            let frequency = try store.loadWeeklyFrequency()
            let experience = try store.experienceLevel()
            let tags = try store.activeConditionTags(now: now)
            let gates = GateEscalation.escalate(tags: Set(tags), answers: ScreeningAnswers())

            let plan = try await client.fetchPlan(
                frequencyPerWeek: frequency,
                experienceLevel: experience,
                workoutGate: gates.workout
            )
            state = .plan(plan)
        } catch let error as WorkoutPlanClientError {
            state = .error(error)
        } catch {
            state = .error(.transport)
        }
    }
}

struct RecommendationsView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .recommendations

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(RecommendationsView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var model: RecommendationsModel?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Recommendations") {
            content
        }
        .onAppear {
            if model == nil {
                model = RecommendationsModel(store: HealthDataStore(context: modelContext))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            switch model.state {
            case .idle:
                idleContent(model)
            case .loading:
                ProgressView("Building your plan...")
                    .foregroundStyle(RithamColor.paper)
            case .plan(let plan):
                planContent(plan)
            case .error(let error):
                errorContent(error, model: model)
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func idleContent(_ model: RecommendationsModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("Get a plan built around your stored weekly frequency and starting point.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            PrimaryCTAButton(title: "Get my plan") {
                request(model)
            }
        }
    }

    @ViewBuilder
    private func planContent(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            ForEach(plan.sessions) { session in
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text("Day \(session.dayIndex): \(session.focus)")
                        .font(RithamType.body.weight(.semibold))
                    ForEach(session.exercises, id: \.name) { exercise in
                        Text("\(exercise.name) -- \(exercise.sets) sets, \(exercise.repRange) reps")
                    }
                }
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
            }

            Text(plan.guidanceNote)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func errorContent(_ error: WorkoutPlanClientError, model: RecommendationsModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("We couldn't reach the plan service. Check your connection and try again.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryCTAButton(title: "Retry") {
                request(model)
            }
        }
    }

    private func request(_ model: RecommendationsModel) {
        Task {
            await model.requestPlan(flow: flow)
        }
    }
}
