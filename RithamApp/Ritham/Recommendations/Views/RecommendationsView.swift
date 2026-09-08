import SwiftData
import SwiftUI
import RithamCore

// D-03's dedicated Recommendations surface: originally the user opened this explicitly from the
// hub (`HomeHubView`'s "Recommendations" action). As of plan 04-01/04-02, the dashboard embeds
// this screen's content (`RecommendationsSectionContent`) directly as a workout-plan section
// instead, so nothing pushes to `.recommendations` from the running app any more. This screen
// stays registered anyway -- 04-RESEARCH.md Pitfall 4: `StepRegistry.unregisteredSteps` is
// asserted empty per-case, not per-reachability, so every `OnboardingStep` must resolve to a
// presenter whether or not anything currently navigates to it.
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

    // RECOVERY-01/D-04: the adjustment is a client-side post-processing step applied entirely
    // after `client.fetchPlan` returns, over the plan already in hand. `originalPlan` is always
    // the exact plan `WorkoutPlanClient` returned; `adjustedPlan` is only ever non-nil when
    // today's stored sleep check-in is Poor. Neither property is read by `fetchPlan` to build the
    // request -- sleep-quality data never crosses into `WorkoutPlanRequest`, and `WorkoutPlanClient`
    // itself is untouched by this file (git diff --stat on that file is empty for this plan).
    private(set) var originalPlan: WorkoutPlan?
    private(set) var adjustedPlan: WorkoutPlan?
    private(set) var isDisplayingAdjustedPlan = false

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

    /// RECOVERY-01 invariant 2: "do the original session instead" is always available and
    /// equal-weight. Flips which plan is displayed and updates `state` to match -- a no-op when
    /// no adjustment applies (`adjustedPlan == nil`), since there is nothing to toggle to.
    func toggleDisplayedPlan() {
        guard let originalPlan, let adjustedPlan else { return }
        isDisplayingAdjustedPlan.toggle()
        state = .plan(isDisplayingAdjustedPlan ? adjustedPlan : originalPlan)
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

            // Read today's check-in and compute the shift entirely after the client has already
            // returned -- no new network round-trip, no field added anywhere upstream of this
            // point. A missing/unreadable check-in (`try?`) is treated the same as no check-in at
            // all, matching `SleepAdjustment.shift(for: nil)`'s own "skip has zero effect" rule.
            let checkIn = try? store.loadSleepCheckIn(on: now)
            let shift = SleepAdjustment.shift(for: checkIn)

            originalPlan = plan
            if shift == .lighter {
                // D-11: the adjustment applies uniformly across every session in the
                // currently-displayed plan, never a single day singled out by the session's own
                // ordinal (a plain sequence number with no calendar-weekday meaning) -- every
                // session below is mapped through the identical
                // `SleepAdjustment.adjustedSetCount` lever.
                let lighterPlan = Self.applyingLighterShift(to: plan)
                adjustedPlan = lighterPlan
                isDisplayingAdjustedPlan = true
                state = .plan(lighterPlan)
            } else {
                adjustedPlan = nil
                isDisplayingAdjustedPlan = false
                state = .plan(plan)
            }
        } catch let error as WorkoutPlanClientError {
            state = .error(error)
        } catch {
            state = .error(.transport)
        }
    }

    /// Maps every session's every exercise through `SleepAdjustment.adjustedSetCount`, leaving
    /// the rep range, the focus text, the day index, the frequency and the guidance note
    /// untouched -- the single numeric lever this adjustment is permitted to touch (RECOVERY-01
    /// invariant 1: no other field on a session row ever differs between the two plans).
    private static func applyingLighterShift(to plan: WorkoutPlan) -> WorkoutPlan {
        let adjustedSessions = plan.sessions.map { session -> WorkoutPlanSession in
            let adjustedExercises = session.exercises.map { exercise -> WorkoutPlanExercise in
                WorkoutPlanExercise(
                    name: exercise.name,
                    sets: SleepAdjustment.adjustedSetCount(exercise.sets, shift: .lighter),
                    repRange: exercise.repRange
                )
            }
            return WorkoutPlanSession(dayIndex: session.dayIndex, focus: session.focus, exercises: adjustedExercises)
        }
        return WorkoutPlan(frequencyPerWeek: plan.frequencyPerWeek, sessions: adjustedSessions, guidanceNote: plan.guidanceNote)
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
            if let model {
                RecommendationsSectionContent(model: model, flow: flow)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil {
                model = RecommendationsModel(store: HealthDataStore(context: modelContext))
            }
        }
    }
}
