// Maps §1.3's condition checklist plus §1.4's severity follow-ups onto the §2/§3 Condition Tag
// vocabulary, per docs/health-screening.md §1.4 and §5. This is the first of the two stages
// HEALTH-06's engine composes (plan 01-06 Task 3 wires this to `GateEscalation`); this file's
// only job is answers -> tags, never tags -> gates.
//
// DietaryPattern is deliberately never imported or referenced here — DIET-01 forbids it from
// participating anywhere in gate-resolution logic, and tag derivation is the stage where it
// would most plausibly creep in.

/// Turns a user's screening answers into the set of `ConditionTag`s they hold.
public enum TagDerivation {

    /// - Parameters:
    ///   - answers: the user's screening answers (§1.1-§1.4).
    ///   - ageDerivedTags: the age-derived tag set from `ConditionTag.ageDerivedTags(forAge:)`,
    ///     passed in by the caller rather than recomputed here so this function stays a pure
    ///     function of screening answers. Per §1.1's precedence rule this is unioned into the
    ///     result and never subtracted from — U-1 can only add the 65+ tag, never clear one
    ///     already set by age.
    public static func deriveTags(
        from answers: ScreeningAnswers,
        ageDerivedTags: Set<ConditionTag>
    ) -> Set<ConditionTag> {
        var checklistDerived: Set<ConditionTag> = []

        checklistDerived.formUnion(cardiovascularTags(answers))
        checklistDerived.formUnion(metabolicTags(answers))
        checklistDerived.formUnion(musculoskeletalTags(answers))
        checklistDerived.formUnion(pregnancyTags(answers))
        checklistDerived.formUnion(postpartumTags(answers))
        checklistDerived.formUnion(kidneyTags(answers))
        checklistDerived.formUnion(eatingDisorderTags(answers))
        checklistDerived.formUnion(foodAllergyTags(answers))
        checklistDerived.formUnion(otherSeriousConditionTags(answers))

        var result = checklistDerived

        // §1.3's "None of the above clears any other selection" plus this rule: when nothing
        // else on the checklist produced a tag and the sole selection is the sentinel, the
        // baseline tag applies. Reading pinned here: this checks only checklist-derived tags —
        // an age-derived or U-1-derived tag unioned in afterward does not suppress the
        // baseline tag, since §1.1's precedence rule is additive-only and a 65-plus baseline
        // user is a real, common case this module must represent, not an edge case to collapse
        // away.
        //
        // `ConditionChecklistView` (live-review feedback, 2026-09-01) dropped the single global
        // "None of the above" control in favor of a per-section confirmation, so a user can no
        // longer produce `items == [.noneOfTheAbove]` through the screen — they instead confirm
        // every one of the checklist's real categories individually, leaving `items` empty. That
        // path is an equally explicit "nothing applies" and must reach the same baseline tag; the
        // `.noneOfTheAbove` sentinel itself stays in `ChecklistItem`, and this check's original
        // form stays alongside it for any other caller that still constructs a selection with it
        // directly.
        let everySectionConfirmedNone = Set(ChecklistCategory.allCases)
            .subtracting([.none])
            .isSubset(of: answers.checklist.noneConfirmedCategories)
        if checklistDerived.isEmpty && (answers.checklist.items == [.noneOfTheAbove] || everySectionConfirmedNone) {
            result.insert(.noneOfTheAboveBaseline)
        }

        // MED-1/MED-2 are G5's immediate follow-ups but are read directly off the answer here,
        // ungated on G5 itself — the plan only requires SCOFF's checklist-item gating (D-10);
        // no equivalent gating is asked of MED-1/MED-2.
        if answers.med1RateLimitingHeartOrBPMedication?.isCautiousBranch == true {
            result.insert(.rateLimitingHeartOrBPMedication)
        }
        if answers.med2ClinicianPrescribedDietOrMealPlan == .yes {
            result.insert(.clinicianPrescribedDietOrMealPlan)
        }

        // U-1 is a universal follow-up, independent of the checklist.
        if answers.u1AgeOrDeconditioned == .yes {
            result.insert(.age65PlusOrDeconditioned)
        }

        // §1.1 Q0: age under 18 sets `.under18Minor` permanently. `ScreeningAnswers.age` is
        // Q0's own field, so this reads directly off the screening answers rather than
        // reaching outside this pure function. This is a distinct, separate mapping from
        // `ConditionTag.ageDerivedTags(forAge:)` (which is scoped to the 65+ tag only, per
        // 01-03-SUMMARY.md's open-gap note) and from MINOR-01's 13+ eligibility floor (a plain
        // boolean plan 01-07 reads independently) — this is the only producer for
        // `.under18Minor` anywhere in RithamCore. Without it, §3's Under-18 nutrition
        // required-blocking row would never fire for any minor, silently under-restricting a
        // protected population; see 01-06-SUMMARY.md for this gap's closure.
        if let age = answers.age, age < 18 {
            result.insert(.under18Minor)
        }

        result.formUnion(ageDerivedTags)

        return result
    }

    // MARK: - Cardiovascular

    private static func cardiovascularTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        let items = answers.checklist.items
        let anyCardioSelected = items.contains { $0.category == .cardiovascular }
        var tags: Set<ConditionTag> = []

        if anyCardioSelected {
            if answers.cv1RecentCardiacEvent == .yes {
                tags.insert(.heartDiseaseRecentEventOrSymptomatic)
            } else if items.contains(.heartDisease) {
                tags.insert(.heartDiseaseStable)
            }
        }

        if items.contains(.highBloodPressure) {
            switch answers.cv2BloodPressureControl {
            case .wellControlled:
                tags.insert(.hypertensionManaged)
            case .doctorSaysHigh, .notSureOrNotChecked:
                // §5 rule 3: both the explicit "high" branch and "Not sure" resolve to the
                // uncontrolled tag — "Not sure" is not a pass-through to Managed.
                tags.insert(.hypertensionUncontrolledOrUnsure)
            case nil:
                break
            }
        }

        if items.contains(.irregularHeartbeat) {
            switch answers.cv2bRhythmControl {
            case .yes:
                tags.insert(.arrhythmiaStable)
            case .no, .notSure:
                tags.insert(.arrhythmiaUncontrolledOrUnsure)
            case nil:
                break
            }
        }

        return tags
    }

    // MARK: - Metabolic

    private static func metabolicTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        let items = answers.checklist.items
        let metabolicItems = items.filter { $0.category == .metabolic }
        guard !metabolicItems.isEmpty else { return [] }

        let isPrediabetesAlone = metabolicItems == [.prediabetes]
        if isPrediabetesAlone {
            return [.prediabetes]
        }

        var tags: Set<ConditionTag> = []
        if answers.m1InsulinOrHypoglycemiaRiskMedication?.isCautiousBranch == true {
            tags.insert(.diabetesOnHypoglycemiaRiskMedication)
        } else {
            tags.insert(.diabetesNotOnHypoglycemiaRiskMedication)
        }
        if answers.m2RetinopathyNeuropathyOrFootWound?.isCautiousBranch == true {
            tags.insert(.diabetesRetinopathyOrFootComplication)
        }
        return tags
    }

    // MARK: - Musculoskeletal / Joint

    private static func musculoskeletalTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        let items = answers.checklist.items
        var tags: Set<ConditionTag> = []

        if items.contains(.osteoarthritis) {
            tags.insert(.osteoarthritis)
        }
        if items.contains(.osteoporosisOrOsteopenia) {
            tags.insert(.osteoporosisOrOsteopenia)
        }
        if items.contains(.chronicLowBackPain) {
            tags.insert(.chronicLowBackPain)
        }
        if items.contains(.priorInjuryOrSurgery) {
            switch answers.msk2SurgicalClearance {
            case .stillInRecoveryNotCleared:
                tags.insert(.priorInjuryOrSurgeryNotCleared)
            case .fullyCleared:
                tags.insert(.priorInjuryOrSurgeryCleared)
            case .notApplicable, nil:
                break
            }
        }

        let anyMSKSelected = items.contains { $0.category == .musculoskeletalJoint }
        if anyMSKSelected && answers.msk1CurrentFlare == .yes {
            tags.insert(.musculoskeletalFlare)
        }

        return tags
    }

    // MARK: - Pregnancy / Postpartum

    private static func pregnancyTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        guard answers.checklist.items.contains(.currentlyPregnant) else { return [] }
        switch answers.pg1PregnancyComplications {
        case .no:
            return [.pregnancyUncomplicated]
        case .yes, .notSure:
            return [.pregnancyComplicatedOrUnsure]
        case nil:
            return []
        }
    }

    private static func postpartumTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        guard answers.checklist.items.contains(.postpartum) else { return [] }
        switch answers.pp1CSectionOrDeliveryComplications {
        case .yes:
            return [.postpartumCSectionOrComplications]
        case .no:
            return [.postpartumUncomplicated]
        case nil:
            return []
        }
    }

    // MARK: - Kidney / Renal

    private static func kidneyTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        let items = answers.checklist.items
        // §5 rule 10: any kidney/renal box checked is sufficient on its own, regardless of
        // KR-1 or KR-2 — KR-2 is informational only.
        guard items.contains(.kidneyDiseaseCKD) || items.contains(.currentlyOnDialysis) else {
            return []
        }
        return [.kidneyDiseaseOrDialysis]
    }

    // MARK: - Eating Disorder History

    private static func eatingDisorderTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        // D-10: SCOFF contributes only when the eating-disorder checklist item was selected.
        // If untriggered, any SCOFF value present is ignored and neither tag is derived.
        guard SCOFFResponses.isTriggered(by: answers.checklist) else { return [] }
        guard let scoff = answers.scoff else { return [] }
        return scoff.isPositiveScreen
            ? [.eatingDisorderPositiveScreen]
            : [.eatingDisorderSelfReportedNegativeScreen]
    }

    // MARK: - Food Allergies

    private static func foodAllergyTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        guard answers.checklist.items.contains(.foodAllergies) else { return [] }
        guard let fa1 = answers.fa1SevereAllergyOrEpinephrine else { return [] }
        return fa1.isCautiousBranch ? [.severeFoodAllergy] : [.nonSevereFoodAllergy]
    }

    // MARK: - Other Serious Condition

    private static func otherSeriousConditionTags(_ answers: ScreeningAnswers) -> Set<ConditionTag> {
        let items = answers.checklist.items
        // §5 rule 13: any "Other Serious Condition" box checked is sufficient on its own,
        // regardless of OS-1.
        guard items.contains(.activeCancerTreatment) || items.contains(.otherSeriousOrComplexCondition) else {
            return []
        }
        return [.otherSeriousConditionOrActiveCancerTreatment]
    }
}
