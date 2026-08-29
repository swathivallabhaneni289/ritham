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
///
/// `animatesEntrance` (opt-in, default `false`, only ever turned on by `WelcomeStepView` via
/// `ScreenHeader`/`RithamScreen`'s own opt-in chain) plays a ONE-TIME reveal on first appearance:
/// the ring fades into place, and the dot travels in along a fixed curved path from outside the
/// ring to dead centre, then stops completely -- built to match `.planning/sketches/
/// 004-welcome-hero-treatment`'s approved "Synthesis" variant exactly (band settles, ring reveals
/// quietly, the dot's curved travel is the one deliberate motion). This does not violate the
/// static/non-data-bearing rule above: the path and duration are fixed constants, nothing here
/// represents a value, and once the animation completes the ring and dot are pixel-identical to
/// the always-static rendering everywhere else in the app.
struct RingAndDot: View {
    /// The ornament's overall size. Not a progress value -- there is no such parameter here.
    var diameter: CGFloat = 24
    var animatesEntrance: Bool = false

    /// The large "hero" treatment from sketch 004's approved Synthesis variant (Welcome only):
    /// a thinner relative stroke and a smaller relative dot than the small corner ornament used
    /// everywhere else, matching `.ring.giant`'s own proportions in the sketch rather than the
    /// small `.ring`'s -- a giant ring built from the small ring's proportions reads as chunky
    /// and the dot as oversized, which is why these aren't simple percentages of `diameter`.
    var isHero: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringRevealed = false
    @State private var dotProgress: CGFloat = 0

    private var dotDiameter: CGFloat { diameter * (isHero ? 0.14 : 0.3) }
    private var strokeWidth: CGFloat { isHero ? 4 : max(diameter * 0.06, 1) }
    private var shouldAnimate: Bool { animatesEntrance && !reduceMotion }

    /// The dot's start offset (outside the ring, upper-right) and a control point that bends its
    /// path into a curve, both expressed as fractions of `diameter` so the motion scales with the
    /// ornament's own size rather than a fixed pixel path.
    private var dotStart: CGSize { CGSize(width: diameter * 0.55, height: -diameter * 0.5) }
    private var dotControl: CGSize { CGSize(width: diameter * 0.12, height: -diameter * 0.18) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(RithamColor.volt, lineWidth: strokeWidth)
                .opacity(shouldAnimate ? (ringRevealed ? 1 : 0) : 1)
                .scaleEffect(shouldAnimate && !ringRevealed ? 0.85 : 1)
            Circle()
                .fill(RithamColor.volt)
                .frame(width: dotDiameter, height: dotDiameter)
                .opacity(shouldAnimate ? (dotProgress > 0.04 ? 1 : 0) : 1)
                .modifier(QuadraticBezierOffset(
                    progress: shouldAnimate ? dotProgress : 1,
                    start: dotStart,
                    control: dotControl
                ))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
        .onAppear {
            guard shouldAnimate else { return }
            withAnimation(.easeOut(duration: 0.5)) { ringRevealed = true }
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.85).delay(0.35)) {
                dotProgress = 1
            }
        }
    }
}

/// Offsets a view along a quadratic Bezier curve as `progress` runs 0 → 1: `start` at 0,
/// smoothly bending through `control`, arriving at zero offset (the view's own natural position)
/// at 1. Used only for the one-time dot entrance above -- `animatableData` makes this drive
/// cleanly off SwiftUI's own animation timing rather than a manual timer.
private struct QuadraticBezierOffset: GeometryEffect {
    var progress: CGFloat
    let start: CGSize
    let control: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress
        let inv = 1 - t
        let x = inv * inv * start.width + 2 * inv * t * control.width
        let y = inv * inv * start.height + 2 * inv * t * control.height
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
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
///
/// Radius and vertical anchor are tuned to bleed off the trailing (right) edge only. An earlier
/// version centered the largest circle at the header's vertical midpoint with a radius large
/// enough to overflow both the top AND bottom of the header frame -- `ScreenHeader`'s `.clipped()`
/// then sliced that overflow off abruptly right at the header's top edge, reading as the header
/// itself being cut off rather than the ornament gracefully bleeding off an edge. Anchoring lower
/// and scaling down keeps the bleed confined to the trailing/bottom corner, matching the "bleeding
/// off the right edge" intent without slicing across the top.
struct ArcOrnament: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(RithamColor.paper.opacity(0.25), lineWidth: 1.5)
                        .frame(width: proxy.size.height * CGFloat(index + 1) * 0.34)
                }
            }
            .position(x: proxy.size.width, y: proxy.size.height * 0.72)
        }
        .allowsHitTesting(false)
    }
}
