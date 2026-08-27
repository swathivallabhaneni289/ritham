import SwiftUI

/// A static, non-data-bearing brand ornament: one thin lime stroke ring with a single solid
/// centre dot, drawn with `RithamColor.volt`.
///
/// Per 01-UI-SPEC.md's binding Ring-and-Dot decision, this may ONLY ever be a static ornament --
/// it must never gain a second concentric ring, never fill or animate to represent a fraction,
/// never serve as a progress, streak, or loading indicator, and must never sit adjacent to
/// Momentum data. That constraint is what keeps it from reading as an Apple Activity-Rings-style
/// data widget: Apple's rings are always three, always closing/filling, always representing
/// move/exercise/stand -- this is deliberately one ring, one dot, always static, decorative
/// typography rather than a data widget. This type is given no parameter that could carry a
/// progress, fraction, or completion value, so the misuse this rule forbids is not expressible
/// through its API.
struct RingAndDot: View {
    /// The ornament's overall size. Not a progress value -- there is no such parameter here.
    var diameter: CGFloat = 24

    private var dotDiameter: CGFloat { diameter * 0.3 }
    private var strokeWidth: CGFloat { max(diameter * 0.06, 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(RithamColor.volt, lineWidth: strokeWidth)
            Circle()
                .fill(RithamColor.volt)
                .frame(width: dotDiameter, height: dotDiameter)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// A bounded, decorative halftone dot pattern for the header's top-right corner (sketch 003:
/// "halftone dot pattern in one dark corner, top-right, coral-tinted"). Confined to its own
/// bounded frame -- never a full-screen wash, per the accent-discipline rule that coral is a
/// signal, never a decorative surface covering more than a thin band or small ornament.
struct HalftoneOrnament: View {
    private let rows = 5
    private let columns = 5

    var body: some View {
        GeometryReader { proxy in
            let spacing = min(proxy.size.width, proxy.size.height) / CGFloat(max(rows, columns))
            ZStack(alignment: .topTrailing) {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        Circle()
                            .fill(RithamColor.hot.opacity(0.35))
                            .frame(width: spacing * 0.35, height: spacing * 0.35)
                            .offset(x: -CGFloat(column) * spacing, y: CGFloat(row) * spacing)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
        }
        .frame(width: 96, height: 96)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

/// Concentric decorative arcs bleeding off the header's trailing edge (sketch 003: "concentric
/// arcs bleeding off the right edge"). Bounded to the header region it is drawn in -- never a
/// full-screen bleed.
struct ArcOrnament: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(RithamColor.paper.opacity(0.25), lineWidth: 1.5)
                        .frame(width: proxy.size.height * CGFloat(index + 1) * 0.6)
                }
            }
            .position(x: proxy.size.width, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}
