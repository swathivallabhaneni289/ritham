import SwiftUI

/// A single selectable option control, the building block `ChoiceQuestionView` lays out for
/// every fixed-choice question shape in this phase. Selected state fills with `RithamColor.hot`
/// and takes its label color from `RithamColor.label(on:)`; unselected renders as an outlined
/// control on charcoal with `RithamColor.paper` text. Both states hold at least
/// `RithamSpacing.minimumTapTarget` in both dimensions.
///
/// Selection is exposed through `accessibilityAddTraits(.isSelected)` so assistive technology
/// receives the state directly, rather than only through a color change a screen reader cannot
/// perceive.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RithamType.body)
                .foregroundStyle(isSelected ? RithamColor.label(on: RithamColor.hot) : RithamColor.paper)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, RithamSpacing.md)
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                .background(chipBackground)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: RithamSpacing.sm).fill(RithamColor.hot)
        } else {
            RoundedRectangle(cornerRadius: RithamSpacing.sm).stroke(RithamColor.paper, lineWidth: 1)
        }
    }
}
