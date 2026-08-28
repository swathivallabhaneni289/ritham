import SwiftUI
import RithamCore

/// §4.4/§4.5's persistent compact disclaimer tag and its expanded form -- the always-visible
/// surface that answers "which of my conditions is this suggestion adjusted for?" wherever an
/// adjusted suggestion appears. Attaches to *adjusted suggestions*, which are HEALTH-03/HEALTH-04
/// work in Phase 2 -- this plan builds the component itself and gives it a real, working home on
/// `HealthProfileView`, so Phase 2's suggestion surfaces attach an already-tested component
/// rather than building a second one.
///
/// Takes a `GateResolutionResult` rather than a single condition name. Per D-12, when two or
/// more condition tags apply but only the single most restrictive gate is binding, the tag still
/// lists every matched condition, not only the one governing gate -- a user seeing only one name
/// would reasonably conclude the others aren't affecting them. `result.disclaimerConditionNames`
/// already returns the complete, sorted, matched set (plan 01-06); this view must not filter it
/// down to a "primary" condition.
///
/// Persistent and always visible by construction: there is no dismiss action, no auto-collapse,
/// and nothing here hides it behind a scroll threshold. Rendered at the `label` role via
/// `fineprint()` -- the sanctioned way for label-role copy to read as fine print (reduced
/// opacity, same 16pt floor) -- never a smaller point size (01-UI-SPEC.md's Typography floor
/// rule names this element specifically). The leading accent mark is coral, the one color
/// 01-UI-SPEC.md reserves for this among a short, fixed list of uses; it is a thin decorative
/// bar, never a fill large enough to need `RithamColor.label(on:)`'s coral-fill contrast rule,
/// but the button/icon area is deliberately charcoal-on-paper (never off-white on a coral fill)
/// to honor that rule wherever it *would* apply.
struct ConditionDisclaimerTag: View {
    let result: GateResolutionResult

    @State private var isExpanded = false

    private var conditions: [String] {
        result.disclaimerConditionNames
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: RithamSpacing.sm) {
                    Rectangle()
                        .fill(RithamColor.hot)
                        .frame(width: RithamSpacing.xs)

                    HStack(alignment: .top, spacing: RithamSpacing.xs) {
                        Text(ScreeningCopy.compactDisclaimerTag(conditions: conditions))
                            .modifier(RithamType.fineprint())
                            .foregroundStyle(RithamColor.paper)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Image(systemName: isExpanded ? "chevron.up.circle" : "info.circle")
                            .foregroundStyle(RithamColor.paper)
                    }
                }
                // The expand affordance must hold `minimumTapTarget` in both dimensions even
                // though the tag itself is visually compact -- 01-UI-SPEC.md lists this among
                // its non-negotiable spacing exceptions.
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityHint("Reveals the full disclaimer for every matched condition")
            .accessibilityAddTraits(isExpanded ? [.isSelected] : [])

            if isExpanded {
                Text(ScreeningCopy.expandedDisclaimer(conditions: conditions))
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }
        }
    }
}
