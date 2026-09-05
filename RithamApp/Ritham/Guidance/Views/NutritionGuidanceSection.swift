import SwiftUI
import SwiftData
import RithamCore

/// HEALTH-04/DIET-02/DIET-03's nutrition section of `GuidanceView`. Renders, in order: the
/// nutrition banner (permission-checked general guidance), the applicable published reference
/// figures (each attributed to its publishing body), the dietary-pattern food-swap examples, and
/// the nutrient-education block for that pattern.
///
/// `swapSection` and `educationSection` are two independent view branches sharing no enclosing
/// condition. Per `DietarySwapCatalog`'s own header comment, `swaps(for:pattern:)` is
/// gate-conditional while `educationBlock(for:)` takes no tag and consults no gate at all --
/// wrapping both behind one shared `if` would silently make DIET-03's education block disappear
/// for every user carrying a blocking nutrition tag, which is exactly the anti-pattern
/// 02-RESEARCH.md names and this file must never reintroduce.
struct NutritionGuidanceSection: View {
    let context: GuidanceContext

    @Environment(\.modelContext) private var modelContext
    @State private var dietaryPattern: DietaryPattern?
    @State private var allergens: Set<FoodAllergen> = []

    private var permission: ContentPermission {
        context.permission(for: .nutrition)
    }

    private var governingTag: ConditionTag? {
        context.governingTag(for: .nutrition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.lg) {
            Text("Nutrition")
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            AdjustedGuidanceBanner(context: context, domain: .nutrition)
            referenceFiguresSection
            swapSection
            educationSection
        }
        .onAppear(perform: load)
    }

    // MARK: - Reference figures

    /// Every applicable published reference figure, each rendered with its publishing body's
    /// name so a user can see it is fixed, cited, population-level education -- never a number
    /// Ritham computed for them. Shown only when the nutrition permission allows content at all;
    /// `NutritionGuidanceCatalog.referenceFigures(for:)` never returns a personalized quantity in
    /// the first place, but this guard keeps the section from appearing at all under a required-
    /// blocking gate, matching HEALTH-04's "no quantity of any kind" requirement.
    @ViewBuilder
    private var referenceFiguresSection: some View {
        if let governingTag, permission != .none {
            let figures = NutritionGuidanceCatalog.referenceFigures(for: governingTag)
            if !figures.isEmpty {
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    ForEach(Array(figures.enumerated()), id: \.offset) { _, figure in
                        Text("\(figure.label): \(figure.value) (\(figure.publishingBody))")
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Food swaps (DIET-02)

    /// Gate-conditional on the nutrition content permission (enforced inside
    /// `DietarySwapCatalog.swaps` itself) and on a dietary pattern actually being recorded --
    /// `dietaryPattern == nil` means the user has never visited `DietPlanView`, which must show
    /// no swap content rather than defaulting silently to an omnivore pattern's own examples.
    @ViewBuilder
    private var swapSection: some View {
        if let dietaryPattern, let governingTag {
            let swaps = DietarySwapCatalog.swaps(for: governingTag, pattern: dietaryPattern)
            if !swaps.isEmpty {
                VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                    ForEach(swaps, id: \.row) { swap in
                        Text(swap.exampleFoods.joined(separator: ", "))
                            .font(RithamType.body)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    allergenNotice
                }
            }
        }
    }

    /// The stored food allergens, surfaced alongside food content since they've been captured
    /// since Phase 1 with no consumer until now, plus the standing "verify independently before
    /// eating" notice whenever the severe-allergen tag applies -- shown on every food-content
    /// surface, per section 3's mandatory-every-time flag.
    @ViewBuilder
    private var allergenNotice: some View {
        if !allergens.isEmpty {
            Text("Allergens you've noted: \(allergenLabels)")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
        if context.result.requiresIndependentAllergenVerification {
            Text("Verify independently before eating -- always check the label yourself, every time.")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.hot)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Nutrient education (DIET-03)

    /// Takes no condition tag and consults no gate at all: this section renders identically
    /// whether or not the nutrition permission is blocking, for the stored dietary pattern alone.
    /// `dietaryPattern == nil` (no dietary preference recorded at all) is the one case that shows
    /// nothing here, same as `swapSection` above -- everything else on the screen keeps working.
    @ViewBuilder
    private var educationSection: some View {
        if let dietaryPattern, let block = DietarySwapCatalog.educationBlock(for: dietaryPattern) {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text(block.heading)
                    .font(RithamType.body.weight(.semibold))
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(block.notes, id: \.nutrient) { note in
                    VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                        Text(note.nutrient)
                            .font(RithamType.body.weight(.semibold))
                        Text(note.body)
                            .font(RithamType.label)
                    }
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text(block.closingProteinParagraph)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Formatting

    private var allergenLabels: String {
        allergens.map(allergenLabel).sorted().joined(separator: ", ")
    }

    private func allergenLabel(_ allergen: FoodAllergen) -> String {
        switch allergen {
        case .milk: return "Milk"
        case .eggs: return "Eggs"
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        case .treeNuts: return "Tree nuts"
        case .peanuts: return "Peanuts"
        case .wheat: return "Wheat"
        case .soy: return "Soy"
        case .sesame: return "Sesame"
        case .other: return "Other"
        }
    }

    // MARK: - Loading

    /// Reads the stored dietary pattern and food allergens once, from the same
    /// `HealthDataStore.loadProfile`/`loadFoodAllergens` accessors `DietPlanView` itself writes
    /// through -- this screen and `DietPlanView` therefore always agree on one value, never a
    /// second locally-cached copy of either.
    private func load() {
        let store = HealthDataStore(context: modelContext)
        dietaryPattern = (try? store.loadProfile())?.dietaryPattern
        allergens = (try? store.loadFoodAllergens()) ?? []
    }
}
