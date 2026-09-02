import SwiftUI
import RithamCore

/// The diet plan, opened from Settings as its own screen rather than shown inline there --
/// direct product feedback (2026-09-01): the dietary-pattern picker and the allergies picker for
/// it belong together in one screen the user opens, not spilled across Settings' main list.
///
/// Both pickers still take effect immediately and persist independently through
/// `HealthDataStore`, exactly as they did when they lived inline in `SettingsView` -- this view
/// only changes where they live, never DIET-01's isolation from `GateResolution`/condition tags:
/// the `.onChange` handlers below may never call `GateResolution` or
/// `HealthDataStore.invalidateSection`, and they do not. `DietaryPattern`/`FoodAllergen`'s
/// `Identifiable` conformances live in `SettingsView.swift`, this view's sole other consumer.
struct DietPlanView: View {
    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dietSelection: Set<DietaryPattern>
    @State private var allergenSelection: Set<FoodAllergen>

    init(flow: OnboardingFlow) {
        self.flow = flow
        _dietSelection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
        _allergenSelection = State(initialValue: flow.answers.allergens)
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

            // Framed as its own block, separate from the dietary-pattern picker above, and shown
            // only once the health screening has already recorded a food allergy, so this never
            // re-asks "do you have one" itself.
            if flow.answers.screening.checklist.items.contains(.foodAllergies) {
                ChoiceQuestionView(
                    prompt: OnboardingCopy.Diet.allergensHeadline,
                    helper: OnboardingCopy.Diet.allergensHelper,
                    options: FoodAllergen.allCases,
                    mode: .multiple(exclusiveOption: nil),
                    selection: $allergenSelection,
                    optionTitle: allergenOptionTitle
                )
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
    /// alone, never touching `GateResolution`/condition-tag records.
    private func persistAllergens(_ allergens: Set<FoodAllergen>) {
        let store = HealthDataStore(context: modelContext)
        try? store.saveFoodAllergens(allergens)
    }
}
