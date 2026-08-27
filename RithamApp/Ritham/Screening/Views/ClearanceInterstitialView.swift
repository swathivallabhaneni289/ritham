import SwiftUI
import RithamCore

/// §1.2/§4.2/§4.3's clearance interstitial. Takes the already-resolved `ClearanceInterstitial`
/// value rather than re-deriving it from raw answers -- `GateResolution.resolve` is the sole
/// authority on which variant applies (§1.2's branching: urgent on G2/G3 = Yes, routine on any
/// other G1-G7 = Yes).
///
/// Both variants render on a flat-charcoal field with an off-white card (Decorative Surface
/// Inventory), matching the same card treatment `AgeIneligibleStepView` and the (future)
/// required-blocking message use for a plain blocking/hold message. The urgent variant is made
/// visually distinct with a leading SF Symbol and a coral border/rule on the card -- coral is the
/// sanctioned signal accent (01-UI-SPEC.md); the destructive system red is reserved for a later
/// phase and never appears on any Phase 1 screen. Neither variant offers an action that skips the
/// condition checklist: both continue there, per §1.2's explicit "either way, the user proceeds
/// to the checklist afterward" (T-01-96) -- a yes here alone doesn't tell Ritham which rule set to
/// hold back, so the checklist still has to run.
struct ClearanceInterstitialView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .clearanceInterstitial

    static func makeView(flow: OnboardingFlow) -> AnyView {
        let result = GateResolution.resolve(
            answers: flow.answers.screening,
            ageDerivedTags: flow.answers.ageDerivedTags
        )
        return AnyView(ClearanceInterstitialView(variant: result.interstitial, flow: flow))
    }

    let variant: ClearanceInterstitial
    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            card

            PrimaryCTAButton(title: ctaTitle) {
                flow.advance(from: .clearanceInterstitial)
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            HStack(alignment: .top, spacing: RithamSpacing.sm) {
                if isUrgent {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(RithamColor.hot)
                }
                // `LocalizedStringKey` markdown rendering is scoped to only these two blocks --
                // they're the only screening copy blocks that carry `**bold**` markers; every
                // other copy constant in this plan renders as plain `Text` so a stray `*`
                // character elsewhere can never be misparsed as emphasis.
                Text(.init(bodyCopy))
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RithamSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RithamColor.paper)
        .overlay(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(isUrgent ? RithamColor.hot : Color.clear, lineWidth: isUrgent ? 3 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }

    private var isUrgent: Bool {
        variant == .urgent
    }

    private var bodyCopy: String {
        switch variant {
        case .urgent:
            return ScreeningCopy.urgentClearanceInterstitial
        case .routine, .none:
            // `.none` is unreachable in practice -- `OnboardingRouter` only routes to
            // `.clearanceInterstitial` when at least one gate question is "Yes", the same
            // condition under which `GateResolution.resolve`'s `interstitial` is never `.none`.
            // Falling back to the routine copy (rather than leaving the switch non-exhaustive or
            // trapping) keeps this view from crashing if that invariant is ever violated
            // upstream.
            return ScreeningCopy.routineClearanceInterstitial
        }
    }

    private var ctaTitle: String {
        isUrgent ? ScreeningCopy.urgentClearanceCTA : ScreeningCopy.routineClearanceCTA
    }
}
