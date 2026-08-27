import SwiftUI

/// The screen scaffold every onboarding/screening screen in this phase composes, binding the
/// design system (`RithamColor`/`RithamType`/`RithamSpacing`) to the decorative surface
/// inventory (01-UI-SPEC.md, Decorative Surface Inventory).
///
/// `surface` has no default value on purpose. Giving it one would let a screen silently inherit
/// decoration, and the Inventory's closing rule is that any screen collecting, confirming, or
/// blocking on health or consent data stays flat charcoal -- no bands, no halftone, no arcs, no
/// mascot. Requiring every screen to state its surface explicitly is what makes that rule
/// enforceable structurally rather than by review convention: there is no default to fall back
/// on, so a screen author cannot forget to declare it.
///
/// The whole screen scrolls, and no text region is given a fixed-height frame. 01-UI-SPEC.md's
/// LAUNCH-01 through LAUNCH-03 constraint requires the layout to tolerate string-length changes
/// without redesign -- a Phase 5 legal/clinical revision to the screening wording is expected,
/// and a fixed-height text container would break under that revision the moment the new copy
/// ran longer than the old.
struct RithamScreen<Content: View>: View {
    let surface: DecorativeSurface
    var headline: String?
    var bodyText: String?
    @ViewBuilder let content: () -> Content

    init(
        surface: DecorativeSurface,
        headline: String? = nil,
        bodyText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.surface = surface
        self.headline = headline
        self.bodyText = bodyText
        self.content = content
    }

    var body: some View {
        ZStack {
            RithamColor.ink
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // The decorative header sits outside the screen margin -- it manages its
                    // own bounded height and accessibility-size drop-out (ScreenHeader.swift).
                    ScreenHeader(surface: surface)

                    VStack(alignment: .leading, spacing: RithamSpacing.lg) {
                        if let headline {
                            Text(headline)
                                .font(RithamType.display)
                                .foregroundStyle(RithamColor.paper)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let bodyText {
                            Text(bodyText)
                                .font(RithamType.body)
                                .foregroundStyle(RithamColor.paper)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        content()
                    }
                    .padding(RithamSpacing.md)
                }
            }
        }
    }
}
