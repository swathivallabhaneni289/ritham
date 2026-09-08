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
struct MomentumDashboardSection: View {
    let summary: MomentumSummary?
    let loadFailed: Bool
    let flow: OnboardingFlow

    var body: some View {
        if let summary {
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
