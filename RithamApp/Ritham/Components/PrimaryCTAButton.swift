import SwiftUI

/// The primary call-to-action button ("Continue," "Start calibration session," "I understand —
/// continue"). Fills with `RithamColor.hot` and takes its label color from
/// `RithamColor.label(on:)`, which returns charcoal for a coral fill -- never off-white, which
/// fails contrast on coral at 2.8:1 (01-UI-SPEC.md, Contrast Verification). Enforces the
/// forty-four point minimum tap target in both dimensions and carries an accessibility label
/// matching its visible title.
struct PrimaryCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.label(on: RithamColor.hot))
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, RithamSpacing.md)
                .background(RithamColor.hot)
                .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
        .accessibilityLabel(title)
    }
}

/// A secondary action -- e.g. the teen notice's skip-for-now action -- styled as an outlined
/// control on charcoal using `RithamColor.paper` (17.2:1 on ink, per 01-UI-SPEC.md's Contrast
/// Verification), holding the same minimum tap target as `PrimaryCTAButton`.
struct SecondaryCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, RithamSpacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
    }
}
