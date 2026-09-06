import SwiftUI
import RithamCore

// MOMENTUM-05's milestone badge list: one row per tier in `MomentumMilestone.tiers`. No bespoke
// celebration animation, no confetti, no full-screen takeover on a milestone being newly reached
// -- a row simply renders as "earned" the next time the screen appears, the same
// reconciliation-on-read discipline `ShieldRow` follows.
struct MilestoneBadgeList: View {
    let awarded: [MilestoneAward]

    private var awardedWeekCounts: Set<Int> {
        Set(awarded.map(\.weekCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            ForEach(MomentumMilestone.tiers, id: \.self) { tier in
                row(forTier: tier, isEarned: awardedWeekCounts.contains(tier))
            }
        }
    }

    @ViewBuilder
    private func row(forTier tier: Int, isEarned: Bool) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            // A rosette vs. a dashed circle is a shape difference, not color alone, matching the
            // same WCAG 1.4.1 discipline `ShieldRow` and `MomentumProgressBlocks` use.
            Image(systemName: isEarned ? "rosette" : "circle.dashed")
                .foregroundStyle(isEarned ? RithamColor.hot : RithamColor.paper.opacity(0.2))

            VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                Text("\(tier)")
                    .font(RithamType.heading)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)

                if let line = MomentumCopy.Milestones.line(forWeekCount: tier) {
                    Text(line)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                }
            }
        }
    }
}
