import SwiftUI
import RithamCore

/// Welcome — the first screen every user sees. 01-UI-SPEC.md's Decorative Surface Inventory
/// gives this screen the full decorative treatment (`DecorativeSurface.welcome`): band motif,
/// halftone, arcs, and the ring-and-dot ornament.
///
/// Momo (the mascot) is reserved as a bounded inset card on the flat charcoal field below the
/// header, never floated over the band motif or halftone texture — 01-UI-SPEC.md's Momo
/// Placement section explains why: a semi-realistic painted illustration and the hard-edged
/// flat band motif are a genuine style collision when overlapped, and bounding Momo in his own
/// card resolves it.
///
/// Whether Momo ships at all is an explicitly open, deferred decision (01-CONTEXT.md,
/// `<specifics>`) — not this phase's to settle. `MomoHeroCard` below is a slot that renders its
/// content when an asset is supplied and collapses cleanly to nothing when none is, so this file
/// is correct regardless of how that decision resolves later. No artwork is commissioned,
/// generated, or invented here.
struct WelcomeStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .welcome

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(WelcomeStepView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.welcome,
            headline: OnboardingCopy.Welcome.headline,
            bodyText: OnboardingCopy.Welcome.subhead
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.lg) {
                MomoHeroCard(asset: nil)

                PrimaryCTAButton(title: OnboardingCopy.Welcome.cta) {
                    flow.advance(from: .welcome)
                }
            }
        }
    }
}

/// A bounded inset card reserved for Momo's hero art (01-UI-SPEC.md's Momo Placement section).
/// Renders `asset` when one is supplied; collapses to an empty view when it is `nil`, since
/// Momo's inclusion is an open, deferred decision this file does not presume.
private struct MomoHeroCard: View {
    let asset: Image?

    var body: some View {
        if let asset {
            asset
                .resizable()
                .scaledToFit()
                .padding(RithamSpacing.md)
                .frame(maxWidth: .infinity)
                .background(RithamColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
    }
}
