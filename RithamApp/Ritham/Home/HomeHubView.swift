import SwiftUI
import RithamCore

/// The real home screen (CROSSGEN-01): a sectioned dashboard, not a vertical list of action
/// buttons. Every section renders its own real content -- progress blocks, session rows, plan
/// session rows, or a diet-pattern selector -- above any action control (04-UI-SPEC.md's
/// "card-vs-button-list discriminator"), replacing the earlier interim hub the user tested and
/// rejected during Phase 3 sign-off.
///
/// `.boundedHeaderOnly` fits this screen's own naming rationale (a bounded header band, used by
/// screens that explain or introduce something without collecting, confirming, or blocking on
/// health or age data themselves): this hub collects nothing itself -- every write happens inside
/// an embedded section's own model/store call, unchanged from before this rewrite.
///
/// Navigates to every pushed destination through `flow.open(_:)`, never a second navigation
/// container -- CROSSGEN-05 reserves the app's one navigation container for `OnboardingRootView`.
/// Settings (and the health profile it can open) are sheets, exactly as `SettingsView` itself
/// already uses sheets for its own sub-screens, never pushes. The `SettingsView` sheet below is
/// the only surviving route to the food-allergy screening question (`DietPlanView`'s checklist and
/// severity follow-up) -- see `dietPlanSection`'s own comment for why that question does not also
/// live on this dashboard.
struct HomeHubView: View {
    // Dashboard copy catalog: centralized `nonisolated static let` constants, matching this
    // type's existing `nonisolated static func` idiom for testable derivations (see the bottom
    // extension), rather than scattering section-heading literals across `body`. Not added to
    // `RithamCore`'s `MomentumCopy` catalog: this plan's own verification requires `RithamCore`
    // untouched (Scripts/test-core.sh must pass with no diff), and every string below is
    // planner-authored purely for visual grouping, not a verbatim-shipped-strings-table entry.
    nonisolated static let dashboardHeadline = "Home"
    nonisolated static let exerciseSectionHeading = "This week's activity"
    nonisolated static let workoutPlanSectionHeading = "Your workout plan"
    nonisolated static let dietPlanSectionHeading = "Diet plan"

    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingSettings = false
    @State private var isPresentingHealthProfile = false

    // D-08's Momentum summary section state: a plain `MomentumSummary?`, loaded via the same
    // `MomentumSummaryReader` `MomentumView` (plan 03-06) constructs over its own `HealthDataStore`
    // -- proven to be the same underlying read by `hubAndDetailScreenReadTheSameUnderlyingData`
    // (HomeHubTests). `MomentumSummary` itself carries no sleep-check-in member of any kind
    // (03-05's own structural guarantee, `momentumSummaryCarriesNoSleepState`), so this state can
    // never grow a sleep-derived indicator without editing `MomentumSummary`'s own declaration
    // first -- not just by adding a line to this view.
    @State private var momentumSummary: MomentumSummary?

    // WR-03's fix: a genuine store-read failure previously rendered identically to "no Momentum
    // section" (both left `momentumSummary` at `nil`), making a real persistence problem
    // indistinguishable from a legitimately empty state. This flag lets `momentumSection`
    // surface `OnboardingCopy.Errors.savingFailed`, matching `MomentumView`/`RecommendationsView`'s
    // existing `loadError` pattern, instead of collapsing the failure into silence.
    @State private var momentumLoadFailed = false

    // MOMENTUM-07/D-09's opt-in-gated entry state: loaded alongside `momentumSummary` in this
    // view's one existing appearance handler below (never a second one). Off by default
    // (`HealthDataStore.loadMovementSnapshotOptIn`'s own default), which is what makes the CTA
    // below render nothing at all until the user opts in from Settings.
    @State private var isMovementSnapshotEnabled = false

    // D-04: the workout-plan section's own model, constructed once in this view's existing
    // `onAppear` alongside the Momentum summary load. A plain `RecommendationsModel?`, not a
    // hub-owned aggregate view model (D-08's "no dashboard-specific aggregate view model" rule,
    // 04-CONTEXT.md's canonical-refs restatement) -- the same independently-loaded-per-section
    // pattern `momentumSummary` above already uses, and the same construction
    // `RecommendationsView` itself already performs.
    @State private var recommendationsModel: RecommendationsModel?

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: HomeHubView.dashboardHeadline
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                // D-08: the hub's own decorative surface (`.boundedHeaderOnly` above) stays
                // exactly as it is -- every section below renders in the scrollable content area
                // under the header, never inside the header region itself, so the hub's existing
                // header ornament and any section's own progress-block strip never share one
                // viewport (03-UI-SPEC.md Component 1's own "two circular motifs" rationale;
                // 04-UI-SPEC.md restates this as the Ring Collision rule).
                sectionCard { momentumSection }
                sectionCard { sleepSection }
                sectionCard { exerciseSection }
                sectionCard { workoutPlanSection }
                sectionCard { dietPlanSection }
                overflowRow
            }
        }
        .onAppear {
            let store = HealthDataStore(context: modelContext)
            let reader = MomentumSummaryReader(store: store, calendar: .current)
            do {
                momentumSummary = try reader.summary(now: Date())
                momentumLoadFailed = false
            } catch {
                momentumSummary = nil
                momentumLoadFailed = true
            }
            // Deliberately left as a silent `try?` fallback-to-off, unlike the summary load
            // above: a failure here only hides one already-off-by-default CTA (WR-03's finding
            // cites the summary read as the case that matters, since that one collapses a whole
            // section's failure into "you haven't done anything yet").
            isMovementSnapshotEnabled = (try? store.loadMovementSnapshotOptIn()) ?? false

            if recommendationsModel == nil {
                recommendationsModel = RecommendationsModel(store: store)
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView(
                flow: flow,
                onOpenHealthProfile: {
                    isPresentingSettings = false
                    isPresentingHealthProfile = true
                }
            )
        }
        .sheet(isPresented: $isPresentingHealthProfile) {
            HealthProfileView()
        }
    }

    // MARK: - Dashboard sections
    //
    // Every member below is declared above the Momentum-section marker comment further down this
    // file, per this plan's own structural constraint: `momentumSection` must stay the struct's
    // last member, with nothing between that marker and the file's bottom `extension HomeHubView`
    // ever mentioning the snapshot entry (see `exerciseSection`, which owns that entry, declared
    // here instead).

    // RECOVERY-01's daily sleep check-in entry point, carried over unchanged from today's hub per
    // D-03. Invariant 3 is absolute here: no badge, dot, checkmark, count, "logged today" marker,
    // or any state derived from sleep check-in history, on this card or any other -- the section's
    // heading and its tap affordance are both the same plain, unconditional string
    // (`MomentumCopy.Sleep.headline`), never derived from whether a check-in exists for today, so
    // a skipped check-in is indistinguishable, app-wide, from a day the prompt was never shown.
    // 04-UI-SPEC.md's Copywriting Contract names exactly one string for this whole section, so no
    // second, distinct button label was invented for it.
    @ViewBuilder
    private var sleepSection: some View {
        Text(MomentumCopy.Sleep.headline)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        SecondaryCTAButton(title: MomentumCopy.Sleep.headline) {
            flow.open(.sleepCheckIn)
        }
    }

    // The logged-exercise section (D-02): reads `momentumSummary?.recentSessions` -- the same
    // already-loaded `MomentumSummaryReader` result `momentumSection` reads, never re-derived a
    // second way. Carries the tracking entry points (Track cardio, Log strength, their history
    // screens, and the opt-in-gated Daily Movement Snapshot entry) that used to sit in the hub's
    // old vertical button list (D-07). Placing the Movement Snapshot entry here, two cards below
    // the Momentum section, is what satisfies 04-RESEARCH.md Pitfall 6's locked adjacency rule --
    // a carried-forward Phase 3 constraint, not a fresh layout choice.
    @ViewBuilder
    private var exerciseSection: some View {
        Text(HomeHubView.exerciseSectionHeading)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        if let summary = momentumSummary, !summary.recentSessions.isEmpty {
            ForEach(summary.recentSessions) { session in
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text(session.title)
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)

                    if let verificationLabel = session.verificationLabel {
                        Text(verificationLabel)
                            .font(RithamType.label)
                            .modifier(RithamType.fineprint())
                            .foregroundStyle(RithamColor.paper)
                    }
                }
            }
        } else {
            // Relocated here from `MomentumDashboardSection` in this plan's Task 2 -- see that
            // file's own header comment for why. 04-UI-SPEC.md section 3 assigns this empty state
            // to the exercise card, not the Momentum card, so it now renders in exactly one place.
            VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                Text(MomentumCopy.Empty.noSessionsHeadline)
                    .font(RithamType.body.weight(.semibold))
                    .foregroundStyle(RithamColor.paper)
                Text(MomentumCopy.Empty.noSessionsBody)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        PrimaryCTAButton(title: "Track cardio") {
            flow.open(.cardioActivityPicker)
        }
        SecondaryCTAButton(title: "Cardio history") {
            flow.open(.cardioHistory)
        }
        PrimaryCTAButton(title: "Log strength") {
            flow.open(.strengthSession)
        }
        SecondaryCTAButton(title: "Strength history") {
            flow.open(.strengthHistory)
        }

        // MOMENTUM-07/D-09: the Daily Movement Snapshot's opt-in-gated entry. Deliberately placed
        // here, inside the exercise section rather than adjacent to the Momentum card -- the
        // snapshot is the deliberately quiet counterpart to Momentum and must carry no streak,
        // shield or target association, including by mere adjacency (04-RESEARCH.md Pitfall 6).
        // When the opt-in is off, this renders nothing at all: no disabled row, no greyed entry,
        // no "turn this on" prompt -- an off opt-in is indistinguishable from the feature not
        // existing.
        if HomeHubView.showsMovementSnapshotEntry(optIn: isMovementSnapshotEnabled) {
            SecondaryCTAButton(title: "Daily Movement Snapshot") {
                flow.open(.movementSnapshot)
            }
        }
    }

    // D-04: the workout-plan section, embedding `RecommendationsSectionContent` (04-01's
    // extraction) directly rather than a button that navigates away. Deliberately never calls
    // `requestPlan` from this view's `onAppear` or from any other lifecycle hook --
    // `RecommendationsModel.requestPlan` opens `.preAssessment` when the pre-assessment flag is
    // false, so an auto-request would push the pre-assessment screen on top of home with no user
    // action on a cold launch, and would hit the Go plan service on every launch. The landing
    // state is `.idle` plus `RecommendationsSectionContent`'s own "Get my plan" control -- the
    // user's tap is the only trigger.
    @ViewBuilder
    private var workoutPlanSection: some View {
        Text(HomeHubView.workoutPlanSectionHeading)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        if let recommendationsModel {
            RecommendationsSectionContent(model: recommendationsModel, flow: flow)
        } else {
            ProgressView()
        }
    }

    // D-05 (narrowed per 04-RESEARCH.md Pitfall 3): embeds only `DietPlanSectionContent`, the
    // DIET-01-isolated dietary-pattern and allergen pickers (04-01's extraction) -- never
    // `DietPlanView` and never a re-created food-allergy checklist control. The food-allergy
    // screening checkbox and its severity follow-up call `GateResolution.resolve`/
    // `saveScreeningResult` against `flow.answers.screening`, which is empty on every fresh app
    // launch; embedding that control on a screen reached fresh on every relaunch would silently
    // wipe real condition-tag data the first time a returning user touched it. That question stays
    // in the Settings-presented `DietPlanView` only (this file's `SettingsView` sheet below).
    @ViewBuilder
    private var dietPlanSection: some View {
        Text(HomeHubView.dietPlanSectionHeading)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        DietPlanSectionContent(flow: flow)
    }

    // D-07: Guidance and Settings, reduced to a single compact overflow row rather than the two
    // full-width `PrimaryCTAButton`/`SecondaryCTAButton` rows the old hub used -- a leftover
    // button stack under real sections is the same rejected pattern with extra steps
    // (04-UI-SPEC.md section 6). Not wrapped in `sectionCard`: this is an overflow affordance, not
    // a content section.
    private var overflowRow: some View {
        HStack(spacing: RithamSpacing.md) {
            Button("Guidance") {
                flow.open(.guidance)
            }
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .accessibilityLabel("Guidance")

            Button("Settings") {
                isPresentingSettings = true
            }
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .accessibilityLabel("Settings")
        }
    }

    // The Dashboard Section Card treatment (04-UI-SPEC.md "Dashboard Section Card"): a low-opacity
    // paper tint on ink, not `ReScreenBanner`'s solid-paper fill -- four-plus solid off-white slabs
    // would invert the screen's 60/30/10 color split. Applied to every content section above;
    // `overflowRow` deliberately does not use this helper (see its own comment).
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            content()
        }
        .padding(RithamSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RithamColor.paper.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }

    // MARK: - D-08's Momentum summary section
    //
    // Rendering itself now lives in `MomentumDashboardSection` (Ritham/Momentum/Components/) --
    // see that type's own header comment for why it moved there. This member is HomeHubView's own
    // bridging point: HomeHubView still owns and passes `momentumSummary`/`momentumLoadFailed`
    // down as parameters (D-08/03-CONTEXT precedent -- no dashboard-specific aggregate view
    // model), rather than the new component loading its own state a second way.
    @ViewBuilder
    private var momentumSection: some View {
        MomentumDashboardSection(summary: momentumSummary, loadFailed: momentumLoadFailed, flow: flow)
    }
}

// MARK: - Pure, testable derivations (see MomentumView.swift's header for why these must be
// `nonisolated`: SwiftUI's `View` protocol is itself `@MainActor`, which infers `@MainActor`
// isolation onto every member of a conforming type by default, and Swift Testing runs test
// functions off the main actor).

extension HomeHubView {
    /// Whether the Daily Movement Snapshot's hub entry should render for a given opt-in state.
    /// The real `body` above calls this exact function -- not a parallel, independently
    /// maintained copy -- so `MovementSnapshotViewTests` exercises the same logic the rendered
    /// screen uses.
    nonisolated static func showsMovementSnapshotEntry(optIn: Bool) -> Bool {
        optIn
    }

    /// The hub's `flow.open(_:)`-reachable destinations for a given movement-snapshot opt-in
    /// state, used by `MovementSnapshotViewTests` to assert the snapshot step's exact
    /// presence/absence without rendering this view. Enumerates only the destinations `body`
    /// opens *directly* via a `flow.open(_:)` call inside this file. `.recommendations` was
    /// removed here in plan 04-02, once the dashboard's workout-plan section started embedding
    /// `RecommendationsSectionContent` inline instead of pushing to it -- `.recommendations`
    /// stays registered regardless (`StepRegistry.unregisteredSteps` is asserted empty per-case,
    /// not per-reachability; 04-RESEARCH.md Pitfall 4). `.preAssessment` is reachable indirectly,
    /// through the embedded workout-plan section's own `RecommendationsModel.requestPlan`, and
    /// `.momentum` is reachable indirectly through `MomentumDashboardSection`'s own CTA -- neither
    /// is a direct call inside this file's `body`, so neither is listed here.
    nonisolated static func routingSteps(movementSnapshotOptIn: Bool) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .sleepCheckIn, .cardioActivityPicker, .cardioHistory,
            .strengthSession, .strengthHistory, .guidance,
        ]
        if showsMovementSnapshotEntry(optIn: movementSnapshotOptIn) {
            steps.append(.movementSnapshot)
        }
        return steps
    }
}
