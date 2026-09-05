// Transcribed from docs/health-screening.md section 3 (Nutrition Adjustment Rule Table). Every
// general-guidance and prohibition string below is transcribed verbatim from that table's
// substance, rather than paraphrased or generated (HEALTH-01 forbids live-generated advice).
// Following WorkoutGuidanceCatalog.swift's own precedent for this codebase's shipped strings,
// Unicode em/en dashes in the source prose are rewritten to plain punctuation (a period, a
// comma, or a plain hyphen inside a numeric range) here; no wording is added, removed, or
// reworded beyond that substitution. Every published reference figure section 3's preamble
// names is exposed as a fixed, transcribed string through `referenceFigures(for:)` -- there is
// no arithmetic anywhere in this file, so a figure can never become a number computed from a
// specific user's data. This wording, like WorkoutGuidanceCatalog.swift's, is pending LAUNCH-02
// and LAUNCH-03 review and ships as-is per the roadmap's own sequencing (Phase 5 gates the
// review, not this plan's build).

/// A published, population-level nutrition reference figure -- a fixed string transcribed from
/// section 3's preamble, never a number Ritham computes for one specific user. Each figure
/// records the body that publishes it, so the education text this catalog exposes always
/// carries a citation.
public struct ReferenceFigure: Sendable, Equatable {
    public let label: String
    public let value: String
    public let publishingBody: String

    public init(label: String, value: String, publishingBody: String) {
        self.label = label
        self.value = value
        self.publishingBody = publishingBody
    }
}

/// The section 3 nutrition rule table, exposed as one accessor per column, the section 4.6
/// referral message, the section 3 mandatory allergen-verification flag, section 3 preamble's
/// published reference figures, and the weight-loss feature availability check section 5 rules
/// 14/15 govern. Views must call `presentableGuidance(for:)`, never `generalGuidance(for:)`
/// directly: the permission check that keeps a view from rendering personalized quantity text
/// past a required-blocking gate lives inside this catalog, not at the call site.
public enum NutritionGuidanceCatalog {

    /// The section 3 "General Guidance Direction" column, verbatim (dash-rewritten per this
    /// file's header). Returns `nil` only for `rateLimitingHeartOrBPMedication`, the sole tag
    /// with no section 3 row at all (it is a workout-only method modifier).
    ///
    /// This is a raw row accessor for tests and for `presentableGuidance(for:)`'s own use.
    /// Views must call `presentableGuidance(for:)` instead, which consults the content
    /// permission before returning any text.
    public static func generalGuidance(for tag: ConditionTag) -> String? {
        switch tag {
        case .under18Minor:
            return "General movement and food-variety education only."
        case .age65PlusOrDeconditioned:
            return "No nutrition-specific rule from this framework; standard general guidance (see the baseline row) applies."
        case .hypertensionManaged:
            return """
            DASH-style eating-pattern awareness: more vegetables, fruit, whole grains, low-fat dairy, lean protein; general sodium-awareness education, optionally citing the published 2,300mg (standard) and 1,500mg (further-reduction) reference ranges as population-level education.
            """
        case .hypertensionUncontrolledOrUnsure:
            return """
            The same DASH-style educational content as above may still be shown (it's general population guidance, low-risk to display), but no personalized quantity target of any kind, and content is paired with a clearance note.
            """
        case .heartDiseaseStable:
            return """
            AHA's general heart-pattern education: favor whole over refined grains, varied produce daily, unsaturated over saturated fats, minimize ultraprocessed foods, limit added sugar, reduce sodium; may cite the <10%/<6% saturated-fat reference ranges as general education.
            """
        case .heartDiseaseRecentEventOrSymptomatic:
            return "General heart-healthy educational content only, no personalized targets, paired with a clearance note."
        case .arrhythmiaStable, .arrhythmiaUncontrolledOrUnsure:
            return """
            No arrhythmia-specific nutrition rule was identified in the research. If hypertension or heart disease is also flagged, that row's guidance applies.
            """
        case .rateLimitingHeartOrBPMedication:
            // No section 3 row exists for this modifier -- it adjusts how workout intensity is
            // presented (section 2), not a nutrition concern.
            return nil
        case .diabetesOnHypoglycemiaRiskMedication, .diabetesNotOnHypoglycemiaRiskMedication:
            return """
            ADA's Diabetes Plate Method (half plate non-starchy vegetables, a quarter protein, a quarter carbohydrate foods, plus water) as the primary no-math framework; general carb-consistency education (keeping carb intake roughly steady meal-to-meal); added-sugar-awareness education, optionally citing the ADA's general ~45-60g-per-meal starting range and the <10%-of-calories added-sugar reference as population-level education.
            """
        case .prediabetes:
            return """
            The same Plate Method framework; general education that consistent moderate activity plus modest weight management (may cite the CDC's National DPP 5-7% figure as population-level education) is associated with lower progression risk, framed as population evidence, not a personal projection.
            """
        case .diabetesRetinopathyOrFootComplication:
            return """
            No incremental nutrition rule beyond the Diabetes row above. This flag changes exercise guidance (Section 2), not nutrition guidance, per the research reviewed.
            """
        case .osteoarthritis, .osteoporosisOrOsteopenia, .chronicLowBackPain,
             .priorInjuryOrSurgeryNotCleared, .priorInjuryOrSurgeryCleared, .musculoskeletalFlare:
            return """
            No nutrition-specific rule was identified in the research for these conditions; standard general guidance applies. Flare status (MSK-1) changes the Workout table's guidance only. It does not change nutrition guidance.
            """
        case .pregnancyUncomplicated:
            return """
            General, non-numeric educational content about eating patterns during pregnancy (e.g., "focus on nutrient-dense foods, and follow your prenatal care team's guidance on weight gain") may be shown; no calorie or weight-loss targets under any circumstance.
            """
        case .pregnancyComplicatedOrUnsure:
            return "No personalized content at all, including the general educational text allowed in the row above; referral only."
        case .postpartumUncomplicated:
            return """
            General, non-restrictive recovery-supportive education (adequate intake to support healing); no calorie-deficit target within this window without clinician input.
            """
        case .postpartumCSectionOrComplications:
            return "General educational content only, more conservative than the uncomplicated row; defer to OB clearance for anything beyond that."
        case .kidneyDiseaseOrDialysis:
            return """
            None. Zero personalized guidance of any kind, including general framework content, because protein/potassium/phosphorus/fluid needs move in different directions depending on CKD stage and dialysis status, and even dedicated renal-diet tools disclaim their own output as insufficient without an RD. In licensure states, generating individualized nutrition therapy for kidney disease without an RDN is not just inadvisable but restricted by law.
            """
        case .eatingDisorderPositiveScreen:
            return """
            None. Zero calorie, macro, weight, or portion-quantity display of any kind for this user; shift entirely to non-numeric, behavior-based content (e.g., general food-variety education) if any nutrition content is shown at all.
            """
        case .eatingDisorderSelfReportedNegativeScreen:
            return """
            General framework guidance permitted, but numeric targets (calories, macros, portions) stay off by default and require the user to explicitly opt in. Never presented as the default view.
            """
        case .severeFoodAllergy:
            return """
            Standard label-check reminder, plus a standing, mandatory "verify independently before eating" flag attached to every food-related suggestion that touches a flagged allergen category.
            """
        case .nonSevereFoodAllergy:
            return "Standard label-check reminder only."
        case .otherSeriousConditionOrActiveCancerTreatment:
            return """
            None. Zero personalized quantity guidance, for the same reason as kidney disease: malnutrition is common and often undetected in this population, and a generic deficit-oriented calculation can push in exactly the wrong direction. General referral to an oncology-credentialed dietitian only.
            """
        case .clinicianPrescribedDietOrMealPlan:
            return """
            Defer entirely to the plan the user's own doctor/dietitian already gave them; if shown at all, Ritham's role is logging/tracking against that existing plan, not generating a competing one.
            """
        case .noneOfTheAboveBaseline:
            return """
            Full personalization available: general frameworks (Plate Method-style, food-quality guidance) presented as editable starting points; calorie/macro estimates, where offered, are clearly labeled general estimates the user can adjust.
            """
        }
    }

    /// The section 3 "What Ritham Should NOT Do" column, verbatim (dash-rewritten per this
    /// file's header), returning `nil` where that column is an em dash in the source table, or
    /// where no section 3 row exists for the tag at all.
    public static func mustNotDo(for tag: ConditionTag) -> String? {
        switch tag {
        case .under18Minor:
            return """
            No weight-loss framing, no calorie targets, no macro targets, no portion-restriction guidance, no weight-loss goal-setting feature at all, independent of any condition otherwise reported, per AAP guidance that dieting itself is a discouraged behavior for minors.
            """
        case .age65PlusOrDeconditioned:
            return "Assuming reduced activity implies reduced nutrition needs."
        case .hypertensionManaged:
            return """
            Calculating or displaying a personalized sodium mg/day target; implying a specific BP outcome ("this will lower your BP to X").
            """
        case .hypertensionUncontrolledOrUnsure:
            return "Any personalized sodium, calorie, or macro number."
        case .heartDiseaseStable:
            return "Prescribing an individualized saturated-fat percentage or cholesterol mg target; suggesting supplement or medication-interaction guidance."
        case .heartDiseaseRecentEventOrSymptomatic:
            return "Any personalized calorie/macro/fat-gram number."
        case .arrhythmiaStable, .arrhythmiaUncontrolledOrUnsure:
            return "Inventing an arrhythmia-specific dietary rule not covered by the research."
        case .rateLimitingHeartOrBPMedication:
            // No section 3 row exists for this modifier.
            return nil
        case .diabetesOnHypoglycemiaRiskMedication, .diabetesNotOnHypoglycemiaRiskMedication:
            return """
            Calculating a personalized carbohydrate-gram target; any insulin-dosing or medication-adjustment suggestion (dosing decisions belong entirely with the user's clinician, never with the app).
            """
        case .prediabetes:
            return "Calculating a personalized weight-loss percentage or calorie target from the 5-7% figure."
        case .diabetesRetinopathyOrFootComplication:
            return nil
        case .osteoarthritis, .osteoporosisOrOsteopenia, .chronicLowBackPain,
             .priorInjuryOrSurgeryNotCleared, .priorInjuryOrSurgeryCleared, .musculoskeletalFlare:
            return """
            Assuming weight loss is medically indicated because of joint or back pain, and defaulting to a deficit-oriented suggestion on that basis. Goal-setting here should be the user's own choice, not an algorithmic inference from a musculoskeletal tag.
            """
        case .pregnancyUncomplicated:
            return """
            Setting a calorie deficit or weight-loss goal for this user under any circumstance. ACOG guidance is that intentional weight loss/calorie restriction is not recommended during pregnancy; also should not calculate a macro target.
            """
        case .pregnancyComplicatedOrUnsure:
            return "Any nutrition suggestion, quantified or not."
        case .postpartumUncomplicated:
            return "Offering or suggesting a weight-loss calorie target as a feature during this window; assuming breastfeeding status without asking."
        case .postpartumCSectionOrComplications:
            return "Any personalized quantity target."
        case .kidneyDiseaseOrDialysis:
            return """
            Showing any calorie, protein, potassium, phosphorus, or fluid target, even a "general" one.
            """
        case .eatingDisorderPositiveScreen:
            return """
            Displaying calorie counts, macro targets, or portion sizes; allowing this user to set a weight-loss goal in-app; any "calories remaining" or similar running total.
            """
        case .eatingDisorderSelfReportedNegativeScreen:
            return """
            Defaulting this user into calorie-deficit-forward messaging; framing food in "good/bad" terms.
            """
        case .severeFoodAllergy:
            return """
            Presenting any meal/recipe/portion suggestion as guaranteed "safe" for this user's allergy, or silently substituting around an allergen without flagging it for the user to confirm.
            """
        case .nonSevereFoodAllergy:
            return nil
        case .otherSeriousConditionOrActiveCancerTreatment:
            return "Assuming a calorie deficit is appropriate; showing any calorie/macro/portion number."
        case .clinicianPrescribedDietOrMealPlan:
            return """
            Layering Plate Method, DASH, or any other Ritham framework on top of an existing clinician-prescribed plan without that clinician's sign-off.
            """
        case .noneOfTheAboveBaseline:
            return nil
        }
    }

    /// Section 4.6's required-blocking message, shown in place of any personalized suggestion
    /// under a blocked nutrition domain. Aliased to `ScreeningCopy.requiredBlockingMessage`
    /// rather than re-transcribed here, so the screening flow and both guidance catalogs can
    /// never carry two diverging copies, and so counsel's LAUNCH-01 review reads one copy, not
    /// several.
    public static let referralMessage: String = ScreeningCopy.requiredBlockingMessage

    /// Section 3's mandatory-every-time flag: true only for the severe-food-allergy tag, per
    /// its row's standing "verify independently before eating" requirement, which never expires
    /// and cannot be toggled off.
    public static func requiresIndependentAllergenVerification(_ tag: ConditionTag) -> Bool {
        tag == .severeFoodAllergy
    }

    private static let sodiumStandardTarget = ReferenceFigure(
        label: "Sodium (standard DASH target)",
        value: "2,300 mg/day",
        publishingBody: "National Heart, Lung, and Blood Institute (DASH Eating Plan)"
    )

    private static let sodiumFurtherReductionTarget = ReferenceFigure(
        label: "Sodium (further-reduction DASH target)",
        value: "1,500 mg/day",
        publishingBody: "National Heart, Lung, and Blood Institute (DASH Eating Plan)"
    )

    private static let saturatedFatGeneralUpperBound = ReferenceFigure(
        label: "Saturated fat (general upper bound)",
        value: "under 10% of calories",
        publishingBody: "American Heart Association"
    )

    private static let saturatedFatStricterBound = ReferenceFigure(
        label: "Saturated fat (stricter bound)",
        value: "under 6% of calories",
        publishingBody: "American Heart Association"
    )

    private static let addedSugarUpperBound = ReferenceFigure(
        label: "Added sugar (upper bound)",
        value: "under 10% of calories",
        publishingBody: "American Diabetes Association"
    )

    private static let carbohydratePerMealStartingRange = ReferenceFigure(
        label: "Carbohydrate starting range per meal",
        value: "about 45-60 grams",
        publishingBody: "American Diabetes Association"
    )

    private static let bodyWeightProgressionFigure = ReferenceFigure(
        label: "Modest weight management associated with lower progression risk",
        value: "5-7% of body weight",
        publishingBody: "Centers for Disease Control and Prevention (National DPP)"
    )

    /// The section 3 preamble's published population-level reference figures relevant to a
    /// tag's row, each a fixed string transcribed from the document. Returns an empty array for
    /// any tag whose row cites no such figure. No accessor here performs arithmetic on any of
    /// these values -- every one is a fixed string, not a number computed from a specific
    /// user's data.
    public static func referenceFigures(for tag: ConditionTag) -> [ReferenceFigure] {
        switch tag {
        case .under18Minor:
            return []
        case .age65PlusOrDeconditioned:
            return []
        case .hypertensionManaged, .hypertensionUncontrolledOrUnsure:
            return [sodiumStandardTarget, sodiumFurtherReductionTarget]
        case .heartDiseaseStable:
            return [saturatedFatGeneralUpperBound, saturatedFatStricterBound]
        case .heartDiseaseRecentEventOrSymptomatic:
            return []
        case .arrhythmiaStable, .arrhythmiaUncontrolledOrUnsure:
            return []
        case .rateLimitingHeartOrBPMedication:
            return []
        case .diabetesOnHypoglycemiaRiskMedication, .diabetesNotOnHypoglycemiaRiskMedication,
             .diabetesRetinopathyOrFootComplication:
            return [carbohydratePerMealStartingRange, addedSugarUpperBound]
        case .prediabetes:
            return [bodyWeightProgressionFigure]
        case .osteoarthritis, .osteoporosisOrOsteopenia, .chronicLowBackPain,
             .priorInjuryOrSurgeryNotCleared, .priorInjuryOrSurgeryCleared, .musculoskeletalFlare:
            return []
        case .pregnancyUncomplicated, .pregnancyComplicatedOrUnsure:
            return []
        case .postpartumUncomplicated, .postpartumCSectionOrComplications:
            return []
        case .kidneyDiseaseOrDialysis:
            return []
        case .eatingDisorderPositiveScreen, .eatingDisorderSelfReportedNegativeScreen:
            return []
        case .severeFoodAllergy, .nonSevereFoodAllergy:
            return []
        case .otherSeriousConditionOrActiveCancerTreatment:
            return []
        case .clinicianPrescribedDietOrMealPlan:
            return []
        case .noneOfTheAboveBaseline:
            return []
        }
    }

    /// The permission-checked accessor views must call: consults
    /// `GuidanceCatalog.contentPermission(for:domain:)` for the `.nutrition` domain first, and
    /// returns `referralMessage` whenever that permission is `.none`, so a view-layer bug can
    /// never reach personalized nutrition text past a required-blocking gate (ASVS V4, per this
    /// plan's threat model T-02-01). For every other permission level, `generalGuidance(for:)`'s
    /// own row text already carries the correct education-only-versus-full distinction, since
    /// section 3's own prose is what determined each row's permission classification in the
    /// first place.
    public static func presentableGuidance(for tag: ConditionTag) -> String {
        let permission = GuidanceCatalog.contentPermission(for: tag, domain: .nutrition)
        guard permission != .none else {
            return referralMessage
        }
        return generalGuidance(for: tag) ?? "No nutrition-specific rule from this framework."
    }

    /// Whether the weight-management feature may be offered to a user with the given tags and
    /// goal. Delegates entirely to the already-built escalation function that checks under-18,
    /// positive-eating-disorder-screen, and below-healthy-floor status, rather than
    /// re-implementing those checks inline here -- resolving 02-RESEARCH.md Open Question 6 by
    /// naming this the single correct entry point for whichever later phase adds goal setting.
    /// Phase 2 exposes no weight-loss goal-setting screen, so this has no UI caller yet.
    public static func weightLossFeatureAvailable(
        tags: Set<ConditionTag>,
        goalBelowHealthyBMIFloor: Bool
    ) -> Bool {
        GateEscalation.weightLossFeatureGate(tags: tags, goalBelowHealthyBMIFloor: goalBelowHealthyBMIFloor) != .requiredBlocking
    }
}
