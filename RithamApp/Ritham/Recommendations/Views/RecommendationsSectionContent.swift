import SwiftUI
import RithamCore

/// The workout-plan content extracted verbatim out of `RecommendationsView` (04-RESEARCH.md
/// Pattern 1 / 04-PATTERNS.md). Renders the idle/loading/plan/error state machine only -- no
/// `RithamScreen`, `ScrollView`, header, background, `NavigationStack`, or dismiss control of any
/// kind (04-RESEARCH.md Anti-Patterns / Pitfall 5's sibling concern for this screen). A host
/// screen supplies all chrome: `RecommendationsView` wraps this in its own `RithamScreen` today,
/// and plan 04-02's dashboard embeds it directly inside a Dashboard Section Card.
///
/// `model` and `flow` are the exact same `RecommendationsModel`/`OnboardingFlow` instances any
/// host already constructed -- this type owns no state of its own and calls no `HealthDataStore`
/// method directly; every read/write goes through `RecommendationsModel`, unchanged.
struct RecommendationsSectionContent: View {
    let model: RecommendationsModel
    let flow: OnboardingFlow

    var body: some View {
        switch model.state {
        case .idle:
            idleContent
        case .loading:
            ProgressView("Building your plan...")
                .foregroundStyle(RithamColor.paper)
        case .plan(let plan):
            planContent(plan)
        case .error(let error):
            errorContent(error)
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("Get a plan built around your stored weekly frequency and starting point.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            PrimaryCTAButton(title: "Get my plan") {
                request()
            }
        }
    }

    @ViewBuilder
    private func planContent(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            // RECOVERY-01's only adjustment-related UI (03-UI-SPEC.md Component 7): one plain
            // plan-level banner plus an equal-weight toggle, shown only when a lighter adjustment
            // applies. This is literally the same button, whose title alternates -- never two
            // separate buttons with different styling, so invariant 2 ("never one primary and
            // one secondary") holds by construction rather than by two components matching.
            if model.adjustedPlan != nil {
                Text(MomentumCopy.Plan.banner)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                SecondaryCTAButton(
                    title: model.isDisplayingAdjustedPlan ? MomentumCopy.Plan.showOriginalCTA : MomentumCopy.Plan.showLighterCTA
                ) {
                    model.toggleDisplayedPlan()
                }
            }

            // Individual session rows below render identically regardless of which plan is
            // currently displayed -- no badge, asterisk, "lighter" tag, tint change, icon, or
            // reordering differentiates an adjusted row from an original one (RECOVERY-01
            // invariant 1). The only value that ever differs between the two plans is a session's
            // exercise `sets` count; every other field renders through the exact same code below
            // either way.
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
    private func errorContent(_ error: WorkoutPlanClientError) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("We couldn't reach the plan service. Check your connection and try again.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryCTAButton(title: "Retry") {
                request()
            }
        }
    }

    private func request() {
        Task {
            await model.requestPlan(flow: flow)
        }
    }
}
