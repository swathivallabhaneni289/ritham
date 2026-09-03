import SwiftUI
import RithamCore

/// §1.3's condition checklist, shown to everyone -- eight categories rendered here; Food
/// Allergies is asked in full (whether the user has one, its severity, and which specific ones)
/// from `DietPlanView` (Settings) instead, per further live-review feedback (2026-09-02): asking
/// only a bare "I have one or more food allergies" here, with no way to say which ones, read as
/// pointless once the detail lived somewhere else entirely. `DietPlanView`'s own header comment
/// covers the full story and why `TagDerivation`/`GateEscalation`'s food-allergy safety tags are
/// unaffected -- only where the question is asked moved, not what it means once answered.
///
/// Every selection change routes
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
/// This has gone through three rounds of live-review feedback on layout (2026-09-02/03): a chip
/// grid read as "a wall of boxes"; a tap-to-expand-per-section follow-up added more interactive
/// surface than it removed ("too complicated"); the compact-row version after that used a
/// leading checkbox-square glyph and was flagged "clumsy" and "confusing" again. Sketch 005
/// (`.planning/sketches/005-condition-checklist-redesign/`) researched why: iOS has no native
/// checkbox control at all (Apple's own component set has nothing named checkbox/chip/tag), and
/// every native iOS multi-select list (Settings, Mail, Reminders) uses a trailing checkmark on a
/// plain list row instead. This version ports that pattern -- `checkRow`'s checkmark trails the
/// label -- and moves each section's "None of these apply" into the row list itself as the
/// section's first row (winning Variant B), rather than a small control bolted onto the section
/// header, which is what made it read as confusing rather than as one more option. Hairline
/// dividers between rows (not whitespace alone) signal grouping, chosen over Variant C's
/// per-section outlined cards specifically because a boxed/carded look was the "wall of boxes"
/// complaint this screen already reverted once.
///
/// The pregnancy/postpartum and eating-disorder-history groups each render their §1.3 rationale
/// line above the group's row list, at the `label` role (full weight, not `fineprint`'s
/// reduced-opacity treatment) -- these lines explain why Ritham asks, and treating them as a
/// footnote would misrepresent what the user is consenting to by omission (T-01-100).
///
/// Live-review feedback (2026-09-03): for the common path (no severity/SCOFF follow-ups
/// triggered), §1.4's universal follow-up (U-1, "are you returning to exercise after being
/// inactive...") landed on its own screen holding nothing but that one question -- "a wasted
/// slide." This view now renders U-1 inline, after the last category, for exactly that common
/// path (`showsInlineUniversalFollowUp` below). A user who *does* need severity/SCOFF follow-ups
/// still answers U-1 on its own screen afterward, same as before -- merging it here unconditionally
/// would mean asking it twice for that path, once inline and once again on `UniversalFollowUpView`.
/// `showsInlineUniversalFollowUp` queries `OnboardingRouter.nextStep` (the single branching
/// authority, CROSSGEN-05) rather than reimplementing "does this selection need follow-ups" --
/// this view decides what to *render* from that query, never what to *route to*; the CTA below
/// still calls the unchanged `flow.advance(from: .conditionChecklist)` regardless of which case
/// this is, so `EditAnswerFlow`'s edit-and-pop-back mechanism (which only watches for `flow.advance`
/// having been called, not what it routed to) is untouched. `UniversalFollowUpView`'s own header
/// comment covers the other half: detecting an already-answered U-1 and auto-completing instead of
/// re-asking it.
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

    /// True when this user's current checklist selection needs no severity/SCOFF follow-ups --
    /// the common path, where U-1 renders inline below instead of on its own screen. Re-evaluated
    /// live against `flow.answers` on every render (a `Binding`-backed computed property, not
    /// cached `@State`), so ticking a box that newly triggers a follow-up (e.g. "Currently
    /// pregnant") makes this section disappear immediately rather than staying stale until the
    /// next screen.
    private var showsInlineUniversalFollowUp: Bool {
        OnboardingRouter.nextStep(after: .conditionChecklist, answers: flow.answers) == .universalFollowUp
    }

    private var universalFollowUpBinding: Binding<Set<YesNo>> {
        Binding(
            get: { flow.answers.screening.u1ReturningAfterInactivity.map { [$0] } ?? [] },
            set: { flow.answers.screening.u1ReturningAfterInactivity = $0.first }
        )
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, bodyText: ScreeningCopy.conditionChecklistIntro) {
            ForEach(Self.groups) { group in
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text(group.title)
                        .font(RithamType.heading)
                        .fontWeight(.bold)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)

                    if let rationale = group.rationale {
                        Text(rationale)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    rowList(for: group)
                }
                // Extra breathing room after each section, live-review feedback (2026-09-03) --
                // on top of RithamScreen's own RithamSpacing.lg gap between top-level content()
                // children, so the total gap after a section reads as clearly larger than the
                // hairline-divider rhythm between rows within one.
                .padding(.bottom, RithamSpacing.md)
            }

            if showsInlineUniversalFollowUp {
                ChoiceQuestionView(
                    prompt: ScreeningCopy.universalFollowUp,
                    options: YesNo.allCases,
                    mode: .single,
                    selection: universalFollowUpBinding,
                    optionTitle: yesNoTitle
                )
                .padding(.bottom, RithamSpacing.md)
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .conditionChecklist)
            }
        }
    }

    private func yesNoTitle(_ option: YesNo) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }

    /// The section's row list: a top divider, the "None of these apply" row first (Variant B --
    /// one more mutually-exclusive row, not a header-side control), then every condition row,
    /// each followed by its own divider. `spacing: 0` because the divider itself is what
    /// separates rows -- an additional VStack gap would double up with it.
    private func rowList(for group: Group) -> some View {
        let noneApplies = checklistBinding.wrappedValue.noneConfirmedCategories.isSuperset(of: group.categories)

        return VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(RithamColor.paper.opacity(0.14))

            checkRow(
                title: ScreeningCopy.conditionChecklistNoneRowTitle,
                isSelected: noneApplies,
                accessibilityLabel: "None of these \(group.title) conditions apply"
            ) {
                let willConfirmNone = !noneApplies
                checklistBinding.wrappedValue.toggleNoneForSection(group.categories, sectionItems: Set(group.items))
                if willConfirmNone {
                    AccessibilityNotification.Announcement(
                        "None confirmed. Cleared any selections in \(group.title)."
                    ).post()
                }
            }

            ForEach(group.items) { item in
                checkRow(
                    title: item.displayName,
                    isSelected: checklistBinding.wrappedValue.items.contains(item),
                    accessibilityLabel: nil
                ) {
                    checklistBinding.wrappedValue.toggle(item)
                }
            }
        }
    }

    /// A native-iOS-style list row: label leading, a trailing checkmark that only renders when
    /// `isSelected` (opacity-toggled rather than conditionally inserted/removed, so the row's own
    /// height never shifts when selection state flips). Checkmark aligns to the first line of a
    /// wrapped, multi-line label (e.g. "Heart disease (including a prior heart attack, heart
    /// failure, coronary artery disease, or a cardiac surgery/procedure)") via `alignment: .top`,
    /// not the default `.center`, matching the same fix already applied to this row shape before
    /// (live-review feedback, 2026-09-02).
    ///
    /// The "None" row renders identically to every condition row (same weight, same full-opacity
    /// paper color) -- live-review feedback (2026-09-03): an earlier version dimmed its label to
    /// distinguish it, and at reduced opacity against the charcoal background it read as a
    /// rendering glitch/wrong font rather than an intentional style, not the subtle de-emphasis
    /// it was going for. It's already distinguished by being first in the list and by its own
    /// distinct text -- no separate treatment needed, per Variant B's whole point of it being one
    /// more ordinary row.
    private func checkRow(
        title: String,
        isSelected: Bool,
        accessibilityLabel: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: RithamSpacing.md) {
                Text(title)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(RithamColor.hot)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, RithamSpacing.sm + 5)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .overlay(alignment: .bottom) {
            Divider().overlay(RithamColor.paper.opacity(0.14))
        }
    }
}
