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
/// revision.
///
/// **Checkpoint revision (2026-09-08, second round):** direct feedback that the result still read
/// as "a bunch of boxes with text in it" reshaped the layout again. Momentum and Exercise are the
/// two full-width cards with real content (progress blocks/streak/shields, and the session list).
/// Every section heading also carries a leading `SectionIconBadge` for visual identity, and
/// `MomentumDashboardSection`'s streak line was promoted to `RithamType.display`, making the
/// dashboard's core mechanic its clear focal point rather than one box among equals.
///
/// **Checkpoint revision (2026-09-08, third round):** direct feedback that a vertical grouped list
/// still read as "one after the other... boring," explicitly asking for "a sliding dashboard,
/// something interesting," led to a horizontally swiped `TabView` page carousel for Sleep/Workout
/// plan/Diet plan. **Superseded the same day (fourth round):** direct follow-up feedback rejected
/// the swipe outright ("I don't wanna see them horizontally. No.") and restated the real, constant
/// complaint across every round -- too much text, too boxy. The exercise section's session rows
/// gained a cardio-vs-strength `SectionIconBadge` "doodle" per row in this same round, replacing
/// the earlier bare checkmark glyph, and that change survived into the current layout below.
///
/// **Checkpoint revision (2026-09-08, fifth round):** a design panel (three independent proposals,
/// judged on visual craft/constraint compliance/fit to the actual repeated feedback, then
/// synthesized) diagnosed the real pattern: every prior round changed the CONTAINER shape (stack,
/// grid, tap-card, hero card, carousel) while every container kept the identical
/// `paper.opacity(0.06)` fill + hairline stroke + `RoundedRectangle` shell around the trio's
/// content. Changing container shape without changing that shell was never going to stop reading
/// as "boxes with text." Sleep, Workout plan and Diet plan now render with NO card shell at all --
/// a static, non-scrolling row of three icon-first tiles (`iconTile`), each just a large
/// `SectionIconBadge` over a short heading, tap affordance carried by icon+label grouping alone
/// (the same convention as iOS's own Control Center). The workout tile additionally reuses
/// `MomentumDashboardSection`'s own "streak as `RithamType.display` numeral" device for its
/// session count when a plan is ready, rather than a text line -- the graft the judge panel
/// specifically flagged as the strongest available reinforcement, adding a positive graphic device
/// rather than relying on restraint alone.
///
/// **Checkpoint revision (2026-09-09, sixth round):** direct feedback praised the icon-strip's
/// shell-less treatment specifically ("like how we used the rules to align them") and extended the
/// same "too much boxes and text" complaint to the rest of the page ("even history or cardio
/// track... too much of boxes and text... everything else in that page is just empty, and this is
/// all just a bunch of words clump together"). Momentum and Exercise dropped the `sectionCard`
/// shell that survived the fifth round unchanged -- the whole dashboard is now shell-less
/// throughout, sections separated by whitespace (`RithamSpacing.lg` between top-level groups) and
/// their own icon+heading, never a card boundary. The exercise section's four logging buttons also
/// moved from four stacked full-width rows to a 2x2 grid in this same round, addressing a separate
/// "This week's activity... a little too big" comment -- same entry points, same D-07
/// reachability, roughly half the height. A tangential concern about manual cardio/strength
/// logging requiring users to "practically go and stop it" themselves, versus device-automatic
/// tracking, was raised in the same feedback round but is **out of scope for this phase** -- it is
/// the same class of new data-ingestion scope D-08 already deferred (steps/calories: "needs its
/// own scoping decision... before it can be planned"), not a layout change, and needs a dedicated
/// discussion, not a guess folded into this round's visual pass.
///
/// **Checkpoint revision (2026-09-09, seventh round):** the decorative band header (previously
/// `.boundedHeaderOnly`) is gone -- direct feedback that it wasted vertical space real content
/// could use ("I don't think we need to have the stripes for the home page... use the whole page
/// just for these things"). `RithamScreen(surface: DecorativeSurface.flat, ...)` is the same
/// already-reviewed "no decorative header" case eight other screens already use; `ScreenHeader`
/// collapses to zero height rather than reserving a ~250pt band for nothing, so the headline and
/// every section below it now start right at the top margin. This also drops the small
/// ring-and-dot corner ornament (`.flat` turns off all four `DecorativeSurface` flags together --
/// see 04-UI-SPEC.md's dated revision for why no narrower "band off, ring on" surface exists). In
/// the same round, "add some color to some of the features" narrowly extended the accent-color
/// reservation to one more place: the workout icon-strip tile's ready-state session-count numeral
/// now renders in `RithamColor.hot` rather than `paper` -- the same "coral marks something
/// earned/real" language `MomentumProgressBlocks`/`ShieldRow` already use, not a general loosening
/// (see `workoutPlanSummary`'s own comment, and 04-UI-SPEC.md's dated revision).
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

    // Fifth-round icon-tile copy: short, on-screen-only compressions of the three strings above.
    // VoiceOver still speaks the full, unabbreviated strings (`recommendationsWorkoutPlanStatus`),
    // set as the tile's own `accessibilityLabel` -- these three exist only for the glyph-sized
    // on-screen text and must never replace the originals, which continue to feed accessibility.
    nonisolated static let workoutPlanTileIdleStatus = "Get plan"
    nonisolated static let workoutPlanTileLoadingStatus = "Building…"
    nonisolated static let workoutPlanTileErrorStatus = "Couldn't load"

    // Phase 4.1 Plan 05's social entry point (ACCOUNT-01): the section heading and its signed-out
    // CTA. Not `SocialCopy.SignInWithApple.headline` for the CTA label itself -- that string is a
    // full sentence ("Sign in to connect with friends") meant as the sign-in screen's own headline,
    // not a compact button label; this shorter action-oriented string is planner-authored purely
    // for the button, matching this file's own stated rule that section-heading-adjacent strings
    // here are visual-grouping copy, not verbatim-shipped-strings-table entries.
    nonisolated static let socialSectionHeading = "Friends and groups"
    nonisolated static let socialSignInCTA = "Sign in with Apple"

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

    // Phase 4.1 Plan 05's social entry point state: whether a Sign in with Apple session exists on
    // this device, and the display name to show when one does. `nil` means signed out -- read
    // directly from `SessionStore` (Keychain-backed, not cached in memory by that type itself) in
    // `reloadSocialSession()` below, the same independently-loaded-per-section pattern
    // `dietaryPatternSummary`/`momentumSummary` above already use, never a hub-owned aggregate
    // model (D-08's "no dashboard-specific aggregate view model" rule).
    @State private var socialDisplayName: String?

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: HomeHubView.dashboardHeadline
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.lg) {
                // D-08 / Ring Collision rule (03-UI-SPEC.md Component 1, restated by 04-UI-SPEC.md):
                // no section body below may introduce a second ring, arc, or radial motif. This
                // rule constrains section content regardless of which header surface is in use --
                // it stays in force even now that `.flat` (above) means there is no header ring to
                // collide with in the first place (seventh-round revision, this file's own header
                // comment).
                //
                // Checkpoint revision (2026-09-09, sixth round): Momentum and Exercise dropped
                // their `sectionCard` shell (fill + stroke + rounded rect) -- direct follow-up
                // feedback praised the icon-strip's shell-less treatment specifically ("like how we
                // used the rules to align them") and restated the boxes/text complaint against the
                // rest of the page ("even history or cardio track... too much of boxes and text...
                // everything else in that page is just empty, and this is all just a bunch of words
                // clump together"). The whole dashboard is now shell-less throughout -- every
                // section separated by whitespace and its own icon+heading, never a card boundary --
                // which is why the outer spacing here moved from `RithamSpacing.md` to `.lg`: with
                // no card edge doing the separating anymore, spacing has to carry that job alone.
                VStack(alignment: .leading, spacing: RithamSpacing.md) { momentumSection }
                VStack(alignment: .leading, spacing: RithamSpacing.md) { exerciseSection }

                // Checkpoint revision (2026-09-08, fifth round): a static, non-scrolling row of
                // three icon-first tiles -- no card shell of any kind (no fill, no stroke, no
                // RoundedRectangle) around the row or any individual tile. Direct feedback rejected
                // every prior container shape for this trio (stack, grid, tap-card, carousel); the
                // design-panel synthesis this round diagnosed that the shell itself, not the
                // container shape, was what kept reading as "boxes with text." Tap affordance comes
                // from icon+label grouping alone (the same convention iOS's own Control Center
                // uses), plus each tile's own `Button`/VoiceOver trait -- see `iconTile`'s own
                // comment. No fixed height anywhere: each column sizes to its own content, so
                // Sleep's shorter column (heading only, per RECOVERY-01 invariant 3 below) simply
                // ends higher than its neighbors -- deliberate, honest asymmetry, not a forced
                // empty placeholder to fake-match height.
                HStack(alignment: .top, spacing: RithamSpacing.sm) {
                    iconTile(
                        icon: "moon.stars.fill",
                        accessibilityLabel: MomentumCopy.Sleep.headline,
                        action: { flow.open(.sleepCheckIn) }
                    ) { sleepSection }

                    iconTile(
                        icon: workoutPlanTileIcon,
                        accessibilityLabel: "\(HomeHubView.workoutPlanSectionHeading). \(recommendationsWorkoutPlanStatus)",
                        action: { isPresentingWorkoutPlan = true }
                    ) { workoutPlanSummary }

                    iconTile(
                        icon: dietPlanTileIcon,
                        accessibilityLabel: "\(HomeHubView.dietPlanSectionHeading). \(dietPlanStatus)",
                        action: { isPresentingDietPlan = true }
                    ) { dietPlanSummary }
                }

                // Phase 4.1 Plan 05's social entry point: a fourth full-width, shell-less section
                // matching Momentum/Exercise's own icon+heading shape exactly (never the icon-tile
                // trio's compact form -- this section's content differs in kind by session state,
                // which the smaller tile shape has no room for). The dashboard gains this one entry
                // point and loses none of its existing sections (this plan's own must_haves truth).
                VStack(alignment: .leading, spacing: RithamSpacing.md) { socialSection }

                overflowRow
            }
        }
        .onAppear {
            reloadSocialSession()
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

    /// Re-reads whether a Sign in with Apple session exists, and its display name. Called from
    /// `onAppear` -- which SwiftUI re-fires when a pushed step (`.signInWithApple`) is popped back
    /// to this screen, exactly like every other push/pop transition in this app's one
    /// `NavigationStack` -- so a session established on that screen shows up here without a second,
    /// bespoke refresh mechanism.
    private func reloadSocialSession() {
        let sessionStore = SessionStore()
        socialDisplayName = sessionStore.isSignedIn ? sessionStore.displayName : nil
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
    //
    // Checkpoint revision (2026-09-08, second round): the standalone `SecondaryCTAButton` is gone
    // -- this content now renders inside `iconTile`, whose own `Button` is the tap target
    // (`flow.open(.sleepCheckIn)`, unchanged) rather than a button nested inside another button.
    // D-03's entry point is unchanged; only its container changed, the same inline-embed-to-
    // tap-to-open evolution D-04/D-05 already went through this same checkpoint. No status line
    // below the heading, ever -- not a design choice this round, the same absolute RECOVERY-01
    // invariant 3 the comment above already states.
    @ViewBuilder
    private var sleepSection: some View {
        Text(MomentumCopy.Sleep.headline)
            .font(RithamType.body.weight(.semibold))
            .foregroundStyle(RithamColor.paper)
            .multilineTextAlignment(.center)
            .lineLimit(2)
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
        HStack(spacing: RithamSpacing.sm) {
            SectionIconBadge(systemName: "figure.run")
            Text(HomeHubView.exerciseSectionHeading)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)
        }

        if let summary = momentumSummary, !summary.recentSessions.isEmpty {
            ForEach(summary.recentSessions) { session in
                // Checkpoint revision (2026-09-08, third round): a small `SectionIconBadge`
                // "doodle" per row, distinguishing cardio from strength -- direct feedback asked
                // for "a small doodle of that exercise" rather than a bare checkmark. Distinguishes
                // by `verificationLabel != nil`, not a new field: this file's own header comment
                // documents that a cardio entry always carries a verification label and a lift
                // entry never does (`LiftSessionRecord` has no capture-source field at all), so this
                // reads an existing, already-relied-upon invariant rather than adding one. Matches
                // the icon-plus-row shape of Apple Fitness's own workout history list -- the one
                // part of "Apple's model" available here, since a data-bearing ring/arc is
                // permanently off-limits for this screen (04-UI-SPEC.md's Ring Collision rule).
                HStack(alignment: .top, spacing: RithamSpacing.sm) {
                    SectionIconBadge(
                        systemName: session.verificationLabel != nil ? "figure.run" : "dumbbell.fill",
                        diameter: 28
                    )

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

        // Checkpoint revision (2026-09-09, sixth round): the four logging entry points moved from
        // four stacked full-width rows to a 2x2 grid -- direct feedback that this card felt "too
        // big" with "a lot of context, with the words." Same four entry points, same D-07
        // reachability, same button components/titles -- only the arrangement changed, which cuts
        // this block's height roughly in half. Column position pairs each primary action with its
        // own history directly beneath it (Track cardio above Cardio history, Log strength above
        // Strength history), so the pairing reads from layout alone without new copy.
        HStack(spacing: RithamSpacing.sm) {
            PrimaryCTAButton(title: "Track cardio") {
                flow.open(.cardioActivityPicker)
            }
            PrimaryCTAButton(title: "Log strength") {
                flow.open(.strengthSession)
            }
        }
        HStack(spacing: RithamSpacing.sm) {
            SecondaryCTAButton(title: "Cardio history") {
                flow.open(.cardioHistory)
            }
            SecondaryCTAButton(title: "Strength history") {
                flow.open(.strengthHistory)
            }
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
            .font(RithamType.body.weight(.semibold))
            .foregroundStyle(RithamColor.paper)
            .multilineTextAlignment(.center)
            .lineLimit(2)

        // Fifth-round graft from the design panel's runner-up proposal: when a plan is ready, the
        // session count renders as a `RithamType.display` numeral -- the exact device
        // `MomentumDashboardSection` already established for its own streak line -- instead of a
        // text line, so this tile carries a genuine graphic device rather than relying on icon +
        // restraint alone. Every other state falls back to the short `workoutPlanTileStatusText`.
        // Colored `RithamColor.hot`, not `paper`, as of the seventh-round checkpoint revision
        // ("add some color to some of the features") -- a narrow, dated extension of the accent
        // reservation to this one number, matching the "coral marks something earned/real"
        // language `MomentumProgressBlocks`/`ShieldRow` already establish (04-UI-SPEC.md's own
        // dated revision). Still never a badge/dot/status indicator: every other glyph on this
        // tile, and on the Sleep/Diet tiles beside it, stays neutral `paper`.
        if case .plan(let plan) = recommendationsModel?.state {
            VStack(spacing: RithamSpacing.xs) {
                Text("\(plan.sessions.count)")
                    .font(RithamType.display)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.hot)
                Text(plan.sessions.count == 1 ? "session" : "sessions")
                    .font(RithamType.label)
                    .modifier(RithamType.fineprint())
            }
        } else {
            Text(workoutPlanTileStatusText)
                .font(RithamType.label)
                .modifier(RithamType.fineprint())
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    /// A one-line status derived entirely from `recommendationsModel.state` -- no new state of
    /// its own, so it can never drift out of sync with the sheet showing the same model. Feeds
    /// `iconTile`'s `accessibilityLabel` directly, so VoiceOver always hears this full phrasing
    /// even where the on-screen tile shows a shorter string or the numeral device instead.
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

    /// The tile's own compact on-screen text for every state except `.plan`, which
    /// `workoutPlanSummary` renders as the numeral device above instead -- this switch stays
    /// exhaustive (including a `.plan` case) for compiler safety, but that branch is unreachable in
    /// practice since the `@ViewBuilder` `if case .plan` above always wins first.
    private var workoutPlanTileStatusText: String {
        switch recommendationsModel?.state {
        case .none, .idle:
            return HomeHubView.workoutPlanTileIdleStatus
        case .loading:
            return HomeHubView.workoutPlanTileLoadingStatus
        case .plan:
            return ""
        case .error:
            return HomeHubView.workoutPlanTileErrorStatus
        }
    }

    /// The workout tile's icon glyph, state-derived: outline means nothing yet, filled means real
    /// content exists -- a consistent grammar carried through to `dietPlanTileIcon` below. Legible
    /// before any text is read, so it doubles as a second, faster status signal.
    private var workoutPlanTileIcon: String {
        switch recommendationsModel?.state {
        case .none, .idle:
            return "dumbbell"
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .plan:
            return "dumbbell.fill"
        case .error:
            return "exclamationmark.triangle.fill"
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
            .font(RithamType.body.weight(.semibold))
            .foregroundStyle(RithamColor.paper)
            .multilineTextAlignment(.center)
            .lineLimit(2)

        Text(dietPlanStatus)
            .font(RithamType.label)
            .modifier(RithamType.fineprint())
            .multilineTextAlignment(.center)
            .lineLimit(2)
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

    /// The diet tile's icon glyph, state-derived -- same outline/filled grammar as
    /// `workoutPlanTileIcon`: unset is the neutral "nothing chosen yet" glyph, a saved pattern
    /// switches to a filled or half-filled leaf depending on which pattern.
    private var dietPlanTileIcon: String {
        switch dietaryPatternSummary {
        case .none, .some(.none):
            return "fork.knife"
        case .some(.vegetarian):
            return "leaf"
        case .some(.vegan):
            return "leaf.fill"
        }
    }

    // D-07: Guidance and Settings, reduced to a single compact overflow row rather than the two
    // full-width `PrimaryCTAButton`/`SecondaryCTAButton` rows the old hub used -- a leftover
    // button stack under real sections is the same rejected pattern with extra steps
    // (04-UI-SPEC.md section 6). Not wrapped in `sectionCard`: this is an overflow affordance, not
    // a content section. Checkpoint revision (2026-09-08, second round): a small leading SF Symbol
    // per label, matching the icon-led language the rest of the dashboard now uses, instead of
    // two bare text buttons floating with nothing to anchor them visually.
    private var overflowRow: some View {
        HStack(spacing: RithamSpacing.lg) {
            Button {
                flow.open(.guidance)
            } label: {
                Label("Guidance", systemImage: "questionmark.circle")
            }
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .accessibilityLabel("Guidance")

            Button {
                isPresentingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .accessibilityLabel("Settings")
        }
    }

    // Checkpoint revision (2026-09-08, fifth round): one tile inside the Sleep/Workout-plan/
    // Diet-plan icon-strip row -- a large `SectionIconBadge` over the tile's own content (a
    // heading, optionally a one-line status or the workout numeral device). Deliberately NO card
    // shell -- no fill, no stroke, no `RoundedRectangle` -- unlike every other section on this
    // screen: the design-panel synthesis this round's feedback triggered diagnosed that shell as
    // the actual, unchanging source of "boxes with text" across every prior container shape tried.
    // Tap affordance is carried by icon+label grouping alone (the same convention iOS's own
    // Control Center uses for its own icon tiles) plus the `Button`/VoiceOver trait -- no chevron,
    // no border, no other "this is tappable" hint. `accessibilityElement(children: .combine)` +
    // an explicit `accessibilityLabel` make VoiceOver announce the tile's full, unabbreviated
    // status (from `recommendationsWorkoutPlanStatus`/`dietPlanStatus`) even on tiles whose
    // on-screen text is compressed or replaced by the numeral device. No fixed frame height: each
    // tile sizes to its own content, so Sleep's shorter content (heading only) simply ends higher
    // than its neighbors rather than being padded to fake-match them.
    @ViewBuilder
    private func iconTile<Content: View>(
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(spacing: RithamSpacing.xs) {
                SectionIconBadge(systemName: icon, diameter: RithamSpacing.minimumTapTarget)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: RithamSpacing.minimumTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // ACCOUNT-01's opt-in social entry point. Reachable only by explicit choice, here, never during
    // onboarding and never on the path to core tracking (T-04.1-28) -- signed-out state shows the
    // opt-in framing and a CTA into `.signInWithApple`; signed-in state shows only the stored
    // display name, nothing more. This section's own destinations -- the friends list and the
    // groups list -- are not yet attached: they arrive in plans 04.1-09 and 04.1-11, at which point
    // a signed-in tap here should route to one of them rather than doing nothing. Recorded here as
    // an explicit forward handoff for those plans, not an unstated gap.
    @ViewBuilder
    private var socialSection: some View {
        HStack(spacing: RithamSpacing.sm) {
            SectionIconBadge(systemName: "person.2.fill")
            Text(HomeHubView.socialSectionHeading)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)
        }

        if let socialDisplayName {
            Text(socialDisplayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
        } else {
            Text(SocialCopy.SignInWithApple.body)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryCTAButton(title: HomeHubView.socialSignInCTA) {
                flow.open(.signInWithApple)
            }
        }
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
    /// is a direct call inside this file's `body`, so neither is listed here. `.signInWithApple`
    /// (plan 04.1-05) follows `.movementSnapshot`'s own precedent: `socialSection`'s CTA only calls
    /// `flow.open(.signInWithApple)` in the signed-out branch, so `isSignedIn` gates its presence
    /// here the same way `movementSnapshotOptIn` gates `.movementSnapshot` above -- defaulted to
    /// `false` so every pre-existing call site (none of which is signed in) is unaffected.
    nonisolated static func routingSteps(movementSnapshotOptIn: Bool, isSignedIn: Bool = false) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .sleepCheckIn, .cardioActivityPicker, .cardioHistory,
            .strengthSession, .strengthHistory, .guidance,
        ]
        if !isSignedIn {
            steps.append(.signInWithApple)
        }
        if showsMovementSnapshotEntry(optIn: movementSnapshotOptIn) {
            steps.append(.movementSnapshot)
        }
        return steps
    }
}
