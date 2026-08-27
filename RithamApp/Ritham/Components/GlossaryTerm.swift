import SwiftUI
import RithamCore

/// EXPLAIN-01's tap-to-expand definition. Renders `term` inline with a visible expand
/// affordance and, on tap, reveals the definition for the register read from the environment
/// (`RegisterEnvironment.swift`) -- never from local state, never derived from age or tier.
///
/// Expands in place (an inline disclosure) rather than navigating away, since EXPLAIN-01
/// describes expanding in place, not leaving the flow. When `term` has no glossary entry, this
/// renders as plain text with no affordance at all -- a broken affordance (a tap target that
/// reveals nothing) is worse than none.
struct GlossaryTerm: View {
    let term: String

    @State private var isExpanded = false
    @Environment(\.explanationRegister) private var register

    var body: some View {
        if let entry = Glossary.entry(for: term) {
            VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: RithamSpacing.xs) {
                        Text(term)
                            .font(RithamType.body)
                            .underline()
                        Image(systemName: isExpanded ? "chevron.up.circle" : "info.circle")
                    }
                    .foregroundStyle(RithamColor.paper)
                    // Non-negotiable even for a short word (01-UI-SPEC.md's tap-target
                    // exception) -- teens and grandparents use identical controls.
                    .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("Activating reveals a definition")
                .accessibilityAddTraits(isExpanded ? [.isSelected] : [])

                if isExpanded {
                    Text(entry.definition(for: register))
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Definition of \(term): \(entry.definition(for: register))")
                }
            }
        } else {
            Text(term)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
        }
    }
}
