import Testing
@testable import RithamCore

@Suite("TagDerivationTests")
struct TagDerivationTests {

    private func selection(_ items: ChecklistItem...) -> ChecklistSelection {
        ChecklistSelection(items: Set(items))
    }

    // MARK: - Cardiovascular

    @Test("cardiovascular tag with CV-1 yes yields heart disease recent event, not stable")
    func cardiovascularRecentEvent() {
        let answers = ScreeningAnswers(
            checklist: selection(.heartDisease),
            cv1RecentCardiacEvent: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.heartDiseaseRecentEventOrSymptomatic))
        #expect(!tags.contains(.heartDiseaseStable))
    }

    @Test("heart disease selection without a recent event yields stable")
    func cardiovascularStable() {
        let answers = ScreeningAnswers(
            checklist: selection(.heartDisease),
            cv1RecentCardiacEvent: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.heartDiseaseStable))
    }

    @Test("high blood pressure well-controlled yields hypertension managed")
    func hypertensionManaged() {
        let answers = ScreeningAnswers(
            checklist: selection(.highBloodPressure),
            cv2BloodPressureControl: .wellControlled
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.hypertensionManaged))
        #expect(!tags.contains(.hypertensionUncontrolledOrUnsure))
    }

    @Test("high blood pressure doctor-says-high yields hypertension uncontrolled")
    func hypertensionUncontrolledDoctor() {
        let answers = ScreeningAnswers(
            checklist: selection(.highBloodPressure),
            cv2BloodPressureControl: .doctorSaysHigh
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.hypertensionUncontrolledOrUnsure))
    }

    @Test("high blood pressure not-sure-or-not-checked yields the uncontrolled tag, not managed")
    func hypertensionNotSureIsUncontrolled() {
        let answers = ScreeningAnswers(
            checklist: selection(.highBloodPressure),
            cv2BloodPressureControl: .notSureOrNotChecked
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.hypertensionUncontrolledOrUnsure))
        #expect(!tags.contains(.hypertensionManaged))
    }

    @Test("irregular heartbeat well-controlled yields arrhythmia stable")
    func arrhythmiaStable() {
        let answers = ScreeningAnswers(
            checklist: selection(.irregularHeartbeat),
            cv2bRhythmControl: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.arrhythmiaStable))
    }

    @Test("irregular heartbeat not-sure yields the uncontrolled arrhythmia tag")
    func arrhythmiaNotSureIsUncontrolled() {
        let answers = ScreeningAnswers(
            checklist: selection(.irregularHeartbeat),
            cv2bRhythmControl: .notSure
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.arrhythmiaUncontrolledOrUnsure))
        #expect(!tags.contains(.arrhythmiaStable))
    }

    @Test("irregular heartbeat no yields the uncontrolled arrhythmia tag")
    func arrhythmiaNoIsUncontrolled() {
        let answers = ScreeningAnswers(
            checklist: selection(.irregularHeartbeat),
            cv2bRhythmControl: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.arrhythmiaUncontrolledOrUnsure))
    }

    // MARK: - MED-1 / MED-2

    @Test("MED-1 cautious branch yields the rate-limiting medication modifier")
    func med1CautiousYieldsModifier() {
        let answers = ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .yes)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.rateLimitingHeartOrBPMedication))
    }

    @Test("MED-1 not-sure also yields the rate-limiting medication modifier (cautious branch)")
    func med1NotSureYieldsModifier() {
        let answers = ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .notSure)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.rateLimitingHeartOrBPMedication))
    }

    @Test("MED-1 no does not yield the rate-limiting medication modifier")
    func med1NoYieldsNoModifier() {
        let answers = ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .no)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(!tags.contains(.rateLimitingHeartOrBPMedication))
    }

    @Test("MED-2 yes yields the clinician-prescribed diet tag")
    func med2YesYieldsClinicianDiet() {
        let answers = ScreeningAnswers(med2ClinicianPrescribedDietOrMealPlan: .yes)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.clinicianPrescribedDietOrMealPlan))
    }

    // MARK: - Metabolic

    @Test("diabetes with M-1 cautious yields the on-hypoglycemia-risk-medication tag")
    func diabetesOnHypoglycemiaMedication() {
        let answers = ScreeningAnswers(
            checklist: selection(.type1Diabetes),
            m1InsulinOrHypoglycemiaRiskMedication: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.diabetesOnHypoglycemiaRiskMedication))
        #expect(!tags.contains(.diabetesNotOnHypoglycemiaRiskMedication))
    }

    @Test("diabetes with M-1 no yields the not-on-hypoglycemia-risk-medication tag")
    func diabetesNotOnHypoglycemiaMedication() {
        let answers = ScreeningAnswers(
            checklist: selection(.type2Diabetes),
            m1InsulinOrHypoglycemiaRiskMedication: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.diabetesNotOnHypoglycemiaRiskMedication))
    }

    @Test("prediabetes alone yields exactly the prediabetes tag, no M-1/M-2 tags")
    func prediabetesAlone() {
        let answers = ScreeningAnswers(checklist: selection(.prediabetes))
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.prediabetes))
        #expect(!tags.contains(.diabetesOnHypoglycemiaRiskMedication))
        #expect(!tags.contains(.diabetesNotOnHypoglycemiaRiskMedication))
    }

    @Test("M-2 cautious branch additionally yields the retinopathy/foot-complication tag")
    func diabetesRetinopathyFlag() {
        let answers = ScreeningAnswers(
            checklist: selection(.type1Diabetes),
            m1InsulinOrHypoglycemiaRiskMedication: .no,
            m2RetinopathyNeuropathyOrFootWound: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.diabetesRetinopathyOrFootComplication))
        #expect(tags.contains(.diabetesNotOnHypoglycemiaRiskMedication))
    }

    // MARK: - Musculoskeletal / Joint

    @Test("each musculoskeletal item yields its own per-item tag")
    func musculoskeletalPerItemTags() {
        let osteoarthritis = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.osteoarthritis)),
            ageDerivedTags: []
        )
        #expect(osteoarthritis.contains(.osteoarthritis))

        let osteoporosis = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.osteoporosisOrOsteopenia)),
            ageDerivedTags: []
        )
        #expect(osteoporosis.contains(.osteoporosisOrOsteopenia))

        let backPain = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.chronicLowBackPain)),
            ageDerivedTags: []
        )
        #expect(backPain.contains(.chronicLowBackPain))
    }

    @Test("MSK-1 yes additionally yields the musculoskeletal flare modifier")
    func musculoskeletalFlare() {
        let answers = ScreeningAnswers(
            checklist: selection(.osteoarthritis),
            msk1CurrentFlare: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.osteoarthritis))
        #expect(tags.contains(.musculoskeletalFlare))
    }

    @Test("prior injury with MSK-2 still-in-recovery yields not-cleared")
    func priorInjuryNotCleared() {
        let answers = ScreeningAnswers(
            checklist: selection(.priorInjuryOrSurgery),
            msk2SurgicalClearance: .stillInRecoveryNotCleared
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.priorInjuryOrSurgeryNotCleared))
        #expect(!tags.contains(.priorInjuryOrSurgeryCleared))
    }

    @Test("prior injury with MSK-2 fully cleared yields cleared")
    func priorInjuryCleared() {
        let answers = ScreeningAnswers(
            checklist: selection(.priorInjuryOrSurgery),
            msk2SurgicalClearance: .fullyCleared
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.priorInjuryOrSurgeryCleared))
    }

    // MARK: - Pregnancy / Postpartum

    @Test("currently pregnant with PG-1 no yields pregnancy uncomplicated")
    func pregnancyUncomplicated() {
        let answers = ScreeningAnswers(
            checklist: selection(.currentlyPregnant),
            pg1PregnancyComplications: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.pregnancyUncomplicated))
    }

    @Test("currently pregnant with PG-1 yes yields pregnancy complicated or unsure")
    func pregnancyComplicatedYes() {
        let answers = ScreeningAnswers(
            checklist: selection(.currentlyPregnant),
            pg1PregnancyComplications: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.pregnancyComplicatedOrUnsure))
    }

    @Test("currently pregnant with PG-1 not-sure yields pregnancy complicated or unsure")
    func pregnancyComplicatedNotSure() {
        let answers = ScreeningAnswers(
            checklist: selection(.currentlyPregnant),
            pg1PregnancyComplications: .notSure
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.pregnancyComplicatedOrUnsure))
    }

    @Test("postpartum with PP-1 yes yields C-section or complications")
    func postpartumComplications() {
        let answers = ScreeningAnswers(
            checklist: selection(.postpartum),
            pp1CSectionOrDeliveryComplications: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.postpartumCSectionOrComplications))
    }

    @Test("postpartum with PP-1 no yields uncomplicated")
    func postpartumUncomplicated() {
        let answers = ScreeningAnswers(
            checklist: selection(.postpartum),
            pp1CSectionOrDeliveryComplications: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.postpartumUncomplicated))
    }

    // MARK: - Kidney / Renal

    @Test("any kidney/renal box yields kidney disease or dialysis, regardless of follow-ups")
    func kidneyTagRegardlessOfFollowUps() {
        let answers = ScreeningAnswers(
            checklist: selection(.kidneyDiseaseCKD),
            kr1CurrentlyOnDialysis: .no,
            kr2SpecificDietaryLimits: .notSure
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.kidneyDiseaseOrDialysis))
    }

    @Test("dialysis checklist item alone yields kidney disease or dialysis")
    func dialysisTag() {
        let answers = ScreeningAnswers(checklist: selection(.currentlyOnDialysis))
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.kidneyDiseaseOrDialysis))
    }

    // MARK: - Eating Disorder History / SCOFF

    @Test("SCOFF positive screen with the checklist item selected yields the positive-screen tag")
    func scoffPositiveScreen() {
        let answers = ScreeningAnswers(
            checklist: selection(.eatingDisorderHistory),
            scoff: SCOFFResponses(
                ed1MakesSelfSickWhenFull: .yes,
                ed2WorriesLostControlOverEating: .yes,
                ed3RecentSignificantWeightLoss: .no,
                ed4BelievesSelfFatWhenToldTooThin: .no,
                ed5FoodDominatesLife: .no
            )
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.eatingDisorderPositiveScreen))
        #expect(!tags.contains(.eatingDisorderSelfReportedNegativeScreen))
    }

    @Test("SCOFF negative screen with the checklist item selected yields the negative-screen tag")
    func scoffNegativeScreen() {
        let answers = ScreeningAnswers(
            checklist: selection(.eatingDisorderHistory),
            scoff: SCOFFResponses(
                ed1MakesSelfSickWhenFull: .no,
                ed2WorriesLostControlOverEating: .no,
                ed3RecentSignificantWeightLoss: .no,
                ed4BelievesSelfFatWhenToldTooThin: .no,
                ed5FoodDominatesLife: .no
            )
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.eatingDisorderSelfReportedNegativeScreen))
        #expect(!tags.contains(.eatingDisorderPositiveScreen))
    }

    @Test("a positive-screen SCOFF response present while the checklist item is unselected derives neither tag")
    func scoffIgnoredWhenUntriggered() {
        let answers = ScreeningAnswers(
            checklist: selection(.osteoarthritis),
            scoff: SCOFFResponses(
                ed1MakesSelfSickWhenFull: .yes,
                ed2WorriesLostControlOverEating: .yes,
                ed3RecentSignificantWeightLoss: .yes,
                ed4BelievesSelfFatWhenToldTooThin: .yes,
                ed5FoodDominatesLife: .yes
            )
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(!tags.contains(.eatingDisorderPositiveScreen))
        #expect(!tags.contains(.eatingDisorderSelfReportedNegativeScreen))
    }

    // MARK: - Food Allergies

    @Test("FA-1 cautious branch yields severe food allergy")
    func severeFoodAllergy() {
        let answers = ScreeningAnswers(
            checklist: selection(.foodAllergies),
            fa1SevereAllergyOrEpinephrine: .yes
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.severeFoodAllergy))
    }

    @Test("FA-1 not-sure also yields severe food allergy (cautious branch)")
    func severeFoodAllergyNotSure() {
        let answers = ScreeningAnswers(
            checklist: selection(.foodAllergies),
            fa1SevereAllergyOrEpinephrine: .notSure
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.severeFoodAllergy))
    }

    @Test("FA-1 no yields non-severe food allergy")
    func nonSevereFoodAllergy() {
        let answers = ScreeningAnswers(
            checklist: selection(.foodAllergies),
            fa1SevereAllergyOrEpinephrine: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.nonSevereFoodAllergy))
        #expect(!tags.contains(.severeFoodAllergy))
    }

    // MARK: - Other Serious Condition

    @Test("any Other Serious Condition box yields the tag regardless of OS-1")
    func otherSeriousCondition() {
        let answers = ScreeningAnswers(
            checklist: selection(.activeCancerTreatment),
            os1NewDiagnosisOrTreatmentChange: .no
        )
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.otherSeriousConditionOrActiveCancerTreatment))
    }

    // MARK: - U-1 / age-derived precedence

    @Test("U-1 yes yields the 65-plus/deconditioned tag")
    func u1YesYieldsAgeTag() {
        let answers = ScreeningAnswers(u1AgeOrDeconditioned: .yes)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.age65PlusOrDeconditioned))
    }

    @Test("a 65-year-old answering U-1 No still holds the 65-plus tag from ageDerivedTags")
    func ageDerivedTagSurvivesU1No() {
        let answers = ScreeningAnswers(age: 65, u1AgeOrDeconditioned: .no)
        let tags = TagDerivation.deriveTags(
            from: answers,
            ageDerivedTags: ConditionTag.ageDerivedTags(forAge: 65)
        )
        #expect(tags.contains(.age65PlusOrDeconditioned))
    }

    // MARK: - under18Minor producer

    @Test("age under 18 yields the under18Minor tag")
    func under18Age() {
        let answers = ScreeningAnswers(age: 15)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags.contains(.under18Minor))
    }

    @Test("age 18 or older does not yield the under18Minor tag")
    func age18DoesNotYieldMinorTag() {
        let answers = ScreeningAnswers(age: 18)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(!tags.contains(.under18Minor))
    }

    // MARK: - Baseline

    @Test("an empty checklist with None-of-the-above selected yields exactly noneOfTheAboveBaseline")
    func noneOfTheAboveBaseline() {
        let answers = ScreeningAnswers(checklist: selection(.noneOfTheAbove))
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags == [.noneOfTheAboveBaseline])
    }

    @Test("None-of-the-above alongside an unrelated age-derived tag still yields the baseline tag")
    func noneOfTheAboveBaselineSurvivesAgeDerivedUnion() {
        let answers = ScreeningAnswers(checklist: selection(.noneOfTheAbove))
        let tags = TagDerivation.deriveTags(
            from: answers,
            ageDerivedTags: [.age65PlusOrDeconditioned]
        )
        #expect(tags.contains(.noneOfTheAboveBaseline))
        #expect(tags.contains(.age65PlusOrDeconditioned))
    }

    @Test("confirming none for every section yields the baseline tag without the global sentinel")
    func everySectionConfirmedNoneYieldsBaselineTag() {
        var checklist = ChecklistSelection()
        for category in ChecklistCategory.allCases where category != .none {
            checklist.toggleNoneForSection([category], sectionItems: [])
        }
        let answers = ScreeningAnswers(checklist: checklist)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(tags == [.noneOfTheAboveBaseline])
    }

    @Test("confirming none for only some sections does not yield the baseline tag")
    func partiallyConfirmedSectionsDoNotYieldBaselineTag() {
        var checklist = ChecklistSelection()
        checklist.toggleNoneForSection([.cardiovascular], sectionItems: [])
        let answers = ScreeningAnswers(checklist: checklist)
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: [])
        #expect(!tags.contains(.noneOfTheAboveBaseline))
    }
}
