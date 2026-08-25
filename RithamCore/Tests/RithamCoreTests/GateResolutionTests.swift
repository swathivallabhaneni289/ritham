import Testing
@testable import RithamCore

@Suite("GateResolutionTests")
struct GateResolutionTests {

    private func selection(_ items: ChecklistItem...) -> ChecklistSelection {
        ChecklistSelection(items: Set(items))
    }

    private func gates(_ tags: Set<ConditionTag>, answers: ScreeningAnswers = ScreeningAnswers()) -> DomainGates {
        GateEscalation.escalate(tags: tags, answers: answers)
    }

    // MARK: - The three named suites 01-VALIDATION.md specifies

    @Test("Not sure resolves to the more cautious branch on every clearance-relevant follow-up")
    func testNotSureResolvesCautious() {
        // CV-2 (hypertension): not-sure-or-not-checked is equal to doctor-says-high, and
        // strictly more restrictive than well-controlled.
        let cv2NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.highBloodPressure), cv2BloodPressureControl: .notSureOrNotChecked),
                ageDerivedTags: []
            )
        )
        let cv2DoctorHigh = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.highBloodPressure), cv2BloodPressureControl: .doctorSaysHigh),
                ageDerivedTags: []
            )
        )
        let cv2WellControlled = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.highBloodPressure), cv2BloodPressureControl: .wellControlled),
                ageDerivedTags: []
            )
        )
        #expect(cv2NotSure.workout >= cv2DoctorHigh.workout)
        #expect(cv2NotSure.nutrition >= cv2DoctorHigh.nutrition)
        #expect(cv2NotSure.workout > cv2WellControlled.workout)
        #expect(cv2NotSure.nutrition > cv2WellControlled.nutrition)

        // CV-2b (arrhythmia): not-sure is strictly more restrictive than yes (well-controlled),
        // and equal to no — §5 rule 4 groups "No OR Not sure" identically.
        let cv2bNotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.irregularHeartbeat), cv2bRhythmControl: .notSure),
                ageDerivedTags: []
            )
        )
        let cv2bYes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.irregularHeartbeat), cv2bRhythmControl: .yes),
                ageDerivedTags: []
            )
        )
        let cv2bNo = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.irregularHeartbeat), cv2bRhythmControl: .no),
                ageDerivedTags: []
            )
        )
        #expect(cv2bNotSure.workout > cv2bYes.workout)
        #expect(cv2bNotSure.workout == cv2bNo.workout)

        // M-1 (diabetes hypoglycemia-risk medication): not-sure equals yes, strictly more
        // restrictive (on the workout domain) than no.
        let m1NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.type1Diabetes), m1InsulinOrHypoglycemiaRiskMedication: .notSure),
                ageDerivedTags: []
            )
        )
        let m1Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.type1Diabetes), m1InsulinOrHypoglycemiaRiskMedication: .yes),
                ageDerivedTags: []
            )
        )
        let m1No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.type1Diabetes), m1InsulinOrHypoglycemiaRiskMedication: .no),
                ageDerivedTags: []
            )
        )
        #expect(m1NotSure.workout == m1Yes.workout)
        #expect(m1NotSure.workout > m1No.workout)

        // M-2 (retinopathy/foot complication): not-sure equals yes, strictly more restrictive
        // (on the workout domain) than no, holding M-1 = no as the baseline.
        let m2NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(
                    checklist: selection(.type1Diabetes),
                    m1InsulinOrHypoglycemiaRiskMedication: .no,
                    m2RetinopathyNeuropathyOrFootWound: .notSure
                ),
                ageDerivedTags: []
            )
        )
        let m2Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(
                    checklist: selection(.type1Diabetes),
                    m1InsulinOrHypoglycemiaRiskMedication: .no,
                    m2RetinopathyNeuropathyOrFootWound: .yes
                ),
                ageDerivedTags: []
            )
        )
        let m2No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(
                    checklist: selection(.type1Diabetes),
                    m1InsulinOrHypoglycemiaRiskMedication: .no,
                    m2RetinopathyNeuropathyOrFootWound: .no
                ),
                ageDerivedTags: []
            )
        )
        #expect(m2NotSure.workout == m2Yes.workout)
        #expect(m2NotSure.workout > m2No.workout)

        // PG-1 (pregnancy complications): not-sure equals yes (both land on
        // pregnancyComplicatedOrUnsure); strictly more restrictive than no on the workout
        // domain (nutrition is required-blocking either way, per §5 rule 7's absolute clause).
        let pg1NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.currentlyPregnant), pg1PregnancyComplications: .notSure),
                ageDerivedTags: []
            )
        )
        let pg1Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.currentlyPregnant), pg1PregnancyComplications: .yes),
                ageDerivedTags: []
            )
        )
        let pg1No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.currentlyPregnant), pg1PregnancyComplications: .no),
                ageDerivedTags: []
            )
        )
        #expect(pg1NotSure.workout == pg1Yes.workout)
        #expect(pg1NotSure.nutrition == pg1Yes.nutrition)
        #expect(pg1NotSure.workout > pg1No.workout)
        #expect(pg1NotSure.nutrition == pg1No.nutrition) // both required-blocking, rule 7

        // FA-1 (severe allergy): not-sure equals yes; strictly more restrictive than no on the
        // nutrition domain.
        let fa1NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.foodAllergies), fa1SevereAllergyOrEpinephrine: .notSure),
                ageDerivedTags: []
            )
        )
        let fa1Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.foodAllergies), fa1SevereAllergyOrEpinephrine: .yes),
                ageDerivedTags: []
            )
        )
        let fa1No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.foodAllergies), fa1SevereAllergyOrEpinephrine: .no),
                ageDerivedTags: []
            )
        )
        #expect(fa1NotSure.nutrition == fa1Yes.nutrition)
        #expect(fa1NotSure.nutrition > fa1No.nutrition)

        // KR-2 (kidney dietary limits): informational only per §1.4 — not-sure, yes, and no all
        // resolve to the same gate (kidney tag alone is already the most restrictive setting).
        let kr2NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.kidneyDiseaseCKD), kr2SpecificDietaryLimits: .notSure),
                ageDerivedTags: []
            )
        )
        let kr2Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.kidneyDiseaseCKD), kr2SpecificDietaryLimits: .yes),
                ageDerivedTags: []
            )
        )
        let kr2No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(checklist: selection(.kidneyDiseaseCKD), kr2SpecificDietaryLimits: .no),
                ageDerivedTags: []
            )
        )
        #expect(kr2NotSure.workout >= kr2Yes.workout)
        #expect(kr2NotSure.workout >= kr2No.workout)
        #expect(kr2NotSure == kr2Yes)
        #expect(kr2NotSure == kr2No)

        // MED-1 (rate-limiting heart/BP medication modifier): the modifier tag itself is
        // none/none, so not-sure, yes, and no all resolve equally here — §5 doesn't
        // distinguish them at the gate level, only at the intensity-method content layer.
        let med1NotSure = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .notSure),
                ageDerivedTags: []
            )
        )
        let med1Yes = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .yes),
                ageDerivedTags: []
            )
        )
        let med1No = gates(
            TagDerivation.deriveTags(
                from: ScreeningAnswers(med1RateLimitingHeartOrBPMedication: .no),
                ageDerivedTags: []
            )
        )
        #expect(med1NotSure.workout >= med1Yes.workout)
        #expect(med1NotSure == med1No)
    }

    @Test("2+ red-flag tags resolve to the single most restrictive gate, never averaged")
    func testMultiTagMostRestrictiveWins() {
        // A recommended-gated tag plus a required-blocking-gated tag resolves to
        // requiredBlocking in the affected domain.
        let mixed = gates([.heartDiseaseStable, .kidneyDiseaseOrDialysis])
        #expect(mixed.workout == .requiredBlocking)
        #expect(mixed.nutrition == .requiredBlocking)

        // Two recommended tags do not combine into requiredBlocking.
        let twoRecommended = gates([.heartDiseaseStable, .hypertensionManaged])
        #expect(twoRecommended.workout == .recommended)
        #expect(twoRecommended.nutrition == .recommended)

        // Adding a none-gated tag to a requiredBlocking set never lowers the result.
        let withNoneAdded = gates([.kidneyDiseaseOrDialysis, .noneOfTheAboveBaseline, .nonSevereFoodAllergy])
        #expect(withNoneAdded.workout == .requiredBlocking)
        #expect(withNoneAdded.nutrition == .requiredBlocking)
    }

    @Test("SCOFF contributes only when the eating-disorder item is selected, at the documented threshold")
    func testSCOFFTrigger() {
        func scoff(_ yesCount: Int) -> SCOFFResponses {
            let yeses = (0..<yesCount).map { _ in YesNo.yes }
            let nos = (0..<(5 - yesCount)).map { _ in YesNo.no }
            let all = yeses + nos
            return SCOFFResponses(
                ed1MakesSelfSickWhenFull: all[0],
                ed2WorriesLostControlOverEating: all[1],
                ed3RecentSignificantWeightLoss: all[2],
                ed4BelievesSelfFatWhenToldTooThin: all[3],
                ed5FoodDominatesLife: all[4]
            )
        }

        // Present but the checklist item is unselected: neither eating-disorder tag derives,
        // so nutrition stays at the None-of-the-above baseline gate.
        let untriggered = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.osteoarthritis), scoff: scoff(3)),
            ageDerivedTags: []
        )
        #expect(!untriggered.contains(.eatingDisorderPositiveScreen))
        #expect(!untriggered.contains(.eatingDisorderSelfReportedNegativeScreen))

        // Score >= 2 with the item selected -> positive screen, nutrition required-blocking.
        let positive = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.eatingDisorderHistory), scoff: scoff(2)),
            ageDerivedTags: []
        )
        #expect(positive.contains(.eatingDisorderPositiveScreen))
        #expect(gates(positive).nutrition == .requiredBlocking)
        #expect(gates(positive).workout == .requiredBlocking)

        // Score below 2 with the item selected -> negative screen, nutrition recommended.
        let negative = TagDerivation.deriveTags(
            from: ScreeningAnswers(checklist: selection(.eatingDisorderHistory), scoff: scoff(1)),
            ageDerivedTags: []
        )
        #expect(negative.contains(.eatingDisorderSelfReportedNegativeScreen))
        #expect(gates(negative).nutrition == .recommended)
    }

    // MARK: - One test per numbered §5 rule

    @Test("Rule 1: G2 or G3 = Yes escalates both domains to required-blocking, independent of any tag")
    func testRule01ChestPainOrDizziness() {
        let g2 = gates([], answers: ScreeningAnswers(g2ChestPainOrBreathlessness: .yes))
        #expect(g2.workout == .requiredBlocking)
        #expect(g2.nutrition == .requiredBlocking)

        let g3 = gates([], answers: ScreeningAnswers(g3DizzinessOrLossOfConsciousness: .yes))
        #expect(g3.workout == .requiredBlocking)
        #expect(g3.nutrition == .requiredBlocking)

        // Combined with several other yeses, still required-blocking (never averaged down).
        let combined = gates(
            [.hypertensionManaged],
            answers: ScreeningAnswers(
                g1HeartConditionOrHighBP: .yes,
                g2ChestPainOrBreathlessness: .yes,
                g6BoneJointSoftTissueProblem: .yes
            )
        )
        #expect(combined.workout == .requiredBlocking)
        #expect(combined.nutrition == .requiredBlocking)
    }

    @Test("Rule 2: any Cardiovascular tag + CV-1 = Yes yields Heart Disease Recent Event, required-blocking both domains")
    func testRule02RecentCardiacEvent() {
        let result = gates([.heartDiseaseRecentEventOrSymptomatic])
        #expect(result.workout == .requiredBlocking)
        #expect(result.nutrition == .requiredBlocking)
    }

    @Test("Rule 3: High blood pressure + doctor-says-high or not-sure yields required-blocking workout")
    func testRule03HypertensionUncontrolled() {
        let result = gates([.hypertensionUncontrolledOrUnsure])
        #expect(result.workout == .requiredBlocking)
        #expect(result.nutrition == .requiredBlocking)
    }

    @Test("Rule 4: Irregular heartbeat + not-controlled/not-sure yields required-blocking workout")
    func testRule04ArrhythmiaUncontrolled() {
        let result = gates([.arrhythmiaUncontrolledOrUnsure])
        #expect(result.workout == .requiredBlocking)
    }

    @Test("Rule 5: on-hypoglycemia-risk-medication diabetes carries a recommended (not blocking) glucose-check gate")
    func testRule05HypoglycemiaMedicationReminder() {
        let result = gates([.diabetesOnHypoglycemiaRiskMedication])
        #expect(result.workout == .recommended)
        #expect(result.workout != .requiredBlocking)
    }

    @Test("Rule 6: retinopathy/foot-complication flag raises workout to recommended")
    func testRule06RetinopathyFootComplication() {
        let result = gates([.diabetesNotOnHypoglycemiaRiskMedication, .diabetesRetinopathyOrFootComplication])
        #expect(result.workout == .recommended)
    }

    @Test("Rule 7: currently pregnant, regardless of PG-1, yields nutrition required-blocking absolute")
    func testRule07PregnancyNutritionAbsolute() {
        let uncomplicated = gates([.pregnancyUncomplicated])
        #expect(uncomplicated.nutrition == .requiredBlocking)
    }

    @Test("Rule 8: currently pregnant + PG-1 yes/not-sure yields required-blocking across both domains")
    func testRule08PregnancyComplicated() {
        let result = gates([.pregnancyComplicatedOrUnsure])
        #expect(result.workout == .requiredBlocking)
        #expect(result.nutrition == .requiredBlocking)
    }

    @Test("Rule 9: postpartum + PP-1 yes yields required-blocking workout until clearance is confirmed")
    func testRule09PostpartumComplications() {
        let result = gates([.postpartumCSectionOrComplications])
        #expect(result.workout == .requiredBlocking)
    }

    @Test("Rule 10: any kidney/renal box checked yields required-blocking both domains, always")
    func testRule10KidneyDisease() {
        let result = gates([.kidneyDiseaseOrDialysis])
        #expect(result.workout == .requiredBlocking)
        #expect(result.nutrition == .requiredBlocking)
    }

    @Test("Rule 11: SCOFF score >= 2 yields Eating Disorder History Positive Screen, required-blocking")
    func testRule11SCOFFPositiveScreen() {
        let result = gates([.eatingDisorderPositiveScreen])
        #expect(result.nutrition == .requiredBlocking)
        #expect(result.workout == .requiredBlocking)
    }

    @Test("Rule 12: musculoskeletal tag + MSK-2 still-in-recovery yields required-blocking workout")
    func testRule12PriorInjuryNotCleared() {
        let result = gates([.osteoarthritis, .priorInjuryOrSurgeryNotCleared])
        #expect(result.workout == .requiredBlocking)
    }

    @Test("Rule 13: any Other Serious Condition box checked yields required-blocking both domains, always")
    func testRule13OtherSeriousCondition() {
        let result = gates([.otherSeriousConditionOrActiveCancerTreatment])
        #expect(result.workout == .requiredBlocking)
        #expect(result.nutrition == .requiredBlocking)
    }

    @Test("Rule 14: Under 18 + a weight-loss goal is required-blocking, identical to a positive ED screen")
    func testRule14WeightLossUnder18() {
        let underage = GateEscalation.weightLossFeatureGate(tags: [.under18Minor], goalBelowHealthyBMIFloor: false)
        #expect(underage == .requiredBlocking)

        let positiveScreen = GateEscalation.weightLossFeatureGate(
            tags: [.eatingDisorderPositiveScreen],
            goalBelowHealthyBMIFloor: false
        )
        #expect(positiveScreen == .requiredBlocking)

        let neither = GateEscalation.weightLossFeatureGate(tags: [.noneOfTheAboveBaseline], goalBelowHealthyBMIFloor: false)
        #expect(neither == .none)
    }

    @Test("Rule 15: a goal weight below the healthy-BMI floor is treated as a red flag equivalent to a positive ED screen")
    func testRule15WeightLossBelowBMIFloor() {
        let belowFloor = GateEscalation.weightLossFeatureGate(
            tags: [.noneOfTheAboveBaseline],
            goalBelowHealthyBMIFloor: true
        )
        #expect(belowFloor == .requiredBlocking)

        let aboveFloor = GateEscalation.weightLossFeatureGate(
            tags: [.noneOfTheAboveBaseline],
            goalBelowHealthyBMIFloor: false
        )
        #expect(aboveFloor == .none)
    }

    @Test("Rule 16: severe food allergy carries a standing, non-expiring independent-verification flag")
    func testRule16AllergenVerification() {
        #expect(GateEscalation.requiresIndependentAllergenVerification(tags: [.severeFoodAllergy]) == true)
        #expect(GateEscalation.requiresIndependentAllergenVerification(tags: [.nonSevereFoodAllergy]) == false)
        #expect(GateEscalation.requiresIndependentAllergenVerification(tags: []) == false)
    }

    // MARK: - Always-on prohibitions

    @Test("the medication-dosing prohibition is a standing fact, not a clearable gate state")
    func neverGeneratesMedicationDosingGuidanceIsStandingFact() {
        #expect(GateEscalation.neverGeneratesMedicationDosingGuidance == true)
    }

    @Test("the emergency line shows unconditionally at the gate section and the urgent interstitial")
    func emergencyLineShowsAtGateAndUrgentInterstitial() {
        #expect(GateEscalation.showsEmergencyLine(for: .gate) == true)
        #expect(GateEscalation.showsEmergencyLine(for: .urgentInterstitial) == true)
    }

    // MARK: - baseGates sourced independently from §2 and §3

    @Test("baseGates returns per-domain values sourced independently, not one value duplicated")
    func baseGatesDivergesPerDomain() {
        let under18 = GateEscalation.baseGates(for: .under18Minor)
        #expect(under18.workout == .none)
        #expect(under18.nutrition == .requiredBlocking)

        let arrhythmiaStable = GateEscalation.baseGates(for: .arrhythmiaStable)
        #expect(arrhythmiaStable.workout == .recommended)
        #expect(arrhythmiaStable.nutrition == .none)
    }

    // MARK: - Task 3: GateResolution.resolve and interstitial branching (§1.2)

    @Test("all-No gate answers yield the none interstitial")
    func resolveAllNoYieldsNoInterstitial() {
        let answers = ScreeningAnswers(
            g1HeartConditionOrHighBP: .no,
            g2ChestPainOrBreathlessness: .no,
            g3DizzinessOrLossOfConsciousness: .no,
            g4OtherOngoingCondition: .no,
            g5MedicationOrPrescribedDiet: .no,
            g6BoneJointSoftTissueProblem: .no,
            g7MedicallySupervisedOnly: .no,
            checklist: selection(.noneOfTheAbove)
        )
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.interstitial == .none)
    }

    @Test("G1 yes alone yields the routine interstitial")
    func resolveG1YesYieldsRoutine() {
        let answers = ScreeningAnswers(g1HeartConditionOrHighBP: .yes)
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.interstitial == .routine)
    }

    @Test("G2 yes yields the urgent interstitial")
    func resolveG2YesYieldsUrgent() {
        let answers = ScreeningAnswers(g2ChestPainOrBreathlessness: .yes)
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.interstitial == .urgent)
    }

    @Test("G3 yes yields the urgent interstitial")
    func resolveG3YesYieldsUrgent() {
        let answers = ScreeningAnswers(g3DizzinessOrLossOfConsciousness: .yes)
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.interstitial == .urgent)
    }

    @Test("G2 yes combined with several other yeses still yields urgent, not routine")
    func resolveG2WithOthersStillUrgent() {
        let answers = ScreeningAnswers(
            g1HeartConditionOrHighBP: .yes,
            g2ChestPainOrBreathlessness: .yes,
            g4OtherOngoingCondition: .yes,
            g6BoneJointSoftTissueProblem: .yes
        )
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.interstitial == .urgent)
    }

    @Test("a required-blocking workout gate blocks workout personalization, respects nutrition independently, and never blocks app access")
    func resolveBlocksPersonalizationPerDomainOnly() {
        let answers = ScreeningAnswers(checklist: selection(.priorInjuryOrSurgery), msk2SurgicalClearance: .stillInRecoveryNotCleared)
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.blocksPersonalization(in: .workout) == true)
        #expect(result.blocksPersonalization(in: .nutrition) == (result.gates.nutrition == .requiredBlocking))
        #expect(result.blocksAppAccess == false)
    }

    @Test("blocksAppAccess is false even when a domain gate is required-blocking")
    func resolveBlocksAppAccessAlwaysFalse() {
        let answers = ScreeningAnswers(checklist: selection(.kidneyDiseaseCKD))
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.gates.workout == .requiredBlocking)
        #expect(result.gates.nutrition == .requiredBlocking)
        #expect(result.blocksAppAccess == false)
    }

    @Test("a two-tag case where only one gate governs still returns both names from disclaimerConditionNames")
    func resolveDisclaimerListsAllMatchedTags() {
        let answers = ScreeningAnswers(
            checklist: selection(.heartDisease, .kidneyDiseaseCKD),
            cv1RecentCardiacEvent: .no
        )
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.matchedTags.contains(.heartDiseaseStable))
        #expect(result.matchedTags.contains(.kidneyDiseaseOrDialysis))
        // Only the kidney tag's required-blocking gate binds, but both names still appear.
        #expect(result.disclaimerConditionNames.contains(ConditionTag.heartDiseaseStable.displayName))
        #expect(result.disclaimerConditionNames.contains(ConditionTag.kidneyDiseaseOrDialysis.displayName))
    }

    @Test("disclaimerConditionNames is stable across repeated calls")
    func resolveDisclaimerNamesStable() {
        let answers = ScreeningAnswers(checklist: selection(.heartDisease, .kidneyDiseaseCKD), cv1RecentCardiacEvent: .no)
        let result = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(result.disclaimerConditionNames == result.disclaimerConditionNames)
        #expect(result.disclaimerConditionNames == result.disclaimerConditionNames.sorted())
    }

    @Test("resolve is deterministic: identical answers produce equal results across repeated calls")
    func resolveIsDeterministic() {
        let answers = ScreeningAnswers(
            checklist: selection(.currentlyPregnant),
            pg1PregnancyComplications: .yes
        )
        let first = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        let second = GateResolution.resolve(answers: answers, ageDerivedTags: [])
        #expect(first == second)
    }
}
