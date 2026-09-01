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
                    if let rationale = group.rationale {
                        Text(rationale)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ChoiceQuestionView(
                        prompt: group.title,
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

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .conditionChecklist)
            }
        }
    }
}
