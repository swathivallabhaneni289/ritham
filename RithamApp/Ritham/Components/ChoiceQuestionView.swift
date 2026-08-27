import SwiftUI
import RithamCore

// HEALTH-01 forbids free text anywhere in this questionnaire. This component is the one
// fixed-choice question view every screening/onboarding screen in this phase uses, and it
// exposes no free-text mode: no text-entry variant, no "other, please specify" affordance, no
// `TextField` of any kind. Adding one here would breach HEALTH-01 for every screen that composes
// this component, all at once. The sole numeric entry in the entire questionnaire is Q0's age
// field, which the age screen implements directly with its own bounded validation, not through
// this component.

/// Which selection behavior a question uses.
enum ChoiceMode: Equatable {
    /// Selecting an option replaces the current selection -- a two-option Yes/No question, a
    /// three-option Yes/No/Not-sure question, or a single-select-from-a-list question (docs/
    /// health-screening.md §1.2-§1.4).
    case single

    /// Selecting an option adds it to the current selection. When `exclusiveOption` is set,
    /// selecting it clears every other selection, and selecting any other option clears it --
    /// §1.3's None-of-the-above behavior for the condition checklist.
    case multiple(exclusiveOption: AnyHashable?)
}

/// Pure selection logic, extracted into a standalone type so the exclusive-option invariant can
/// be asserted by `ChoiceQuestionTests` without rendering any view.
///
/// `ChecklistSelection` (RithamCore) already enforces this identical invariant -- selecting
/// `noneOfTheAbove` clears everything else, selecting anything else clears `noneOfTheAbove` --
/// for the condition checklist specifically, inside its own `toggle(_:)` mutator. This reducer's
/// job is to reproduce that same behavior generically for every other fixed-choice shape in this
/// phase, not to re-derive or replace `ChecklistSelection`. Where a screen's binding is actually
/// a `ChecklistSelection`, `ChoiceQuestionView`'s `ChecklistSelection`-specific initializer below
/// defers directly to `toggle(_:)` instead of running this reducer.
enum ChoiceSelectionReducer {
    static func toggling<Option: Hashable>(
        _ option: Option,
        in selection: Set<Option>,
        mode: ChoiceMode
    ) -> Set<Option> {
        switch mode {
        case .single:
            return [option]

        case .multiple(let exclusiveOption):
            var next = selection
            let optionIsExclusive = exclusiveOption.map { AnyHashable(option) == $0 } ?? false

            if optionIsExclusive {
                if next.contains(option) {
                    next.remove(option)
                } else {
                    next = [option]
                }
                return next
            }

            if let exclusiveOption, let exclusiveValue = exclusiveOption.base as? Option {
                next.remove(exclusiveValue)
            }

            if next.contains(option) {
                next.remove(option)
            } else {
                next.insert(option)
            }
            return next
        }
    }
}

/// `ChecklistItem` (RithamCore) is `Hashable` but not `Identifiable` -- it has no UI-layer
/// concept, so RithamCore has no reason to conform it. `ChoiceQuestionView` requires
/// `Identifiable` to drive `ForEach` without a separate id parameter; a raw-value-backed
/// `CaseIterable` enum is its own stable, unique identity, so `id: Self { self }` is safe here.
extension ChecklistItem: Identifiable {
    public var id: Self { self }
}

/// The one fixed-choice question component every questionnaire screen in this phase uses --
/// two-option, three-option, single-select-from-a-list, and multi-select-with-an-exclusive-
/// option all go through this same view (docs/health-screening.md §1.2-§1.4).
///
/// Generic over an option type conforming to `Hashable` and `Identifiable`. Lays out the prompt
/// at the `body` role, the helper at the `label` role via `fineprint()`, and the chips in a
/// layout that wraps rather than truncates, so long option strings stay fully readable at
/// accessibility text sizes.
struct ChoiceQuestionView<Option: Hashable & Identifiable>: View {
    let prompt: String
    var helper: String?
    let options: [Option]
    let optionTitle: (Option) -> String
    private let isSelected: (Option) -> Bool
    private let commit: (Option) -> Void

    /// The general-purpose initializer: `ChoiceSelectionReducer` derives the next selection
    /// from `mode` and writes it back through `selection`.
    init(
        prompt: String,
        helper: String? = nil,
        options: [Option],
        mode: ChoiceMode,
        selection: Binding<Set<Option>>,
        optionTitle: @escaping (Option) -> String
    ) {
        self.prompt = prompt
        self.helper = helper
        self.options = options
        self.optionTitle = optionTitle
        self.isSelected = { option in selection.wrappedValue.contains(option) }
        self.commit = { option in
            selection.wrappedValue = ChoiceSelectionReducer.toggling(option, in: selection.wrappedValue, mode: mode)
        }
    }

    /// The condition-checklist-specific initializer: defers every mutation directly to
    /// `ChecklistSelection.toggle(_:)` rather than running `ChoiceSelectionReducer` --
    /// `ChecklistSelection` already enforces the None-of-the-above exclusivity invariant itself,
    /// so this component's job here is to present that state, not re-derive it.
    init(
        prompt: String,
        helper: String? = nil,
        options: [Option],
        checklistSelection: Binding<ChecklistSelection>,
        optionTitle: @escaping (Option) -> String
    ) where Option == ChecklistItem {
        self.prompt = prompt
        self.helper = helper
        self.options = options
        self.optionTitle = optionTitle
        self.isSelected = { option in checklistSelection.wrappedValue.items.contains(option) }
        self.commit = { option in checklistSelection.wrappedValue.toggle(option) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(prompt)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            if let helper {
                Text(helper)
                    .modifier(RithamType.fineprint())
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            WrapLayout(spacing: RithamSpacing.sm) {
                ForEach(options) { option in
                    ChoiceChip(title: optionTitle(option), isSelected: isSelected(option)) {
                        commit(option)
                    }
                }
            }
        }
    }
}

/// A wrapping horizontal-then-vertical layout so chips flow onto a new line instead of being
/// truncated or forced to shrink -- required so long option strings stay fully readable at
/// accessibility text sizes (01-UI-SPEC.md's reflow rule).
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + spacing + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                widestLine = max(widestLine, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        widestLine = max(widestLine, lineWidth)

        let width = maxWidth.isFinite ? maxWidth : widestLine
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
