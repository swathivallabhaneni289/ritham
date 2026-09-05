import Testing
@testable import RithamCore

@Suite("GuidanceCatalogTests")
struct GuidanceCatalogTests {

    @Test("every ConditionTag has a declared permission for both domains")
    func everyTagHasADeclaredPermissionForBothDomains() {
        for tag in ConditionTag.allCases {
            for domain in GuidanceDomain.allCases {
                // Merely calling this must not trap; the switch inside must be exhaustive.
                _ = GuidanceCatalog.contentPermission(for: tag, domain: domain)
            }
        }
        #expect(ConditionTag.allCases.count * GuidanceDomain.allCases.count > 0)
    }

    @Test("permissions order none < educationOnly < full")
    func permissionOrdering() {
        #expect(ContentPermission.none < ContentPermission.educationOnly)
        #expect(ContentPermission.educationOnly < ContentPermission.full)
        #expect(ContentPermission.none < ContentPermission.full)
    }

    @Test("under18Minor is educationOnly for nutrition while kidneyDiseaseOrDialysis is none")
    func under18MinorVersusKidneyDisease() {
        #expect(GuidanceCatalog.contentPermission(for: .under18Minor, domain: .nutrition) == .educationOnly)
        #expect(GuidanceCatalog.contentPermission(for: .kidneyDiseaseOrDialysis, domain: .nutrition) == .none)
    }

    @Test("hypertensionUncontrolledOrUnsure is educationOnly for nutrition, not a mechanical function of its gate")
    func hypertensionUncontrolledIsEducationOnlyForNutrition() {
        #expect(GuidanceCatalog.contentPermission(for: .hypertensionUncontrolledOrUnsure, domain: .nutrition) == .educationOnly)
    }

    @Test("noneOfTheAboveBaseline is full for both domains")
    func baselineIsFullForBothDomains() {
        #expect(GuidanceCatalog.contentPermission(for: .noneOfTheAboveBaseline, domain: .workout) == .full)
        #expect(GuidanceCatalog.contentPermission(for: .noneOfTheAboveBaseline, domain: .nutrition) == .full)
    }

    @Test("resolvedPermission of an empty tag set is none, for both domains")
    func resolvedPermissionOfEmptySetIsNone() {
        #expect(GuidanceCatalog.resolvedPermission(for: [], domain: .nutrition) == .none)
        #expect(GuidanceCatalog.resolvedPermission(for: [], domain: .workout) == .none)
    }

    @Test("resolvedPermission folds a tag set to its most restrictive member, never an average or first match")
    func resolvedPermissionFoldsToMostRestrictive() {
        let tags: [ConditionTag] = [.noneOfTheAboveBaseline, .kidneyDiseaseOrDialysis, .under18Minor]
        #expect(GuidanceCatalog.resolvedPermission(for: tags, domain: .nutrition) == .none)
    }

    @Test("mostRestrictive of a mixed permission list returns none")
    func mostRestrictiveMixedList() {
        let permissions: [ContentPermission] = [.full, .none, .educationOnly]
        #expect(ContentPermission.mostRestrictive(permissions) == .none)
    }

    @Test("mostRestrictive of an empty list returns none")
    func mostRestrictiveEmptyList() {
        #expect(ContentPermission.mostRestrictive([]) == .none)
    }
}

@Suite("WorkoutGuidanceCatalogTests")
struct WorkoutGuidanceCatalogTests {

    @Test("every tag whose workout row carries adjustment prose returns non-empty adjustment text")
    func everyTagReturnsNonEmptyAdjustmentText() {
        for tag in ConditionTag.allCases {
            let adjustment = WorkoutGuidanceCatalog.adjustment(for: tag)
            #expect(adjustment != nil)
            #expect(!(adjustment ?? "").isEmpty)
        }
    }

    @Test("a tag whose contraindicated column is an em dash in the source table returns nil, not an empty string")
    func emDashColumnsReturnNilNotEmptyString() {
        let nilTags: [ConditionTag] = [
            .under18Minor,
            .diabetesNotOnHypoglycemiaRiskMedication,
            .prediabetes,
            .severeFoodAllergy,
            .nonSevereFoodAllergy,
            .clinicianPrescribedDietOrMealPlan,
            .noneOfTheAboveBaseline,
        ]
        for tag in nilTags {
            #expect(WorkoutGuidanceCatalog.contraindicated(for: tag) == nil)
        }
    }

    @Test("heartDiseaseRecentEventOrSymptomatic presents the referral message, matching its none workout permission")
    func heartDiseaseRecentEventPresentsReferral() {
        #expect(
            WorkoutGuidanceCatalog.presentableAdjustment(for: .heartDiseaseRecentEventOrSymptomatic)
                == WorkoutGuidanceCatalog.referralMessage
        )
        #expect(GuidanceCatalog.contentPermission(for: .heartDiseaseRecentEventOrSymptomatic, domain: .workout) == .none)
    }

    @Test("presentableAdjustment returns the referral message, not row prose, for every none-permission workout tag")
    func noneePermissionTagsAlwaysPresentReferral() {
        for tag in ConditionTag.allCases where GuidanceCatalog.contentPermission(for: tag, domain: .workout) == .none {
            #expect(WorkoutGuidanceCatalog.presentableAdjustment(for: tag) == WorkoutGuidanceCatalog.referralMessage)
        }
    }

    @Test("presentableAdjustment returns row prose, not the referral message, for a full-permission workout tag")
    func fullPermissionTagPresentsRowProse() {
        let presented = WorkoutGuidanceCatalog.presentableAdjustment(for: .noneOfTheAboveBaseline)
        #expect(presented != WorkoutGuidanceCatalog.referralMessage)
        #expect(presented == WorkoutGuidanceCatalog.adjustment(for: .noneOfTheAboveBaseline))
    }

    @Test("exactly five tags never trigger streak loss, matching section 2's named set")
    func exactlyFiveTagsNeverTriggerStreakLoss() {
        let flagged = ConditionTag.allCases.filter(WorkoutGuidanceCatalog.neverTriggersStreakLoss)
        #expect(flagged.count == 5)
        #expect(Set(flagged) == Set<ConditionTag>([
            .heartDiseaseRecentEventOrSymptomatic,
            .priorInjuryOrSurgeryNotCleared,
            .pregnancyComplicatedOrUnsure,
            .postpartumCSectionOrComplications,
            .eatingDisorderPositiveScreen,
        ]))
    }

    @Test("no accessor traps across every ConditionTag")
    func noAccessorTrapsAcrossEveryTag() {
        for tag in ConditionTag.allCases {
            _ = WorkoutGuidanceCatalog.adjustment(for: tag)
            _ = WorkoutGuidanceCatalog.contraindicated(for: tag)
            _ = WorkoutGuidanceCatalog.presentableAdjustment(for: tag)
            _ = WorkoutGuidanceCatalog.neverTriggersStreakLoss(tag)
        }
        #expect(!WorkoutGuidanceCatalog.referralMessage.isEmpty)
    }
}
