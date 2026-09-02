import SwiftUI
import RithamCore

/// §1.3's nine-category condition checklist, shown to everyone. Every selection change routes
/// through `ChecklistSelection.toggle` (via `checkRow`'s commit closure) rather than a second,
/// view-local reimplementation of the exclusive-option rule -- a second implementation could
/// drift and feed the resolver a contradictory selection (T-01-99).
///
/// Each section carries its own "None of these apply" confirmation, routed through
/// `ChecklistSelection.toggleNoneForSection(_:sectionItems:)` for the same reason -- live-review
/// feedback (2026-09-01) wanted a per-section "none" rather than one shared control at the end of
/// the whole list. `ChecklistItem.noneOfTheAbove` and the single global sentinel it still
/// enforces (`ChecklistSelection.toggle`) remain in RithamCore for any other caller; `TagDerivation`
/// recognizes every section being confirmed none as the equivalent of that global sentinel.
///
/// This has gone through two rounds of live-review feedback on layout alone (2026-09-02): the
/// original chip grid read as "a wall of boxes," and a tap-to-expand-per-section follow-up added
/// more interactive surface than it removed ("too complicated"). This version drops both: every
/// section stays visible with no expand/collapse state at all, each condition is a compact
/// single-line checkbox row rather than a boxed chip, and "None of these apply" sits inline next
/// to the section title as one small toggle rather than a separate control down in the list --
/// declining a whole section is one tap, not two. `checkRow`/the section header are local to this
/// view (not `ChoiceQuestionView`/`ChoiceChip`, which stay the chip-grid presentation every other
/// fixed-choice question in this phase uses) since this compact-row treatment is specific to a
/// list this long, not a change to the shared component.
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
        /// applied to this per-section confirmation).
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
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    sectionHeader(for: group)

                    if let rationale = group.rationale {
                        Text(rationale)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(group.items) { item in
                        checkRow(
                            title: item.displayName,
                            isSelected: checklistBinding.wrappedValue.items.contains(item)
                        ) {
                            checklistBinding.wrappedValue.toggle(item)
                        }
                    }
                }
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .conditionChecklist)
            }
        }
    }

    private func sectionHeader(for group: Group) -> some View {
        let noneApplies = checklistBinding.wrappedValue.noneConfirmedCategories.isSuperset(of: group.categories)

        return HStack(spacing: RithamSpacing.sm) {
            Text(group.title)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            Spacer()

            Button {
                checklistBinding.wrappedValue.toggleNoneForSection(group.categories, sectionItems: Set(group.items))
            } label: {
                HStack(spacing: RithamSpacing.xs) {
                    Image(systemName: noneApplies ? "checkmark.square.fill" : "square")
                        .foregroundStyle(noneApplies ? RithamColor.hot : RithamColor.paper)
                    Text("None apply")
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                }
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("None of these apply")
            .accessibilityAddTraits(noneApplies ? [.isSelected] : [])
        }
    }

    private func checkRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RithamSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? RithamColor.hot : RithamColor.paper)
                Text(title)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
