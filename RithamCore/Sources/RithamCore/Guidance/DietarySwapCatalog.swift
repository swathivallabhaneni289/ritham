// Transcribed from docs/dietary-pattern.md section 3 (Protein & Food-Source Swap Table) and
// section 4 (Nutrient-Awareness Education Blocks). Every example-food list and nutrient note
// below is transcribed rather than paraphrased (HEALTH-01 forbids live-generated advice). The
// three swap-table cells section 3 flags with a footnote as Ritham's own construction (not a
// directly published substitution) are marked `isRithamOwnConstruction: true` here and are
// pending LAUNCH-03 dietitian sign-off; the rest ship as-is per the roadmap's own sequencing
// (Phase 5 gates the review, not this plan's build).
//
// `swaps(for:pattern:)` (DIET-02) and `educationBlock(for:)` (DIET-03) are deliberately two
// separate entry points and must never be merged behind one visibility check. Per
// dietary-pattern.md section 2's worked vegan-plus-kidney-disease example, a `required-blocking`
// nutrition gate has no personalized food content left for a dietary preference to flavor, so
// `swaps` is gate-conditional. The education blocks, by contrast, are general plant-based
// nutrition education "shown identically whether or not the user also has a condition flagged"
// (section 4's own header) -- `educationBlock(for:)` therefore takes no condition tag and
// consults no gate at all, so no future edit can accidentally make DIET-03 disappear behind a
// nutrition gate the way 02-RESEARCH.md's Anti-Patterns entry warns against.

/// The four existing Nutrition Adjustment Rule Table rows the swap table maps food examples
/// onto, per dietary-pattern.md section 3.
public enum NutritionRow: Sendable, CaseIterable {
    case baseline
    case diabetesPlateMethod
    case hypertensionDASH
    case heartDiseaseAHA
}

/// One resolved cell of the section 3 swap table: which row, which dietary pattern, which
/// example foods, and whether the document flags that specific cell as Ritham's own
/// construction rather than a directly sourced substitution.
public struct FoodSwap: Sendable, Equatable {
    public let row: NutritionRow
    public let pattern: DietaryPattern
    public let exampleFoods: [String]
    public let isRithamOwnConstruction: Bool

    public init(row: NutritionRow, pattern: DietaryPattern, exampleFoods: [String], isRithamOwnConstruction: Bool) {
        self.row = row
        self.pattern = pattern
        self.exampleFoods = exampleFoods
        self.isRithamOwnConstruction = isRithamOwnConstruction
    }
}

/// One nutrient's transcribed education note, as listed in a section 4 education block.
public struct NutrientNote: Sendable, Equatable {
    public let nutrient: String
    public let body: String

    public init(nutrient: String, body: String) {
        self.nutrient = nutrient
        self.body = body
    }
}

/// A full section 4 nutrient-awareness education block for one dietary pattern: a heading, an
/// ordered list of nutrient notes, and the closing paragraph (protein for vegan; protein plus
/// the calcium/vitamin-D/iodine framing note for vegetarian).
public struct NutrientEducationBlock: Sendable, Equatable {
    public let heading: String
    public let notes: [NutrientNote]
    public let closingProteinParagraph: String

    public init(heading: String, notes: [NutrientNote], closingProteinParagraph: String) {
        self.heading = heading
        self.notes = notes
        self.closingProteinParagraph = closingProteinParagraph
    }
}

public enum DietarySwapCatalog {

    /// Maps a `ConditionTag` to the section 3 swap-table row that applies, or `nil` for a tag
    /// with no mapped row (dietary-pattern.md section 3 only defines four rows; every other
    /// condition tag has no food-swap content regardless of its nutrition permission).
    private static func nutritionRow(for tag: ConditionTag) -> NutritionRow? {
        switch tag {
        case .noneOfTheAboveBaseline:
            return .baseline
        case .diabetesOnHypoglycemiaRiskMedication, .diabetesNotOnHypoglycemiaRiskMedication,
             .diabetesRetinopathyOrFootComplication, .prediabetes:
            return .diabetesPlateMethod
        case .hypertensionManaged, .hypertensionUncontrolledOrUnsure:
            return .hypertensionDASH
        case .heartDiseaseStable, .heartDiseaseRecentEventOrSymptomatic:
            return .heartDiseaseAHA
        default:
            return nil
        }
    }

    /// The section 3 example-food list and Ritham-own-construction flag for a row and pattern,
    /// verbatim from the table (dash-rewritten to plain punctuation per this file's header
    /// discipline). The vegetarian and vegan cells under `diabetesPlateMethod`, `hypertensionDASH`,
    /// and `heartDiseaseAHA` carry footnotes 1, 2, and 3 respectively, each marking the swap as
    /// Ritham's own construction rather than a directly published substitution; `baseline` carries
    /// no such footnote.
    private static func exampleFoods(for row: NutritionRow, pattern: DietaryPattern) -> (foods: [String], isRithamOwnConstruction: Bool) {
        switch row {
        case .baseline:
            switch pattern {
            case .none:
                return (["chicken breast", "turkey", "lean beef", "fish", "eggs", "dairy"], false)
            case .vegetarian:
                return (["eggs", "Greek yogurt", "cottage cheese", "milk", "lentils", "chickpeas", "black beans", "tofu", "tempeh"], false)
            case .vegan:
                return (
                    ["lentils", "chickpeas", "black beans", "kidney beans", "tofu", "tempeh", "edamame", "seitan", "almonds", "peanuts", "pumpkin seeds", "fortified soy products"],
                    false
                )
            }
        case .diabetesPlateMethod:
            switch pattern {
            case .none:
                return (["chicken breast", "turkey", "fish", "lean beef", "eggs", "low-fat cottage cheese"], false)
            case .vegetarian:
                return (["eggs", "low-fat cottage cheese or Greek yogurt", "tofu", "tempeh", "lentils", "chickpeas", "black beans"], true)
            case .vegan:
                return (["tofu", "tempeh", "edamame", "seitan", "lentils", "chickpeas", "black beans", "kidney beans", "nuts and seeds in modest portions"], true)
            }
        case .hypertensionDASH:
            switch pattern {
            case .none:
                return (["chicken breast", "fish (e.g., salmon)", "lean beef", "low-fat dairy"], false)
            case .vegetarian:
                return (["low-fat dairy", "eggs", "beans", "lentils", "nuts"], true)
            case .vegan:
                return (["beans", "lentils", "chickpeas", "tofu", "walnuts", "almonds", "pumpkin seeds"], true)
            }
        case .heartDiseaseAHA:
            switch pattern {
            case .none:
                return (["skinless poultry", "fish (especially fatty fish like salmon)", "lean cuts of meat", "eggs in moderation"], false)
            case .vegetarian:
                return (["eggs", "low-fat dairy", "tofu", "tempeh", "legumes", "walnuts", "almonds", "ground flaxseed", "chia seeds"], true)
            case .vegan:
                return (["tofu", "tempeh", "edamame", "legumes", "walnuts", "almonds", "ground flaxseed", "chia seeds", "canola or soybean oil for cooking"], true)
            }
        }
    }

    /// DIET-02: the food-swap lookup, gate-conditional on the nutrition content permission.
    /// Consults `GuidanceCatalog.contentPermission(for:domain:)` first and returns an empty
    /// array whenever that permission is `.none`, per section 3's rule that a blocking row shows
    /// no food content of any kind regardless of dietary pattern. Also returns an empty array
    /// for any tag with no mapped section 3 row, independent of its permission.
    public static func swaps(for tag: ConditionTag, pattern: DietaryPattern) -> [FoodSwap] {
        guard GuidanceCatalog.contentPermission(for: tag, domain: .nutrition) != .none else {
            return []
        }
        guard let row = nutritionRow(for: tag) else {
            return []
        }
        let entry = exampleFoods(for: row, pattern: pattern)
        return [FoodSwap(row: row, pattern: pattern, exampleFoods: entry.foods, isRithamOwnConstruction: entry.isRithamOwnConstruction)]
    }

    private static let veganEducationBlock = NutrientEducationBlock(
        heading: "Eating vegan? A few nutrients are worth extra attention.",
        notes: [
            NutrientNote(
                nutrient: "Vitamin B12",
                body: """
                Found naturally only in animal foods, so this is the one nutrient nearly every vegan needs a deliberate plan for. Good sources: fortified nutritional yeast, fortified breakfast cereals, and a B12 supplement. Many vegans use one as a matter of course, not as a backup plan.
                """
            ),
            NutrientNote(
                nutrient: "Iron",
                body: """
                Plant iron (non-heme) absorbs less efficiently than the iron in meat; a fully plant-based diet needs roughly 1.8x the iron intake of a diet that includes meat to land in the same place. Good sources: lentils, spinach, tofu, chickpeas, kidney beans, cashews, fortified grains/cereals. Pairing these with a vitamin-C-rich food (citrus, peppers, tomatoes) helps absorption.
                """
            ),
            NutrientNote(
                nutrient: "Zinc",
                body: """
                Legumes and whole grains contain phytates that bind zinc and reduce how much your body absorbs. Good sources: pumpkin seeds, lentils, peanuts, whole wheat bread, kidney beans. Soaking beans, grains, and seeds before cooking can help.
                """
            ),
            NutrientNote(
                nutrient: "Omega-3 (EPA/DHA)",
                body: """
                Flaxseed, chia, walnuts, and canola/soybean oil provide a plant omega-3 (ALA), but your body converts less than 15% of it into the long-chain EPA/DHA forms it actually uses. An algal-oil supplement is the most direct plant-based way to get EPA/DHA, worth asking a doctor or dietitian about, especially during pregnancy.
                """
            ),
            NutrientNote(
                nutrient: "Calcium",
                body: """
                Without dairy, this takes more deliberate planning. Good sources: kale, broccoli, bok choy, fortified soy or almond milk, calcium-set tofu, fortified orange juice or cereal. (Spinach is high in calcium on a label but a poor real-world source, oxalates block most of it from actually absorbing.)
                """
            ),
            NutrientNote(
                nutrient: "Vitamin D",
                body: """
                Without fortified dairy, plant sources are limited. Good sources: UV-treated mushrooms, fortified plant milks; a lichen-derived vegan D3 supplement is available and raises blood levels more effectively than D2.
                """
            ),
            NutrientNote(
                nutrient: "Iodine",
                body: """
                Seafood, eggs, and dairy are the main dietary sources, and a vegan diet excludes all three. Iodized salt is the most reliable everyday source; seaweed also contains iodine, but in wildly inconsistent amounts, so it isn't a dependable substitute on its own.
                """
            ),
        ],
        closingProteinParagraph: """
        On protein specifically: you don't need to pair "complete" proteins in the same meal (the classic rice-and-beans-together idea). Eating a variety of plant proteins, beans, lentils, tofu, tempeh, nuts, seeds, whole grains, across the day covers what your body needs. A few, like quinoa and chia, are already complete proteins on their own.
        """
    )

    private static let vegetarianEducationBlock = NutrientEducationBlock(
        heading: "Eating vegetarian? A couple of nutrients are worth a little extra attention.",
        notes: [
            NutrientNote(
                nutrient: "Vitamin B12",
                body: """
                Dairy and eggs give you some coverage, but a vegetarian diet still carries a higher deficiency risk than one that includes meat. Fortified cereals and nutritional yeast are easy to add, and it's worth mentioning to a doctor if dairy and eggs aren't a regular part of your diet either.
                """
            ),
            NutrientNote(
                nutrient: "Iron",
                body: """
                Plant iron (non-heme) absorbs less efficiently than the iron in meat, and dairy/eggs don't change that math. A vegetarian diet needs roughly 1.8x the iron of a diet that includes meat. Lentils, spinach, tofu, chickpeas, kidney beans, cashews, and fortified grains are good sources; pairing with a vitamin-C-rich food helps absorption.
                """
            ),
            NutrientNote(
                nutrient: "Zinc",
                body: """
                Legumes and whole grains contain phytates that reduce absorption, so vegetarians run a bit lower here too. Pumpkin seeds, lentils, peanuts, whole wheat bread, and kidney beans are good sources.
                """
            ),
            NutrientNote(
                nutrient: "Omega-3 (EPA/DHA)",
                body: """
                Unless you eat fish, flax/chia/walnuts only convert to the long-chain forms your body uses at a rate below 15%. An algal-oil supplement is worth a conversation with your doctor.
                """
            ),
        ],
        closingProteinParagraph: """
        Calcium, vitamin D, and iodine aren't called out here the way they are for vegans, dairy and eggs cover most of what those three nutrients need for most people, which is the main nutritional difference between a vegetarian and a vegan diet. And between dairy, eggs, and a variety of plant proteins across the day, protein adequacy generally isn't a concern, no need to pair specific plant proteins at the same meal for a "complete" protein either.
        """
    )

    /// DIET-03: the nutrient-awareness education block for a dietary pattern. Takes no condition
    /// tag and consults no gate at all -- its signature is the enforcement, since a function that
    /// cannot see a tag can never be edited to gate on one. Returns `nil` only for `.none`, the
    /// pattern meaning no dietary preference.
    public static func educationBlock(for pattern: DietaryPattern) -> NutrientEducationBlock? {
        switch pattern {
        case .none:
            return nil
        case .vegetarian:
            return vegetarianEducationBlock
        case .vegan:
            return veganEducationBlock
        }
    }

    /// Section 5's disclaimer, transcribed verbatim.
    public static let disclaimer: String = """
    Dietary Pattern guidance is general plant-based nutrition education, not an individualized meal plan, and it's not a substitute for a registered dietitian, especially if you're vegan and also managing a health condition Ritham has flagged, where the two may need to be balanced by a professional in ways general education alone can't safely cover.
    """
}
