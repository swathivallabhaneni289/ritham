import Testing
@testable import RithamCore

@Suite("DietarySwapCatalogTests")
struct DietarySwapCatalogTests {

    @Test("swaps and educationBlock resolve without trapping across every tag and pattern")
    func noAccessorTrapsAcrossEveryTagAndPattern() {
        for tag in ConditionTag.allCases {
            for pattern in DietaryPattern.allCases {
                _ = DietarySwapCatalog.swaps(for: tag, pattern: pattern)
            }
        }
        for pattern in DietaryPattern.allCases {
            _ = DietarySwapCatalog.educationBlock(for: pattern)
        }
        #expect(!DietarySwapCatalog.disclaimer.isEmpty)
    }

    @Test("swaps returns example foods for each of the four mapped nutrition rows, for each dietary pattern")
    func swapsReturnsExampleFoodsForEveryMappedRowAndPattern() {
        let representativeTags: [ConditionTag] = [
            .noneOfTheAboveBaseline,
            .diabetesNotOnHypoglycemiaRiskMedication,
            .hypertensionManaged,
            .heartDiseaseStable,
        ]
        for tag in representativeTags {
            for pattern in DietaryPattern.allCases {
                let result = DietarySwapCatalog.swaps(for: tag, pattern: pattern)
                #expect(!result.isEmpty)
                #expect(!(result.first?.exampleFoods.isEmpty ?? true))
            }
        }
    }

    @Test("swaps is empty for a tag whose nutrition permission is zero-content, in the same test that educationBlock is non-nil")
    func swapsEmptyVersusEducationBlockNonNilForZeroContentTag() {
        #expect(GuidanceCatalog.contentPermission(for: .kidneyDiseaseOrDialysis, domain: .nutrition) == .none)
        #expect(DietarySwapCatalog.swaps(for: .kidneyDiseaseOrDialysis, pattern: .vegan).isEmpty)

        let block = DietarySwapCatalog.educationBlock(for: .vegan)
        #expect(block != nil)
        #expect(block == DietarySwapCatalog.educationBlock(for: .vegan))
    }

    @Test("swaps is empty regardless of dietary pattern for a zero-content nutrition tag")
    func swapsEmptyForEveryPatternOnZeroContentTag() {
        for pattern in DietaryPattern.allCases {
            #expect(DietarySwapCatalog.swaps(for: .kidneyDiseaseOrDialysis, pattern: pattern).isEmpty)
        }
    }

    @Test("the vegan education block names all seven nutrients; the vegetarian block names its four")
    func educationBlockNutrientCounts() {
        let vegan = DietarySwapCatalog.educationBlock(for: .vegan)
        #expect(vegan?.notes.count == 7)

        let vegetarian = DietarySwapCatalog.educationBlock(for: .vegetarian)
        #expect(vegetarian?.notes.count == 4)
    }

    @Test("educationBlock returns nothing for the pattern representing no dietary preference")
    func educationBlockNilForNoPreference() {
        #expect(DietarySwapCatalog.educationBlock(for: .none) == nil)
    }

    @Test("educationBlock returns identical text for a given pattern regardless of context")
    func educationBlockIsStable() {
        let first = DietarySwapCatalog.educationBlock(for: .vegan)
        let second = DietarySwapCatalog.educationBlock(for: .vegan)
        #expect(first == second)
    }

    @Test("at least one FoodSwap reports the Ritham-own-construction flag, matching the document's flagged cells")
    func atLeastOneFoodSwapIsFlaggedAsRithamOwnConstruction() {
        let swaps = DietarySwapCatalog.swaps(for: .hypertensionManaged, pattern: .vegan)
        #expect(swaps.contains { $0.isRithamOwnConstruction })
    }

    @Test("the baseline row's swaps are not flagged as Ritham's own construction")
    func baselineSwapsAreNotFlagged() {
        let swaps = DietarySwapCatalog.swaps(for: .noneOfTheAboveBaseline, pattern: .vegan)
        #expect(swaps.allSatisfy { !$0.isRithamOwnConstruction })
    }

    @Test("educationBlock's signature carries no ConditionTag or gate parameter")
    func educationBlockSignatureIsGateBlind() {
        // Compile-time assertion: this call only accepts a DietaryPattern.
        let result: NutrientEducationBlock? = DietarySwapCatalog.educationBlock(for: .vegetarian)
        #expect(result != nil)
    }
}
