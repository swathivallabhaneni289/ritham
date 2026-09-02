import SwiftUI
import RithamCore

/// §1.3's nine-category condition checklist, shown to everyone. Every selection change routes
/// through `ChecklistSelection.toggle` (via `ChoiceQuestionView`'s `ChecklistItem`-specific
/// initializer) rather than a second, view-local reimplementation of the exclusive-option rule --
/// a second implementation could drift and feed the resolver a contradictory selection (T-01-99).
///
/// Each section carries its own "None of these apply" confirmation, routed through
/// `ChecklistSelection.toggleNoneForSection(_:sectionItems:)` for the same reason -- live-review
/// feedback (2026-09-01) wanted a per-section "none" rather than one shared control at the end of
/// the whole list, which this view no longer renders (`TagDerivation` recognizes every section
/// being confirmed none as the equivalent of the old global sentinel -- see its own comment).
/// `ChecklistItem.noneOfTheAbove` itself still exists in RithamCore for any other caller.
///
/// Each section is a tap-to-expand disclosure, the same established pattern `GlossaryTerm`/
/// `ConditionDisclaimerTag` already use elsewhere in this app (a `Button` toggling local
/// `@State`, a chevron that flips) rather than SwiftUI's own `DisclosureGroup`, which nothing
/// else in the app uses -- direct product feedback (2026-09-02): with 8 categories and up to 4
/// items each, showing every section's chips at once read as "a wall of boxes." Starts fully
/// collapsed except any section that already has an answer (e.g. re-opening this screen via
/// Settings' Condition checklist entry point), so a returning user's prior answers are not
/// hidden behind a second tap. A small checkmark badge next to an answered section's title
/// survives collapsing it back, so answered state is never silently lost from view.
///
/// The pregnancy/postpartum and eating-disorder-history groups each render their §1.3 rationale
/// line above the group, at the `label` role (full weight, not `fineprint`'s reduced-opacity
/// treatment) -- these lines explain why Ritham asks, and treating them as a footnote would
/// misrepresent what the user is consenting to by omission (T-01-100).
struct ConditionChecklistView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .conditionChecklist

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(ConditionChecklistView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var expandedGroupIDs: Set<String>

    private struct Group: Identifiable {
        let id: String
        let title: String
        let items: [ChecklistItem]
        let rationale: String?

        /// Derived from `items` rather than hand-listed a second time -- `ChecklistItem.category`
        /// is already the single source of truth for which category each item belongs to, and a
        /// second, separately-maintained mapping here could drift from it (T-01-99's reasoning
        /// applied to this new per-section confirmation).
        var categories: Set<ChecklistCategory> {
            Set(items.map(\.category))
        }
    }

    private static let groups: [Group] = [
        Group(id: "cardiovascular", title: "Cardiovascular", items: [
            .highBloodPressure, .heartDisease, .irregularHeartbeat, .otherHeartOrCirculatoryCondition,
        ], rationale: nil),
        Group(id: "metabolic", title: "Metabolic", items: [
            .type1Diabetes, .type2Diabetes, .prediabetes, .otherMetabolicCondition,
        ], rationale: nil),
        Group(id: "musculoskeletalJoint", title: "Musculoskeletal / Joint", items: [
            .osteoarthritis, .osteoporosisOrOsteopenia, .chronicLowBackPain, .priorInjuryOrSurgery,
        ], rationale: nil),
        // §1.3 groups pregnancy and postpartum under one heading with one shared rationale line,
        // even though `ChecklistItem.category` models them as two distinct `ChecklistCategory`
        // cases -- this view follows the doc's visual grouping, not the core type's category
        // split, since the rationale and heading are a presentation concern.
        Group(id: "pregnancyPostpartum", title: "Pregnancy / Postpartum", items: [
            .currentlyPregnant, .postpartum,
        ], rationale: ScreeningCopy.pregnancyRationale),
        Group(id: "kidneyRenal", title: "Kidney / Renal", items: [
            .kidneyDiseaseCKD, .currentlyOnDialysis,
        ], rationale: nil),
        Group(id: "eatingDisorderHistory", title: "Eating Disorder History", items: [
            .eatingDisorderHistory,
        ], rationale: ScreeningCopy.eatingDisorderRationale),
        Group(id: "foodAllergies", title: "Food Allergies", items: [
            .foodAllergies,
        ], rationale: nil),
        Group(id: "otherSeriousCondition", title: "Other Serious Condition", items: [
            .activeCancerTreatment, .otherSeriousOrComplexCondition,
        ], rationale: nil),
    ]

    init(flow: OnboardingFlow) {
        self.flow = flow
        let selection = flow.answers.screening.checklist
        let answeredIDs = Self.groups.filter { Self.isAnswered($0, selection: selection) }.map(\.id)
        _expandedGroupIDs = State(initialValue: Set(answeredIDs))
    }

    private var checklistBinding: Binding<ChecklistSelection> {
        Binding(
            get: { flow.answers.screening.checklist },
            set: { flow.answers.screening.checklist = $0 }
        )
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, bodyText: ScreeningCopy.conditionChecklistIntro) {
            ForEach(Self.groups) { group in
                VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                    disclosureHeader(for: group)

                    if expandedGroupIDs.contains(group.id) {
                        if let rationale = group.rationale {
                            Text(rationale)
                                .font(RithamType.label)
                                .foregroundStyle(RithamColor.paper)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ChoiceQuestionView(
                            prompt: "",
                            options: group.items,
                            checklistSelection: checklistBinding,
                            optionTitle: { $0.displayName }
                        )

                        ChoiceChip(
                            title: "None of these apply",
                            isSelected: checklistBinding.wrappedValue.noneConfirmedCategories.isSuperset(of: group.categories)
                        ) {
                            checklistBinding.wrappedValue.toggleNoneForSection(group.categories, sectionItems: Set(group.items))
                        }
                    }
                }
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .conditionChecklist)
            }
        }
    }

    private func disclosureHeader(for group: Group) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        let answered = Self.isAnswered(group, selection: checklistBinding.wrappedValue)

        return Button {
            if isExpanded {
                expandedGroupIDs.remove(group.id)
            } else {
                expandedGroupIDs.insert(group.id)
            }
        } label: {
            HStack(spacing: RithamSpacing.xs) {
                Text(group.title)
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)

                if answered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RithamColor.hot)
                        .accessibilityHidden(true)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(RithamColor.paper)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityHint("Activating shows this section's questions")
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
        .accessibilityLabel(answered ? "\(group.title), answered" : group.title)
    }

    /// A section counts as answered once it has either a real selection or its own "None of
    /// these apply" confirmation -- matching exactly what `TagDerivation`'s baseline-tag check
    /// (RithamCore) treats as "this section is settled," so the badge here never disagrees with
    /// what actually feeds tag derivation.
    private static func isAnswered(_ group: Group, selection: ChecklistSelection) -> Bool {
        if selection.noneConfirmedCategories.isSuperset(of: group.categories) {
            return true
        }
        return !Set(group.items).isDisjoint(with: selection.items)
    }
}
