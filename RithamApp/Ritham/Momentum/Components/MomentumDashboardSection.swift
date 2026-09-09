import SwiftUI
import RithamCore

/// The Momentum summary section, re-parented out of `HomeHubView`'s old `momentumSection` member
/// verbatim (D-06: "re-parented, not rebuilt -- it is proven, tested, reconciliation-on-read
/// code"). No logic differs from the original member; only the hosting file/type changed.
///
/// Placed here, under `Ritham/Momentum/Components/` rather than `Ritham/Home/`, specifically so
/// `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`'s directory-walk gate (which
/// scans `Ritham/Momentum/` and `Ritham/MovementSnapshot/` for `ShareLink`,
/// `UIActivityViewController`, and `UIPasteboard`) automatically covers this section's source with
/// zero test-file edits, closing a pre-existing gap: `Ritham/Home/` was never inside that walk
/// even though this section has rendered there since Phase 3 (04-RESEARCH.md Pitfall 2).
///
/// MOMENTUM-06 requires zero share/export/invite affordance anywhere on this section -- no
/// `ShareLink`, `UIActivityViewController`, or copy-link control appears here or anywhere else in
/// this file. Deliberately no sleep-check-in state indicator, badge, dot, or "you haven't checked
/// in" prompt of any kind: RECOVERY-01 invariant 3 requires a skipped check-in to be
/// indistinguishable, app-wide, from a day the prompt was never shown -- do not reintroduce one
/// here as a helpful nudge.
///
/// `HomeHubView` still owns and passes `summary`/`loadFailed` down as parameters (D-08's own
/// requirement, restated in 04-CONTEXT.md's canonical refs: "not baked into a hub-specific view
/// model") -- this type loads no state of its own.
///
/// Deviation from the plan 04-02 Task 1 verbatim extraction: the original `momentumSection`'s
/// no-sessions empty-state block (shown when `summary.recentSessions.isEmpty`) moved here
/// unchanged in Task 1's zero-behaviour-change move, then was deleted in Task 2 and relocated to
/// `HomeHubView.exerciseSection` -- 04-UI-SPEC.md section 3 assigns that empty state to the
/// exercise card, not this one, so it now exists in exactly one place.
///
/// Checkpoint revision (2026-09-08): given a leading `SectionIconBadge` and its own "Momentum"
/// heading, and the streak line promoted from `RithamType.heading` to `RithamType.display` -- the
/// same four-role type scale, just its largest role, per direct feedback that the dashboard read
/// as "a bunch of boxes with text in it" with no clear focal point. This is the one card built
/// entirely from proven Phase 3 mechanics (progress blocks, streak, shields), so it is the
/// dashboard's own hero card: full-width in `HomeHubView.body`, not a half-width grid tile.
struct MomentumDashboardSection: View {
    let summary: MomentumSummary?
    let loadFailed: Bool
    let flow: OnboardingFlow

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                HStack(spacing: RithamSpacing.sm) {
                    SectionIconBadge(systemName: "flame.fill")
                    Text("Momentum")
                        .font(RithamType.heading)
                        .foregroundStyle(RithamColor.paper)
                }

                MomentumProgressBlocks(filled: summary.displayedCount, target: summary.weeklyTarget)

                Text(MomentumView.streakLine(for: summary))
                    .font(RithamType.display)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)

                ShieldRow(earned: summary.shieldCount, maximum: MomentumLedger.maxShields)

                PrimaryCTAButton(title: "Momentum") {
                    flow.open(.momentum)
                }
            }
        } else if loadFailed {
            // WR-03: reuses `OnboardingCopy.Errors.savingFailed` verbatim, exactly as
            // `MomentumView`/`RecommendationsView` already do for a Momentum/Recovery read
            // failure, rather than silently rendering nothing.
            Text(OnboardingCopy.Errors.savingFailed)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
