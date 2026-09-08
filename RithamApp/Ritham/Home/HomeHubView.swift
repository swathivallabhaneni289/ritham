import SwiftUI
import RithamCore

/// The real home screen (CROSSGEN-01): a sectioned dashboard, not a vertical list of action
/// buttons. Every section renders its own real content -- progress blocks, session rows, plan
/// summary, or a dietary-pattern name -- above any tap affordance (04-UI-SPEC.md's
/// "card-vs-button-list discriminator"), replacing the earlier interim hub the user tested and
/// rejected during Phase 3 sign-off.
///
/// **Checkpoint revision (2026-09-08):** the workout-plan and diet-plan sections moved from
/// always-inline embeds (the original D-04/D-05) to compact tap-to-open summary cards, per direct
/// human-checkpoint feedback during Task 3's Simulator review -- see 04-CONTEXT.md's dated
/// revision. The Momentum and sleep sections became a two-column grid row at the same time, per
/// the same feedback round, so the dashboard reads as an organized grid rather than one long
/// vertical stack.
///
/// `.boundedHeaderOnly` fits this screen's own naming rationale (a bounded header band, used by
/// screens that explain or introduce something without collecting, confirming, or blocking on
/// health or age data themselves): this hub collects nothing itself -- every write happens inside
/// an embedded section's own model/store call, unchanged from before this rewrite.
///
/// Navigates to every pushed destination through `flow.open(_:)`, never a second navigation
/// container -- CROSSGEN-05 reserves the app's one navigation container for `OnboardingRootView`.
/// Settings, the health profile, the workout-plan quick view and the diet-plan quick view are all
/// sheets, exactly as `SettingsView` itself already uses sheets for its own sub-screens, never
/// pushes. The `SettingsView` sheet below is the only surviving route to the food-allergy
/// screening question (`DietPlanView`'s checklist and severity follow-up) -- `DietPlanQuickEditView`
/// deliberately does not carry it; see that type's own header comment.
struct HomeHubView: View {
    // Dashboard copy catalog: centralized `nonisolated static let` constants, matching this
    // type's existing `nonisolated static func` idiom for testable derivations (see the bottom
    // extension), rather than scattering section-heading literals across `body`. Not added to
    // `RithamCore`'s `MomentumCopy` catalog: this plan's own verification requires `RithamCore`
    // untouched (Scripts/test-core.sh must pass with no diff), and every string below is
    // planner-authored purely for visual grouping, not a verbatim-shipped-strings-table entry.
    nonisolated static let dashboardHeadline = "Home"
    nonisolated static let exerciseSectionHeading = "This week's activity"
    nonisolated static let workoutPlanSectionHeading = "Workout plan"
    nonisolated static let dietPlanSectionHeading = "Diet plan"
    nonisolated static let workoutPlanIdleStatus = "Tap to get your plan"
    nonisolated static let workoutPlanLoadingStatus = "Building your plan…"
    nonisolated static let workoutPlanErrorStatus = "Couldn't load — tap to retry"
    nonisolated static let dietPlanUnsetStatus = "Not set"

    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingSettings = false
    @State private var isPresentingHealthProfile = false
    @State private var isPresentingWorkoutPlan = false
    @State private var isPresentingDietPlan = false

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

    // D-04 (as checkpoint-revised): the workout-plan card's own model, constructed once in this
    // view's existing `onAppear` alongside the Momentum summary load. A plain
    // `RecommendationsModel?`, not a hub-owned aggregate view model (D-08's "no dashboard-specific
    // aggregate view model" rule, 04-CONTEXT.md's canonical-refs restatement) -- the same
    // independently-loaded-per-section pattern `momentumSummary` above already uses. Shared by
    // reference with `RecommendationsQuickView` when the sheet opens, so a plan already fetched
    // shows immediately in the sheet, and a fetch made inside the sheet updates the summary card
    // once dismissed -- both observe the same `@Observable` instance.
    @State private var recommendationsModel: RecommendationsModel?

    // Checkpoint revision: the diet-plan card's own independently-loaded display value -- read
    // directly, not derived from `DietPlanSectionContent`'s private internal `@State`, since that
    // view's selection is intentionally not exposed upward (D-08's "no aggregate state" rule).
    // Reloaded on the quick-edit sheet's dismissal (`reloadDietaryPatternSummary` below), since
    // this view's own `onAppear` does not re-fire just because a child sheet closed.
    @State private var dietaryPatternSummary: DietaryPattern?

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
                //
                // Checkpoint revision: Momentum and sleep sit in a two-column grid row instead of
                // two full-width stacked cards -- the first break from a pure vertical stack, per
                // direct feedback that everything one-after-another did not read as a dashboard.
                HStack(alignment: .top, spacing: RithamSpacing.md) {
                    tile { momentumSection }
                    tile { sleepSection }
                }
                sectionCard { exerciseSection }
                tapToOpenCard(action: { isPresentingWorkoutPlan = true }) { workoutPlanSummary }
                tapToOpenCard(action: { isPresentingDietPlan = true }) { dietPlanSummary }
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

            reloadDietaryPatternSummary()
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
        .sheet(isPresented: $isPresentingWorkoutPlan) {
            if let recommendationsModel {
                RecommendationsQuickView(model: recommendationsModel, flow: flow)
            }
        }
        .sheet(isPresented: $isPresentingDietPlan, onDismiss: reloadDietaryPatternSummary) {
            DietPlanQuickEditView(flow: flow)
        }
    }

    /// Re-reads the stored dietary pattern for the diet-plan card's own display value. Called from
    /// `onAppear` and from the diet quick-edit sheet's `onDismiss`, since a value changed inside
    /// that sheet is not otherwise visible to this view -- `DietPatternPicker`'s selection is
    /// private `@State`, not shared state (D-08).
    private func reloadDietaryPatternSummary() {
        let store = HealthDataStore(context: modelContext)
        dietaryPatternSummary = (try? store.loadProfile())?.dietaryPattern
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
                // Checkpoint revision: a leading SF Symbol per row, matching the icon-plus-row
                // shape of Apple Fitness's own workout history list -- the one part of "Apple's
                // model" available here, since a data-bearing ring/arc is permanently off-limits
                // for this screen (04-UI-SPEC.md's Ring Collision rule, carried from Phase 3).
                // Neutral `paper` tint only, never the accent color: `RithamColor.hot` is reserved
                // for CTA fills/progress blocks/shield glyphs and must never read as a status
                // badge or completion indicator on this row.
                HStack(alignment: .top, spacing: RithamSpacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(RithamColor.paper.opacity(0.6))
                        .accessibilityHidden(true)

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

    // D-04 (checkpoint-revised 2026-09-08): a compact, tap-to-open summary card rather than an
    // inline embed of `RecommendationsSectionContent` -- direct human-checkpoint feedback that
    // diet and workout plan should open only on tap, not sit permanently expanded on the
    // dashboard. `recommendationsWorkoutPlanStatus` below is the card's own real content (never
    // just a heading plus a bare button, per the discriminator rule) -- it reflects
    // `recommendationsModel.state` exactly, so the summary line is never stale relative to
    // whatever `RecommendationsQuickView`'s sheet is showing. Deliberately never calls
    // `requestPlan` from this view's `onAppear` or from any other lifecycle hook --
    // `RecommendationsModel.requestPlan` opens `.preAssessment` when the pre-assessment flag is
    // false, so an auto-request would push the pre-assessment screen on top of home with no user
    // action on a cold launch, and would hit the Go plan service on every launch.
    @ViewBuilder
    private var workoutPlanSummary: some View {
        Text(HomeHubView.workoutPlanSectionHeading)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        Text(recommendationsWorkoutPlanStatus)
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
    }

    /// A one-line status derived entirely from `recommendationsModel.state` -- no new state of
    /// its own, so it can never drift out of sync with the sheet showing the same model.
    private var recommendationsWorkoutPlanStatus: String {
        switch recommendationsModel?.state {
        case .none, .idle:
            return HomeHubView.workoutPlanIdleStatus
        case .loading:
            return HomeHubView.workoutPlanLoadingStatus
        case .plan(let plan):
            return "\(plan.sessions.count) session\(plan.sessions.count == 1 ? "" : "s") ready"
        case .error:
            return HomeHubView.workoutPlanErrorStatus
        }
    }

    // D-05 (narrowed per 04-RESEARCH.md Pitfall 3, then checkpoint-revised 2026-09-08 to
    // tap-to-open): a compact summary card showing the currently saved dietary pattern, never the
    // full `DietPlanSectionContent` inline. Tapping opens `DietPlanQuickEditView` (a sheet hosting
    // only the DIET-01-isolated pickers) -- Pitfall 3's isolation still holds: the food-allergy
    // screening checkbox and its severity follow-up, which call `GateResolution.resolve`/
    // `saveScreeningResult` against `flow.answers.screening` (empty on every fresh app launch),
    // stay reachable only through the Settings-presented `DietPlanView` (this file's `SettingsView`
    // sheet below) -- neither this summary nor the quick-edit sheet it opens ever constructs that
    // screen or duplicates its screening-write path.
    @ViewBuilder
    private var dietPlanSummary: some View {
        Text(HomeHubView.dietPlanSectionHeading)
            .font(RithamType.heading)
            .foregroundStyle(RithamColor.paper)

        Text(dietPlanStatus)
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
    }

    private var dietPlanStatus: String {
        switch dietaryPatternSummary {
        case .none, .some(.none):
            return HomeHubView.dietPlanUnsetStatus
        case .some(.vegetarian):
            return OnboardingCopy.Diet.optionVegetarian
        case .some(.vegan):
            return OnboardingCopy.Diet.optionVegan
        }
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

    // Checkpoint revision: the same Dashboard Section Card treatment as `sectionCard`, but
    // constrained to half the row's width for the Momentum/sleep grid row -- identical fill,
    // radius and padding, only the width behavior differs (`maxWidth: .infinity` inside an
    // `HStack` divides the row evenly between the two tiles rather than each claiming the full
    // screen width).
    @ViewBuilder
    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            content()
        }
        .padding(RithamSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RithamColor.paper.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }

    // Checkpoint revision: the tap-to-open variant of `sectionCard` for the workout-plan and
    // diet-plan summaries -- same fill/radius/padding, wrapped in a `Button` so the whole card is
    // one accessible tap target (VoiceOver reads the heading and status line, then announces the
    // button trait) rather than requiring a separate small control inside the card. A trailing
    // chevron is the only new visual element: a plain SF Symbol glyph, not a ring/arc/radial form,
    // so it does not trip the Ring Collision rule, and it is tinted at the same neutral
    // `paper.opacity` as the exercise section's row icons -- never the accent color, which stays
    // reserved for CTA fills/progress blocks/shield glyphs only.
    @ViewBuilder
    private func tapToOpenCard<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: RithamSpacing.sm) {
                VStack(alignment: .leading, spacing: RithamSpacing.md) {
                    content()
                }
                Spacer(minLength: RithamSpacing.sm)
                Image(systemName: "chevron.right")
                    .foregroundStyle(RithamColor.paper.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(RithamSpacing.md)
            .frame(maxWidth: .infinity, minHeight: RithamSpacing.minimumTapTarget, alignment: .leading)
            .background(RithamColor.paper.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
        .buttonStyle(.plain)
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
