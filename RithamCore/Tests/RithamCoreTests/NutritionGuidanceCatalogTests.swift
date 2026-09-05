import Testing
@testable import RithamCore

@Suite("NutritionGuidanceCatalogTests")
struct NutritionGuidanceCatalogTests {

    @Test("every ConditionTag's guidance accessors resolve without trapping")
    func noAccessorTrapsAcrossEveryTag() {
        for tag in ConditionTag.allCases {
            _ = NutritionGuidanceCatalog.generalGuidance(for: tag)
            _ = NutritionGuidanceCatalog.mustNotDo(for: tag)
            _ = NutritionGuidanceCatalog.presentableGuidance(for: tag)
            _ = NutritionGuidanceCatalog.referenceFigures(for: tag)
            _ = NutritionGuidanceCatalog.requiresIndependentAllergenVerification(tag)
        }
        #expect(!NutritionGuidanceCatalog.referralMessage.isEmpty)
    }

    @Test("kidneyDiseaseOrDialysis presents the referral message, matching its zero-content nutrition permission")
    func kidneyDiseasePresentsReferral() {
        #expect(
            NutritionGuidanceCatalog.presentableGuidance(for: .kidneyDiseaseOrDialysis)
                == NutritionGuidanceCatalog.referralMessage
        )
        #expect(GuidanceCatalog.contentPermission(for: .kidneyDiseaseOrDialysis, domain: .nutrition) == .none)
    }

    @Test("presentableGuidance returns the referral message, not row prose, for every none-permission nutrition tag")
    func nonePermissionTagsAlwaysPresentReferral() {
        for tag in ConditionTag.allCases where GuidanceCatalog.contentPermission(for: tag, domain: .nutrition) == .none {
            #expect(NutritionGuidanceCatalog.presentableGuidance(for: tag) == NutritionGuidanceCatalog.referralMessage)
        }
    }

    @Test("under18Minor yields general education text with no numeric quantity, matching its educationOnly permission")
    func under18MinorYieldsEducationOnlyText() {
        #expect(GuidanceCatalog.contentPermission(for: .under18Minor, domain: .nutrition) == .educationOnly)
        let guidance = NutritionGuidanceCatalog.generalGuidance(for: .under18Minor)
        #expect(guidance == "General movement and food-variety education only.")
        #expect(guidance?.contains(where: \.isNumber) == false)
    }

    @Test("noneOfTheAboveBaseline yields full, non-referral guidance text")
    func baselineYieldsFullGuidanceText() {
        let presented = NutritionGuidanceCatalog.presentableGuidance(for: .noneOfTheAboveBaseline)
        #expect(presented != NutritionGuidanceCatalog.referralMessage)
        #expect(presented == NutritionGuidanceCatalog.generalGuidance(for: .noneOfTheAboveBaseline))
    }

    @Test("severeFoodAllergy requires independent verification; the baseline tag does not")
    func severeFoodAllergyRequiresVerification() {
        #expect(NutritionGuidanceCatalog.requiresIndependentAllergenVerification(.severeFoodAllergy))
        #expect(!NutritionGuidanceCatalog.requiresIndependentAllergenVerification(.noneOfTheAboveBaseline))
    }

    @Test("weightLossFeatureAvailable is false whenever GateEscalation.weightLossFeatureGate reports a blocking gate")
    func weightLossFeatureAvailableFollowsTheGateFunction() {
        #expect(NutritionGuidanceCatalog.weightLossFeatureAvailable(tags: [.under18Minor], goalBelowHealthyBMIFloor: false) == false)
        #expect(NutritionGuidanceCatalog.weightLossFeatureAvailable(tags: [.eatingDisorderPositiveScreen], goalBelowHealthyBMIFloor: false) == false)
        #expect(NutritionGuidanceCatalog.weightLossFeatureAvailable(tags: [], goalBelowHealthyBMIFloor: true) == false)
        #expect(NutritionGuidanceCatalog.weightLossFeatureAvailable(tags: [.noneOfTheAboveBaseline], goalBelowHealthyBMIFloor: false) == true)
    }

    @Test("reference figures are non-empty for the tags whose rows cite a published figure, and each names its publishing body")
    func referenceFiguresAreAttributedToAPublishingBody() {
        let hypertensionFigures = NutritionGuidanceCatalog.referenceFigures(for: .hypertensionManaged)
        #expect(hypertensionFigures.count == 2)
        for figure in hypertensionFigures {
            #expect(!figure.publishingBody.isEmpty)
            #expect(!figure.value.isEmpty)
        }

        let diabetesFigures = NutritionGuidanceCatalog.referenceFigures(for: .diabetesNotOnHypoglycemiaRiskMedication)
        #expect(diabetesFigures.count == 2)

        let prediabetesFigures = NutritionGuidanceCatalog.referenceFigures(for: .prediabetes)
        #expect(prediabetesFigures.count == 1)

        let heartDiseaseFigures = NutritionGuidanceCatalog.referenceFigures(for: .heartDiseaseStable)
        #expect(heartDiseaseFigures.count == 2)
    }

    @Test("reference figures are empty for a tag with no published figure cited in its row")
    func referenceFiguresEmptyForUnrelatedTag() {
        #expect(NutritionGuidanceCatalog.referenceFigures(for: .osteoarthritis).isEmpty)
        #expect(NutritionGuidanceCatalog.referenceFigures(for: .noneOfTheAboveBaseline).isEmpty)
    }

    @Test("mustNotDo returns nil for the rows section 3 marks with an em dash, not an empty string")
    func mustNotDoReturnsNilForEmDashRows() {
        let nilTags: [ConditionTag] = [
            .diabetesRetinopathyOrFootComplication,
            .nonSevereFoodAllergy,
            .noneOfTheAboveBaseline,
            .rateLimitingHeartOrBPMedication,
        ]
        for tag in nilTags {
            #expect(NutritionGuidanceCatalog.mustNotDo(for: tag) == nil)
        }
    }
}
