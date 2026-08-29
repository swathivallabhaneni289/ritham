import SwiftUI

/// Which decorative elements a screen's bounded header region may show. Matches the Decorative
/// Surface Inventory rows in 01-UI-SPEC.md exactly.
struct DecorativeSurface {
    var bandMotif: Bool
    var halftone: Bool
    var arcs: Bool
    var ringAndDot: Bool

    /// Welcome / hero screen -- the full decorative surface.
    static let welcome = DecorativeSurface(bandMotif: true, halftone: true, arcs: true, ringAndDot: true)

    /// Explanation-register picker and the privacy explainer: a bounded header band only, plus
    /// the small corner ring-and-dot ornament.
    static let boundedHeaderOnly = DecorativeSurface(bandMotif: true, halftone: false, arcs: false, ringAndDot: true)

    /// Calibration start / complete: band motif and ring, no halftone or arcs.
    static let calibration = DecorativeSurface(bandMotif: true, halftone: false, arcs: false, ringAndDot: true)

    /// Any screen that collects, confirms, or blocks on health or consent data stays flat
    /// charcoal: no bands, no halftone, no arcs, no mascot (01-UI-SPEC.md, Decorative Surface
    /// Inventory closing rule). Per the Inventory's 2026-08-23 update -- Ritham has a permanent
    /// 13+ age floor with no consent flow of any kind, which removed the separate "Under-13
    /// halt / parent-consent step" and "13-17 partial-gate notice" rows -- the current flat-only
    /// screen set is exactly these nine, enumerated here so a later screen plan does not have to
    /// re-derive the mapping:
    ///   1. Age (Q0)
    ///   2. Dietary pattern (Q0b)
    ///   3. Age blocking (under 13)
    ///   4. Gate section (G1-G7)
    ///   5. Routine clearance interstitial
    ///   6. Urgent clearance interstitial
    ///   7. Condition checklist
    ///   8. SCOFF / eating-disorder follow-up
    ///   9. Required-blocking message
    static let flat = DecorativeSurface(bandMotif: false, halftone: false, arcs: false, ringAndDot: false)
}

/// A bounded decorative header, never a full-screen bleed, so body text always lives outside it
/// and never depends on the band composition leaving room for it.
///
/// At accessibility text sizes (`dynamicTypeSize.isAccessibilitySize`) this view renders nothing
/// at all -- the header compresses out of the layout entirely and content reflows onto the flat
/// charcoal field beneath it. 01-UI-SPEC.md's reflow rule forbids any text being composited over
/// a diagonal band or the halftone texture at AX1 through AX5; dropping the header is the
/// mechanism that makes that unreachable rather than merely discouraged.
struct ScreenHeader: View {
    let surface: DecorativeSurface

    /// Within 01-UI-SPEC.md's 220-280pt recommended header height.
    var height: CGFloat = 250

    /// Opt-in one-time ring-and-dot entrance (see `RingAndDot`'s own doc comment). Defaults to
    /// `false` so every screen besides Welcome renders exactly as before this existed.
    var animatesEntrance: Bool = false

    /// Opt-in large ring-and-dot treatment matching sketch 004's approved Synthesis variant
    /// exactly -- both the band and the ring, ported literally rather than tuned by eye. An
    /// earlier version kept drawing the band through `BandGeometry` (which solves a diagonal to
    /// fit whatever rect it's given, so every other decorated screen's band adapts cleanly to its
    /// own header size) and just narrowed the rect it solved against; that produced a band
    /// thinner than the sketch's, starting well inset from the top-left corner instead of
    /// touching it, which `BandGeometry`'s corner-fit algorithm cannot fix at any parameter
    /// combination. So `heroRing` draws the band with `HeroBandMotif` instead: three fixed-size
    /// bars ported directly from the sketch's own CSS technique. A second, now-fixed mistake:
    /// every constant here was originally scaled against 393pt as this app's reference device
    /// width, copied from memory of iPhone 15/16 Pro's width rather than checked -- the actual
    /// simulator device is 402pt wide (`xcrun simctl io screenshot` at 1206x2622px / 3x = 402x874).
    /// That's why hand-tuning against screenshots never converged: every "sketch-derived" number
    /// was off by the same ~2% before any tuning even started. Every constant below (this file and
    /// `HeroBandMotif`) is now the sketch's own pixel value times the *correct* 402/300 ratio, a
    /// pure port with no eyeballed adjustment. Currently Welcome-only.
    var heroRing: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            EmptyView()
        } else {
            decorativeContent
                .frame(height: heroRing ? 402 : height)
                .clipped()
        }
    }

    @ViewBuilder
    private var decorativeContent: some View {
        ZStack {
            RithamColor.ink

            if surface.bandMotif {
                if heroRing {
                    ForEach(0..<3, id: \.self) { band in
                        HeroBandMotif(band: band)
                    }
                } else {
                    ForEach(0..<3, id: \.self) { band in
                        BandMotif(band: band)
                            .fill(bandFill(for: band))
                    }
                }
            }

            if surface.halftone {
                HalftoneOrnament()
                    .padding(.top, heroRing ? 48 : 0)
            }

            // `heroRing` drops the arc rings entirely per direct feedback -- with the ring
            // itself already large, the extra concentric arcs read as clutter rather than
            // texture. Every other screen using `.arcs` is unaffected.
            if surface.arcs && !heroRing {
                ArcOrnament()
            }

            if surface.ringAndDot {
                RingAndDot(
                    diameter: heroRing ? 143 : 24,
                    animatesEntrance: animatesEntrance,
                    isHero: heroRing
                )
                .padding(.top, heroRing ? 67 : RithamSpacing.md)
                .padding(.trailing, heroRing ? 11 : RithamSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }

    private func bandFill(for band: Int) -> Color {
        switch band {
        case 0: return RithamColor.hot
        case 1: return RithamColor.volt
        default: return RithamColor.paper
        }
    }
}

/// One bar of `heroRing`'s band, a literal port of sketch 004's `.hero-phone .band.*` CSS (see
/// `ScreenHeader.heroRing`'s doc comment for why this exists as a separate technique from
/// `BandGeometry`/`BandMotif`, and for the 402/300 scale ratio used throughout -- this app's
/// actual reference device width, verified against a real screenshot, not assumed). Every
/// constant below is the sketch's own pixel value times that ratio -- a pure port, no eyeballed
/// adjustment.
private struct HeroBandMotif: View {
    /// Which bar: 0 = hot (coral, innermost/leftmost), 1 = volt (lime), 2 = paper (off-white,
    /// outermost/trailing), matching the sketch's own `.band.hot`/`.band.volt`/`.band.paper`
    /// left-to-right order.
    let band: Int

    /// Sketch: `left: 90px / 128px / 166px`.
    private static let leftOffsets: [CGFloat] = [121, 172, 222]

    /// Sketch: `.band { width: 46px }`. Widened from the literal 62pt scale to 74pt -- measured
    /// directly against the rendered sketch (not the CSS source), the visible paper stripe is
    /// ~1.45x the width of the (exactly equal) coral and lime stripes beneath it; at the literal
    /// scale that ratio came out closer to 1.2x, visibly flatter than the reference. Each visible
    /// stripe's width is `barWidth` minus whatever the bar drawn on top of it covers, so widening
    /// every bar equally (offsets unchanged) restores the reference's stronger taper without
    /// touching the corner-touch or clearance math, which depend on `leftOffsets` and rotation,
    /// not `barWidth`.
    private static let barWidth: CGFloat = 74

    /// Sketch: `.hero-phone .band.* { height: 420px }`. Lengthened well past the literal 563pt
    /// scale (see `bottomOvershoot`) so the bar's far end still reaches the top-left corner even
    /// with the pivot pushed much further below the frame.
    private static let barHeight: CGFloat = 832

    /// Sketch: `bottom: -30px` -- the bar's bottom edge sits this far below the header's own
    /// bottom edge before rotation. Pushed well past the literal 40pt scale so the bar is still
    /// solid (not yet tapering toward its own pivot corner) by the time it crosses the header's
    /// clip boundary -- the reference cuts the stripes off in a flat horizontal line, not a
    /// tapered point, which a short, literally-scaled bar can't reproduce: it simply doesn't
    /// reach far enough to still be full-width where the clip happens. Every extra pt of
    /// overshoot pulls the bar's far (top) end away from the top-left corner by the same rigid
    /// rotation, which is why `barHeight` had to grow to compensate.
    private static let bottomOvershoot: CGFloat = 300

    /// Sketch: `transform: rotate(-33deg)` with `transform-origin: bottom left` -- SwiftUI's
    /// `.rotationEffect(anchor:)` is the same mechanic (rotate around a point within the view's
    /// own unrotated bounds, without moving that point), so this ports directly.
    private static let rotationDegrees: Double = -33

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(color)
                .frame(width: Self.barWidth, height: Self.barHeight)
                .position(
                    x: Self.leftOffsets[band] + Self.barWidth / 2,
                    y: proxy.size.height + Self.bottomOvershoot - Self.barHeight / 2
                )
                .rotationEffect(.degrees(Self.rotationDegrees), anchor: .bottomLeading)
        }
    }

    private var color: Color {
        switch band {
        case 0: return RithamColor.hot
        case 1: return RithamColor.volt
        default: return RithamColor.paper
        }
    }
}
