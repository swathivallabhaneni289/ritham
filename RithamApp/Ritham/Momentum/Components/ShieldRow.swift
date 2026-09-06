import SwiftUI
import RithamCore

// MOMENTUM-02's shield display.
//
// No consumption animation of any kind: when reconciliation auto-consumes a shield to cover a
// missed week, this row simply renders its new, lower count the next time the screen appears --
// no shrink, fade-out, shatter, or "spent" transition of any kind. This generalizes the "no
// reset-to-zero animation" rule from MOMENTUM-05: any animated loss of a game-like asset (a
// shield, a streak number ticking down) reads as punishment, exactly what this phase's framing
// rule forbids. A newly-earned shield may use a plain, brief fade-in and nothing more -- never a
// celebratory burst/confetti/bespoke animation.
//
// These glyphs render at roughly 32pt, deliberately below the 44pt tap-target floor -- they are
// display-only, non-interactive glyphs, not controls, and must never be wrapped in a `Button`.
struct ShieldRow: View {
    let earned: Int
    let maximum: Int

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            HStack(spacing: RithamSpacing.sm) {
                ForEach(0..<max(maximum, 0), id: \.self) { index in
                    // Filled-vs-outline SF Symbol variant is a second, non-color channel
                    // alongside the fill-color change (WCAG 1.4.1 "not color alone"), matching
                    // the progress blocks' own filled-vs-translucent discipline.
                    Image(systemName: index < earned ? "shield.fill" : "shield")
                        .font(.system(size: 32))
                        .foregroundStyle(index < earned ? RithamColor.hot : RithamColor.paper.opacity(0.2))
                }
            }

            Text(MomentumCopy.Shields.shields(earned: earned))
                .font(RithamType.label)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)
        }
    }
}
