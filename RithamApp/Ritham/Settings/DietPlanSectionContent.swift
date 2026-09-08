import SwiftUI
import RithamCore

/// The DIET-01-isolated subset of `DietPlanView`, extracted so it can be embedded directly on the
/// dashboard (D-05) as well as inside the Settings-presented `DietPlanView`. Deliberately excludes
/// the food-allergy screening checkbox and its severity follow-up -- those call
/// `GateResolution.resolve`/`saveScreeningResult` against `flow.answers.screening`, which is empty
/// on every fresh app launch now that `OnboardingRootView` roots straight at `.home` for a
/// returning user; embedding that control here would risk silently wiping real condition-tag data
/// the first time a returning user touched it (04-RESEARCH.md Pitfall 3, D-05's narrowing).
///
/// No `dismiss()`/"Done" control exists anywhere in this file (04-RESEARCH.md Pitfall 5): an
/// always-visible dashboard section has no modal to close, and `dismiss()` silently no-ops outside
/// a presentation context.
///
/// The only persistence call sites in this file are `store.updateProfile(` (via `DietPatternPicker`)
/// and `store.saveFoodAllergens(` (via `AllergenPicker`) -- neither ever re-resolves or re-saves a
/// screening result, and neither ever touches `GateResolution`.

/// Hydrates from and persists to `HealthDataStore.updateProfile`. Each write goes through a
/// computed `Binding` whose setter both assigns `selection` and persists -- not `.onChange(of:)`,
/// which would fire on the render pass following hydration's own `selection` write, after
/// `hasHydrated` has already flipped `true`, making an `onChange`-based guard unable to
/// distinguish a hydration write from a genuine user tap. A custom `Binding`'s setter only ever
/// runs when something actually commits a new selection through it, so it persists only on real
/// user input, by construction.
struct DietPatternPicker: View {
    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var selection: Set<DietaryPattern> = []
    @State private var hasHydrated = false
    @State private var showSaveError = false

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: dietSelectionBinding,
                optionTitle: dietOptionTitle
            )

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: hydrateIfNeeded)
    }

    private var dietSelectionBinding: Binding<Set<DietaryPattern>> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                guard let chosen = newValue.first else { return }
                flow.answers.dietaryPattern = chosen
                persistDiet(chosen)
            }
        )
    }

    /// Hydrates from the device store, guarded so a re-appearance never clobbers an
    /// in-progress selection. Reads (in order) the store, then `flow.answers.dietaryPattern`,
    /// then `.none` -- `loadProfile()` throws on an empty store, so the read is `try?`-tolerant,
    /// matching `MomentumSummaryReader`'s existing tolerance for the same condition. Assigns
    /// `selection` directly, never through `dietSelectionBinding`, so hydration never persists.
    private func hydrateIfNeeded() {
        guard !hasHydrated else { return }
        let store = HealthDataStore(context: modelContext)
        let stored = (try? store.loadProfile())?.dietaryPattern
        let resolved = stored ?? flow.answers.dietaryPattern ?? .none
        selection = [resolved]
        hasHydrated = true
    }

    private func dietOptionTitle(_ pattern: DietaryPattern) -> String {
        switch pattern {
        case .none: return OnboardingCopy.Diet.optionNone
        case .vegetarian: return OnboardingCopy.Diet.optionVegetarian
        case .vegan: return OnboardingCopy.Diet.optionVegan
        }
    }

    /// DIET-01: no expiry, no re-screen. Never calls `GateResolution` and never invalidates a
    /// condition tag -- a dietary preference must never loosen (or otherwise touch) a safety
    /// gate. A small improvement on `DietPlanView`'s original silent `try?`: a failed persist
    /// here sets `showSaveError`, required by 04-UI-SPEC.md's diet-section error state.
    private func persistDiet(_ pattern: DietaryPattern) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        do {
            try store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}

/// Same shape and isolation discipline as `DietPatternPicker`, persisting through
/// `HealthDataStore.saveFoodAllergens` alone -- never touching `GateResolution`/condition-tag
/// records.
struct AllergenPicker: View {
    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var selection: Set<FoodAllergen> = []
    @State private var hasHydrated = false
    @State private var showSaveError = false

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.allergensHeadline,
                helper: OnboardingCopy.Diet.allergensHelper,
                options: FoodAllergen.allCases,
                mode: .multiple(exclusiveOption: nil),
                selection: allergenSelectionBinding,
                optionTitle: allergenOptionTitle
            )

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: hydrateIfNeeded)
    }

    private var allergenSelectionBinding: Binding<Set<FoodAllergen>> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                flow.answers.allergens = newValue
                persistAllergens(newValue)
            }
        )
    }

    /// Same hydration discipline as `DietPatternPicker.hydrateIfNeeded`: store, then
    /// `flow.answers.allergens`, then the empty set; assigned directly, never through
    /// `allergenSelectionBinding`.
    private func hydrateIfNeeded() {
        guard !hasHydrated else { return }
        let store = HealthDataStore(context: modelContext)
        let stored = try? store.loadFoodAllergens()
        selection = stored ?? flow.answers.allergens
        hasHydrated = true
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

    /// Same isolation as `DietPatternPicker.persistDiet`: saved through
    /// `HealthDataStore.saveFoodAllergens` alone, never touching `GateResolution`/condition-tag
    /// records.
    private func persistAllergens(_ allergens: Set<FoodAllergen>) {
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveFoodAllergens(allergens)
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}

/// The single symbol the dashboard embeds (D-05, plan 04-02): both DIET-01-isolated pickers,
/// stacked in the same order `DietPlanView` renders them in today.
struct DietPlanSectionContent: View {
    let flow: OnboardingFlow

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            DietPatternPicker(flow: flow)
            AllergenPicker(flow: flow)
        }
    }
}
