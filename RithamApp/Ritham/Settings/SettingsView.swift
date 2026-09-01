import SwiftUI
import SwiftData
import RithamCore

/// `EditAnswerFlow`/`SettingsView`'s first consumer of `EditableSection` as a `.sheet(item:)`
/// identity -- the same retroactive-`Identifiable` pattern `ChecklistItem`/`DietaryPattern`
/// already use at their own first UI-layer consumer.
extension EditableSection: @retroactive Identifiable {
    public var id: Self { self }
}

// DIET-01: `DietaryPattern` needs `Identifiable` to drive `ChoiceQuestionView`'s `ForEach`
// without a separate id parameter -- the same retroactive-conformance pattern above applies.
// `DietaryPattern` is already `Hashable` (raw-value-backed `CaseIterable` enums get that
// automatically); only `Identifiable` is missing. This conformance used to live in
// `DietaryPatternStepView.swift`, the onboarding screen for this question -- per direct product
// feedback (2026-08-29) that question moved out of onboarding entirely (see
// `OnboardingRouter`'s doc comment), making this view its sole remaining consumer.
extension DietaryPattern: @retroactive Identifiable {
    public var id: Self { self }
}

// Same reasoning as `DietaryPattern` above, for the allergens picker this view also renders.
extension FoodAllergen: @retroactive Identifiable {
    public var id: Self { self }
}

/// DIET-01's dietary-pattern choice, edited in place with immediate effect and no re-screen
/// consequence -- a downstream-of-the-gate concern (DIET-01's own isolation rule), so the
/// `.onChange` handler below may never call `GateResolution` or
/// `HealthDataStore.invalidateSection`, and it does not.
///
/// Also offers an entry point to the health profile, plus one per-section entry point for each
/// of the four screening sections (`.gateSection`, `.conditionChecklist`, `.severityFollowUps`,
/// `.scoff`), each routed through `EditAnswerFlow` as a `.sheet` -- D-09 scopes each of those
/// edits to its own section, never the whole questionnaire, and CROSSGEN-05 reserves the app's
/// one `NavigationStack` for `OnboardingRootView`, so a section edit here is always a sheet,
/// never a push.
struct SettingsView: View {
    let flow: OnboardingFlow
    var onOpenHealthProfile: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var dietSelection: Set<DietaryPattern>
    @State private var allergenSelection: Set<FoodAllergen>
    @State private var editingSection: EditableSection?
    @State private var isReScreenDue = false

    init(flow: OnboardingFlow, onOpenHealthProfile: @escaping () -> Void = {}) {
        self.flow = flow
        self.onOpenHealthProfile = onOpenHealthProfile
        _dietSelection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
        _allergenSelection = State(initialValue: flow.answers.allergens)
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Settings") {
            // D-07: shown when overdue, non-blocking, dismissible for the session. "Start
            // re-screen" opens the gate section -- the first screen of the real screening --
            // through the same section-scoped `EditAnswerFlow` every other entry point here
            // uses; this plan builds no separate full-questionnaire restart wizard.
            ReScreenBanner(isReScreenDue: isReScreenDue) {
                editingSection = .gateSection
            }

            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: $dietSelection,
                optionTitle: dietOptionTitle
            )

            // Framed as its own block, separate from the dietary-pattern picker above -- direct
            // product feedback (2026-09-01) -- and shown only once the health screening has
            // already recorded a food allergy, so this never re-asks "do you have one" itself.
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

            SecondaryCTAButton(title: "Health profile", action: onOpenHealthProfile)

            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Screening answers")
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)

                sectionEntryPoint(.gateSection, title: "Health questions")
                sectionEntryPoint(.conditionChecklist, title: "Condition checklist")
                sectionEntryPoint(.severityFollowUps, title: "Follow-up questions")
                sectionEntryPoint(.scoff, title: "Eating-pattern questions")
            }
        }
        .onAppear(perform: refreshReScreenDue)
        .onChange(of: dietSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            flow.answers.dietaryPattern = chosen
            persistDiet(chosen)
        }
        .onChange(of: allergenSelection) { _, newValue in
            flow.answers.allergens = newValue
            persistAllergens(newValue)
        }
        .sheet(item: $editingSection) { section in
            EditAnswerFlow(flow: flow, section: section)
                .onDisappear(perform: refreshReScreenDue)
        }
    }

    private func sectionEntryPoint(_ section: EditableSection, title: String) -> some View {
        SecondaryCTAButton(title: title) {
            editingSection = section
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

    private func refreshReScreenDue() {
        let store = HealthDataStore(context: modelContext)
        isReScreenDue = (try? store.isReScreenDue(now: Date())) ?? false
    }
}
