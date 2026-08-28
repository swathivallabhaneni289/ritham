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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            EmptyView()
        } else {
            decorativeContent
                .frame(height: height)
                .clipped()
        }
    }

    @ViewBuilder
    private var decorativeContent: some View {
        ZStack {
            RithamColor.ink

            if surface.bandMotif {
                ForEach(0..<3, id: \.self) { band in
                    BandMotif(band: band)
                        .fill(bandFill(for: band))
                }
            }

            if surface.halftone {
                HalftoneOrnament()
            }

            if surface.arcs {
                ArcOrnament()
            }

            if surface.ringAndDot {
                RingAndDot(animatesEntrance: animatesEntrance)
                    .padding(RithamSpacing.md)
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
