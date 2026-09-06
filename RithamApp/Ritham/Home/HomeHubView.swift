import SwiftUI
import RithamCore

/// D-05's deliberately interim hub -- not CROSSGEN-01's polished three-item home (Phase 4's
/// scope), just enough real navigation for Phase 2's own features to be reachable and testable
/// in the running app. `.boundedHeaderOnly` fits this screen's own naming rationale (a bounded
/// header band, used by screens that explain or introduce something without collecting,
/// confirming, or blocking on health or age data themselves): this hub collects nothing, it only
/// routes.
///
/// Navigates to every pushed destination through `flow.open(_:)`, never a second navigation
/// container -- CROSSGEN-05 reserves the app's one navigation container for `OnboardingRootView`.
/// Settings (and the health profile it can open) are sheets, exactly as `SettingsView` itself
/// already uses sheets for its own sub-screens, never pushes.
///
/// Nothing in app code constructs `SettingsView` before this view -- presenting it here is what
/// finally makes it, and therefore `DietPlanView` (DIET-01, already built), reachable in the
/// running app for the first time.
struct HomeHubView: View {
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

    // MOMENTUM-07/D-09's opt-in-gated entry state: loaded alongside `momentumSummary` in this
    // view's one existing appearance handler below (never a second one). Off by default
    // (`HealthDataStore.loadMovementSnapshotOptIn`'s own default), which is what makes the CTA
    // below render nothing at all until the user opts in from Settings.
    @State private var isMovementSnapshotEnabled = false

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: "Your interim home",
            bodyText: "This is a temporary hub so Phase 2's tracking and guidance features are reachable now. A polished home screen arrives later."
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                // D-08: the hub's own decorative surface (`.boundedHeaderOnly` above) stays
                // exactly as it is -- this section renders in the scrollable content area below
                // the header, never inside the header region itself, so the hub's existing
                // header ornament and this section's own progress-block strip never share one
                // viewport (03-UI-SPEC.md Component 1's own "two circular motifs" rationale).
                momentumSection

                // RECOVERY-01's daily sleep check-in entry point. Deliberately placed here, on
                // the hub, rather than inside `momentumSection` or on `MomentumView`: invariant 7
                // requires the sleep and Momentum systems to share zero UI surface beyond the
                // single plan-level banner (Component 7), and D-03 requires the three self-report
                // machines (sleep check-in, Recovery Week, injury freeze) to stay structurally
                // independent. The label is a plain string constant -- never derived from
                // whether a check-in exists for today -- so a skipped check-in is indistinguishable,
                // app-wide, from a day the prompt was never shown (invariant 3): no badge, no dot,
                // no completed state of any kind.
                SecondaryCTAButton(title: MomentumCopy.Sleep.headline) {
                    flow.open(.sleepCheckIn)
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
                PrimaryCTAButton(title: "Guidance") {
                    flow.open(.guidance)
                }
                PrimaryCTAButton(title: "Recommendations") {
                    flow.open(.recommendations)
                }

                // MOMENTUM-07/D-09: the Daily Movement Snapshot's opt-in-gated hub entry.
                // Deliberately placed here, below the tracking entries and below
                // `momentumSection` (never inside it, never rendered adjacent to it as a group)
                // -- the snapshot is the deliberately quiet counterpart to Momentum and must
                // carry no streak, shield or target association, including by mere adjacency.
                // When the opt-in is off, this renders nothing at all: no disabled row, no
                // greyed entry, no "turn this on" prompt -- an off opt-in is indistinguishable
                // from the feature not existing.
                if HomeHubView.showsMovementSnapshotEntry(optIn: isMovementSnapshotEnabled) {
                    SecondaryCTAButton(title: "Daily Movement Snapshot") {
                        flow.open(.movementSnapshot)
                    }
                }

                SecondaryCTAButton(title: "Settings") {
                    isPresentingSettings = true
                }
            }
        }
        .onAppear {
            let store = HealthDataStore(context: modelContext)
            let reader = MomentumSummaryReader(store: store, calendar: .current)
            momentumSummary = try? reader.summary(now: Date())
            isMovementSnapshotEnabled = (try? store.loadMovementSnapshotOptIn()) ?? false
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

    // MARK: - D-08's Momentum summary section
    //
    // Renders this week's progress, the streak, and the shield count -- MOMENTUM-06 requires zero
    // share/export/invite affordance anywhere on this section (no `ShareLink`,
    // `UIActivityViewController`, or copy-link control appears here or anywhere else in this
    // file). Deliberately no sleep-check-in state indicator, badge, dot, or "you haven't checked
    // in" prompt of any kind: RECOVERY-01 invariant 3 requires a skipped check-in to be
    // indistinguishable, app-wide, from a day the prompt was never shown -- do not reintroduce one
    // here as a helpful nudge.
    @ViewBuilder
    private var momentumSection: some View {
        if let summary = momentumSummary {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                MomentumProgressBlocks(filled: summary.displayedCount, target: summary.weeklyTarget)

                Text(MomentumView.streakLine(for: summary))
                    .font(RithamType.heading)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)

                ShieldRow(earned: summary.shieldCount, maximum: MomentumLedger.maxShields)

                if summary.recentSessions.isEmpty {
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

                PrimaryCTAButton(title: "Momentum") {
                    flow.open(.momentum)
                }
            }
        }
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
    /// presence/absence without rendering this view.
    nonisolated static func routingSteps(movementSnapshotOptIn: Bool) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .sleepCheckIn, .cardioActivityPicker, .cardioHistory,
            .strengthSession, .strengthHistory, .guidance, .recommendations,
        ]
        if showsMovementSnapshotEntry(optIn: movementSnapshotOptIn) {
            steps.append(.movementSnapshot)
        }
        return steps
    }
}
