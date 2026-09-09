import SwiftUI

/// A small neutral rounded-square glyph badge used as a leading identity mark next to a dashboard
/// section's heading (`Home/HomeHubView.swift`, `Momentum/Components/MomentumDashboardSection.swift`).
///
/// Deliberately a rounded square, never a circle: a circular badge on the same screen as
/// `RingAndDot`'s header ornament -- and, on the Momentum card specifically, in the same viewport
/// as `MomentumProgressBlocks` -- risks reading as a second circular motif, exactly the "two
/// circular motifs" collision 04-UI-SPEC.md's Ring Collision rule forbids. Filled with a
/// low-opacity `paper` tint only, never `hot`/`volt`: those two tokens are reserved elsewhere (CTA
/// fills/progress blocks/shield glyphs, and the static header ornament) and must never double as a
/// badge/icon fill or read as a status indicator.
struct SectionIconBadge: View {
    let systemName: String
    var diameter: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: RithamSpacing.xs + 2)
            .fill(RithamColor.paper.opacity(0.12))
            .frame(width: diameter, height: diameter)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: diameter * 0.5, weight: .medium))
                    .foregroundStyle(RithamColor.paper.opacity(0.85))
            )
            .accessibilityHidden(true)
    }
}
