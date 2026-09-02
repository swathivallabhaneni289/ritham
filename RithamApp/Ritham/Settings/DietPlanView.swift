import SwiftUI
import RithamCore

/// The diet plan, opened from Settings as its own screen rather than shown inline there --
/// direct product feedback (2026-09-01): the dietary-pattern picker and the allergies picker for
/// it belong together in one screen the user opens, not spilled across Settings' main list.
///
/// The food-allergy questions live here in full now, not split across this screen and the health
/// screening checklist -- further live-review feedback (2026-09-02): the checklist only ever
/// asked a bare "I have one or more food allergies" with no way to say which ones right there,
/// and having that fact live on the screening page while its detail lived here read as pointless.
/// So the whole allergy question set moved: whether the user has one, whether any is severe
/// (FA-1's mandatory-verification safety flag -- see `TagDerivation.foodAllergyTags` and
/// `GateEscalation.requiresIndependentAllergenVerification`, both still fed from here, byte-for-
/// byte unchanged), and which specific ones (`FoodAllergen`, diet-suggestion preference only).
/// `ConditionChecklistView`/`SeverityFollowUpView` no longer render any food-allergy question at
/// all -- see their own header comments.
///
/// This makes the boolean-and-severity pair here a genuine exception to `DietaryPattern`/
/// `FoodAllergen`'s DIET-01-style isolation: unlike those two (still saved through
/// `HealthDataStore.updateProfile`/`saveFoodAllergens` alone, never touching gate resolution),
/// `checklistBinding`/`severitySelection` changes call `GateResolution.resolve` and
/// `HealthDataStore.saveScreeningResult` -- the same re-resolve `EditAnswerFlow` runs for any
/// other screening edit -- because they are still real screening answers (`ChecklistItem
/// .foodAllergies`, `ScreeningAnswers.fa1SevereAllergyOrEpinephrine`) that feed a real safety tag;
/// only where they are asked moved, not what they mean. Same KNOWN LIMITATION as `EditAnswerFlow`
/// (its own doc comment): this requires the same `OnboardingFlow` instance whose
/// `answers.screening` already holds the user's other screening answers in memory, or the
/// re-resolve silently wipes them.
struct DietPlanView: View {
    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dietSelection: Set<DietaryPattern>
    @State private var severitySelection: Set<YesNoUnsure>
    @State private var allergenSelection: Set<FoodAllergen>
    @State private var showSaveError = false

    init(flow: OnboardingFlow) {
        self.flow = flow
        _dietSelection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
        _severitySelection = State(initialValue: flow.answers.screening.fa1SevereAllergyOrEpinephrine.map { [$0] } ?? [])
        _allergenSelection = State(initialValue: flow.answers.allergens)
    }

    /// Every write through this binding re-resolves and re-saves the screening result (see this
    /// type's own header comment) -- correct because this binding backs exactly one control
    /// below, the food-allergy checkbox, so any write through it is a real screening-answer
    /// change, never a diet-preference one.
    private var checklistBinding: Binding<ChecklistSelection> {
        Binding(
            get: { flow.answers.screening.checklist },
            set: { newValue in
                flow.answers.screening.checklist = newValue
                resolveAndSaveScreening()
            }
        )
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Diet plan") {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: $dietSelection,
                optionTitle: dietOptionTitle
            )

            ChoiceQuestionView(
                prompt: ChecklistItem.foodAllergies.displayName,
                options: [ChecklistItem.foodAllergies],
                checklistSelection: checklistBinding,
                optionTitle: { $0.displayName }
            )

            if flow.answers.screening.checklist.items.contains(.foodAllergies) {
                ChoiceQuestionView(
                    prompt: ScreeningCopy.FollowUp.fa1,
                    options: YesNoUnsure.allCases,
                    mode: .single,
                    selection: $severitySelection,
                    optionTitle: yesNoUnsureTitle
                )

                ChoiceQuestionView(
                    prompt: OnboardingCopy.Diet.allergensHeadline,
                    helper: OnboardingCopy.Diet.allergensHelper,
                    options: FoodAllergen.allCases,
                    mode: .multiple(exclusiveOption: nil),
                    selection: $allergenSelection,
                    optionTitle: allergenOptionTitle
                )
            }

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: "Done") {
                dismiss()
            }
        }
        .onChange(of: dietSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            flow.answers.dietaryPattern = chosen
            persistDiet(chosen)
        }
        .onChange(of: severitySelection) { _, newValue in
            flow.answers.screening.fa1SevereAllergyOrEpinephrine = newValue.first
            resolveAndSaveScreening()
        }
        .onChange(of: allergenSelection) { _, newValue in
            flow.answers.allergens = newValue
            persistAllergens(newValue)
        }
    }

    private func dietOptionTitle(_ pattern: DietaryPattern) -> String {
        switch pattern {
        case .none: return OnboardingCopy.Diet.optionNone
        case .vegetarian: return OnboardingCopy.Diet.optionVegetarian
        case .vegan: return OnboardingCopy.Diet.optionVegan
        }
    }

    private func yesNoUnsureTitle(_ option: YesNoUnsure) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        case .notSure: return "Not sure"
        }
    }

    private func allergenOptionTitle(_ allergen: FoodAllergen) -> String {
        switch allergen {
        case .milk: return OnboardingCopy.Diet.allergenOptionMilk
        case .eggs: return OnboardingCopy.Diet.allergenOptionEggs
        case .fish: return OnboardingCopy.Diet.allergenOptionFish
        case .shellfish: return OnboardingCopy.Diet.allergenOptionShellfish
        case .treeNuts: return OnboardingCopy.Diet.allergenOptionTreeNuts
        case .peanuts: return OnboardingCopy.Diet.allergenOptionPeanuts
        case .wheat: return OnboardingCopy.Diet.allergenOptionWheat
        case .soy: return OnboardingCopy.Diet.allergenOptionSoy
        case .sesame: return OnboardingCopy.Diet.allergenOptionSesame
        case .other: return OnboardingCopy.Diet.allergenOptionOther
        }
    }

    /// DIET-01: no expiry, no re-screen. Never calls `GateResolution` and never invalidates a
    /// condition tag -- a dietary preference must never loosen (or otherwise touch) a safety
    /// gate.
    private func persistDiet(_ pattern: DietaryPattern) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
    }

    /// Same isolation as `persistDiet` above: saved through `HealthDataStore.saveFoodAllergens`
    /// alone, never touching `GateResolution`/condition-tag records. Unlike `persistDiet`/this,
    /// `checklistBinding`/`severitySelection` deliberately do NOT stay isolated -- see this
    /// type's own header comment.
    private func persistAllergens(_ allergens: Set<FoodAllergen>) {
        let store = HealthDataStore(context: modelContext)
        try? store.saveFoodAllergens(allergens)
    }

    /// Re-resolves the complete screening result and persists it, exactly as `EditAnswerFlow`
    /// does for any other screening edit -- the food-allergy boolean and severity answer are real
    /// screening answers, not diet preferences, even though they are asked from this screen.
    private func resolveAndSaveScreening() {
        let result = GateResolution.resolve(
            answers: flow.answers.screening,
            ageDerivedTags: flow.answers.ageDerivedTags
        )
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveScreeningResult(result, answers: flow.answers.screening, now: Date())
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}
