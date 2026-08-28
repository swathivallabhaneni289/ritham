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

    /// Opt-in, one-time entrance sequence: the header, the headline/body group, and `content()`
    /// fade/slide in staggered rather than appearing instantly static. Defaults to `false` so
    /// every existing screen's layout and appearance are byte-for-byte unchanged -- only a
    /// screen that explicitly asks for this (currently just `WelcomeStepView`, the one flagged
    /// as feeling empty at default text size) opts in. This is a first-impression touch for a
    /// screen seen once per onboarding, not a mechanism every decorated screen should adopt.
    var animatesEntrance: Bool = false

    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    init(
        surface: DecorativeSurface,
        headline: String? = nil,
        bodyText: String? = nil,
        animatesEntrance: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.surface = surface
        self.headline = headline
        self.bodyText = bodyText
        self.animatesEntrance = animatesEntrance
        self.content = content
    }

    /// True once every element should render in its final, resting state: either this screen
    /// never asked for an entrance sequence, Reduce Motion is on (elements must just appear,
    /// never move), or the one-time sequence has already played this launch. `animatesEntrance
    /// == false` makes this `true` from the very first render, which is what keeps every other
    /// screen's appearance identical to before this parameter existed.
    private var isRevealed: Bool {
        !animatesEntrance || reduceMotion || hasAppeared
    }

    /// `nil` whenever nothing should animate (entrance not requested, or Reduce Motion is on) --
    /// so the transition below is structurally inert rather than merely unused in those cases.
    private func entranceAnimation(delay: Double) -> Animation? {
        guard animatesEntrance, !reduceMotion else { return nil }
        return .easeOut(duration: 0.45).delay(delay)
    }

    var body: some View {
        ZStack {
            RithamColor.ink
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // The decorative header sits outside the screen margin -- it manages its
                    // own bounded height and accessibility-size drop-out (ScreenHeader.swift).
                    // The header itself only fades in, no slide -- per product-owner feedback,
                    // stripes sliding into place read as arbitrary motion. The one deliberate
                    // motion is `RingAndDot`'s own opt-in entrance (a fixed, non-data-bearing
                    // curved dot travel, matching sketch 004's approved Synthesis variant), which
                    // is why `animatesEntrance` is threaded through to `ScreenHeader` here rather
                    // than stopping at this block-level fade.
                    ScreenHeader(surface: surface, animatesEntrance: animatesEntrance)
                        .opacity(isRevealed ? 1 : 0)
                        .animation(entranceAnimation(delay: 0), value: hasAppeared)

                    VStack(alignment: .leading, spacing: RithamSpacing.lg) {
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
                        }
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 14)
                        .animation(entranceAnimation(delay: 0.15), value: hasAppeared)

                        content()
                            .opacity(isRevealed ? 1 : 0)
                            .offset(y: isRevealed ? 0 : 14)
                            .animation(entranceAnimation(delay: 0.3), value: hasAppeared)
                    }
                    .padding(RithamSpacing.md)
                }
            }
        }
        .onAppear {
            // Reduce Motion: skip the sequence entirely rather than firing it and letting
            // `isRevealed` short-circuit around it -- `hasAppeared` simply never becomes the
            // animation's trigger, so no motion is ever requested in the first place.
            guard animatesEntrance, !reduceMotion else { return }
            hasAppeared = true
        }
    }
}
