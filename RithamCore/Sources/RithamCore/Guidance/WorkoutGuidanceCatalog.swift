// Transcribed from docs/health-screening.md section 2 (Workout Adjustment Rule Table). Every
// adjustment and contraindicated-activity string below is transcribed verbatim from that
// table's substance, rather than paraphrased or generated (HEALTH-01 forbids live-generated
// advice). Following `ScreeningCopy.swift`'s own precedent for this codebase's shipped
// strings, Unicode em/en dashes in the source prose are rewritten to plain punctuation (a
// period, a comma, or "and") here; no wording is added, removed, or reworded beyond that
// substitution. This wording, like `ScreeningCopy.swift`'s, is pending LAUNCH-01 counsel
// review and ships as-is per the roadmap's own sequencing (Phase 5 gates the review, not this
// plan's build).

/// The section 2 workout rule table, exposed as one accessor per column plus the section 4.6
/// referral message and the section 2 streak-safety flag. Views must call
/// `presentableAdjustment(for:)`, never `adjustment(for:)` directly: the permission check that
/// keeps a view from rendering personalized text past a required-blocking gate lives inside
/// this catalog, not at the call site.
public enum WorkoutGuidanceCatalog {

    /// The section 2 "Workout Adjustment" column, verbatim (dash-rewritten per this file's
    /// header). Every `ConditionTag`'s row carries adjustment prose, so this currently never
    /// returns `nil` in practice; the optional return type matches the "Contraindicated /
    /// Avoid" column's own shape for symmetry and in case a future table revision leaves a row
    /// blank.
    ///
    /// This is a raw row accessor for tests and for `presentableAdjustment(for:)`'s own use.
    /// Views must call `presentableAdjustment(for:)` instead, which consults the content
    /// permission before returning any text.
    public static func adjustment(for tag: ConditionTag) -> String? {
        switch tag {
        case .under18Minor:
            return "No exercise-specific restriction from this framework based on age alone. Standard general-activity suggestions apply."
        case .age65PlusOrDeconditioned:
            return """
            Same aerobic/strength targets as any adult, plus a 3rd component: multicomponent balance and functional-strength work, prioritized ahead of aerobic work if very deconditioned. Set intensity relative to the individual (RPE or the talk test, moderate means can talk but not sing, vigorous means can say only a few words), not a fixed benchmark. Start low, progress gradually across duration/frequency/intensity, any duration counts toward weekly totals. Extra emphasis on warm-up/cool-down.
            """
        case .hypertensionManaged:
            return "Aerobic and/or resistance training most days. Resistance training is treated as roughly equivalent to aerobic work for blood-pressure benefit. Progress duration first, then frequency/intensity. Cue exhaling through the exertion phase of a lift."
        case .hypertensionUncontrolledOrUnsure:
            return "Hold personalized intensity suggestions. Offer only general, non-vigorous activity information until status is clarified."
        case .heartDiseaseStable:
            return "Gradual, supervised-style progression (cardiac-rehab-aligned pacing). Increase duration/intensity slowly based on tolerance."
        case .heartDiseaseRecentEventOrSymptomatic:
            return "Hold personalized suggestions. Direct to a cardiac-rehab program or physician-directed plan. Rest days here should never break the user's streak or trigger streak-loss messaging."
        case .arrhythmiaStable:
            return "Moderate-intensity activity is generally well-tolerated. Keep the format similar to Ritham's default aerobic/strength mix."
        case .arrhythmiaUncontrolledOrUnsure:
            return "Hold personalized intensity suggestions until rate control is established."
        case .rateLimitingHeartOrBPMedication:
            return "Use RPE or the talk test to set intensity instead of heart-rate zones. These medications blunt the heart-rate response, so HR-based targets are unreliable for this user."
        case .diabetesOnHypoglycemiaRiskMedication:
            return "Standard aerobic and resistance targets, paired with a reminder to check blood glucose before exercising and to have fast-acting carbohydrate available. Suggest rechecking after exercise given the risk of delayed post-exercise low blood sugar."
        case .diabetesNotOnHypoglycemiaRiskMedication:
            return "Standard aerobic and resistance targets. No routine glucose-check reminder needed."
        case .prediabetes:
            return "Standard consistent moderate-activity progression, resistance training encouraged as an addition."
        case .diabetesRetinopathyOrFootComplication:
            return """
            If eye disease flagged: favor low-impact modes (e.g., stationary cycling, swimming) and avoid framing suggestions around vigorous or jarring effort pending an eye exam. If foot wound/ulcer flagged: shift to non-weight-bearing suggestions until resolved, otherwise walking-type weight-bearing activity is not automatically restricted for neuropathy alone.
            """
        case .osteoarthritis:
            return """
            Low-impact aerobic modes (walking, cycling, swimming/water aerobics), strengthening of muscles around the affected joint, flexibility and balance work, gait aids/bracing during flares or longer/uneven-terrain walks. Once an individualized program is established and well-tolerated, ongoing suggestions can move to standard (no-gate) personalization.
            """
        case .osteoporosisOrOsteopenia:
            return "Weight-bearing endurance activity and progressive resistance training targeting hip and spine, balance/posture training, neutral-spine core bracing instead of flexion-based ab work."
        case .chronicLowBackPain:
            return """
            Trunk strengthening/endurance, motor-control and stabilization work, general aerobic activity, aquatic exercise, hamstring flexibility work, core-activation cueing (exhale through effort, avoid breath-holding), a "stay active" framing over rest.
            """
        case .priorInjuryOrSurgeryNotCleared:
            return "Hold loading/intensity progression for the affected area specifically. General, low-impact, non-affected-area activity can still be suggested. Rest or modified sessions here should never break the user's streak or trigger streak-loss messaging."
        case .priorInjuryOrSurgeryCleared:
            return "Conservative reintroduction: start meaningfully below prior activity level and progress gradually rather than resuming at pre-injury load immediately."
        case .musculoskeletalFlare:
            return "Temporarily treat the underlying condition as higher-caution: reduce load/intensity, favor low-impact alternatives, pause progression until the flare settles."
        case .pregnancyUncomplicated:
            return """
            Walking, swimming, stationary cycling, low-impact aerobics, modified yoga/Pilates avoiding prolonged supine positioning after the first trimester. Most uncomplicated pregnancies can continue moderate aerobic and strength activity throughout.
            """
        case .pregnancyComplicatedOrUnsure:
            return "Hold personalized suggestions entirely. General, non-quantified information only. Rest days here should never break the user's streak or trigger streak-loss messaging."
        case .postpartumUncomplicated:
            return "Pelvic-floor exercises can start immediately, light walking as tolerated within days for an uncomplicated vaginal delivery, gradual, progressive return with general/core strengthening."
        case .postpartumCSectionOrComplications:
            return "Hold personalized suggestions until explicit clearance is confirmed. General, non-quantified information only. Rest days here should never break the user's streak or trigger streak-loss messaging."
        case .kidneyDiseaseOrDialysis:
            return """
            No exercise-specific guidance was identified in the research for this project. Per the general ACSM screening principle that known renal disease should prompt medical clearance, hold personalized workout suggestions and route to the user's care team. Dialysis scheduling and fluid/electrolyte status can also affect safe exercise timing.
            """
        case .eatingDisorderPositiveScreen:
            return """
            Shift entirely away from quantified/compensatory framing (no "burn X," no streak-linked intensity pressure), general movement-for-enjoyment suggestions only. Rest days here should never break the user's streak or trigger streak-loss messaging.
            """
        case .eatingDisorderSelfReportedNegativeScreen:
            return """
            Standard workout suggestions, with quantified/compensatory framing (e.g., "calories burned this session") off by default and available only if the user explicitly opts in.
            """
        case .severeFoodAllergy:
            return "No exercise-specific adjustment identified in this framework."
        case .nonSevereFoodAllergy:
            return "No exercise-specific adjustment identified in this framework."
        case .otherSeriousConditionOrActiveCancerTreatment:
            return """
            No exercise-specific guidance was identified in the research for this project. Per general chronic-condition screening guidance, hold personalized workout suggestions and route to the user's care team. Treatment type/phase can affect fatigue, immune status, and cardiac considerations in ways this framework can't safely generalize.
            """
        case .clinicianPrescribedDietOrMealPlan:
            return "No workout-specific rule from this framework. See the nutrition catalog."
        case .noneOfTheAboveBaseline:
            return "Full standard Ritham programming: gradual progression across duration, frequency, and intensity per general adult activity guidance."
        }
    }

    /// The section 2 "Contraindicated / Avoid" column, verbatim (dash-rewritten per this
    /// file's header), returning `nil` where that column is an em dash in the source table.
    public static func contraindicated(for tag: ConditionTag) -> String? {
        switch tag {
        case .under18Minor:
            return nil
        case .age65PlusOrDeconditioned:
            return "Jumping straight into vigorous intensity or heavy loads without a gradual build-up."
        case .hypertensionManaged:
            return "Holding the breath during heavy lifts (Valsalva maneuver). Flag this specifically for anyone in this tag."
        case .hypertensionUncontrolledOrUnsure:
            return "Vigorous-intensity and heavy-resistance suggestions."
        case .heartDiseaseStable:
            return "Sudden jumps in intensity without a gradual build."
        case .heartDiseaseRecentEventOrSymptomatic:
            return "Any self-directed intensity or resistance-training suggestion."
        case .arrhythmiaStable:
            return "Sustained very-high-intensity/high-volume endurance efforts (a U-shaped intensity/arrhythmia-risk relationship is noted in the research)."
        case .arrhythmiaUncontrolledOrUnsure:
            return "Any intensity increase. New dizziness or chest pain during activity should stop the session."
        case .rateLimitingHeartOrBPMedication:
            return "Presenting or relying on heart-rate-zone-based targets for this user."
        case .diabetesOnHypoglycemiaRiskMedication:
            return "Starting exercise during symptoms of low blood sugar (shakiness, confusion, sweating, weakness) without checking/treating first."
        case .diabetesNotOnHypoglycemiaRiskMedication:
            return nil
        case .prediabetes:
            return nil
        case .diabetesRetinopathyOrFootComplication:
            return "Vigorous aerobic/resistance work, jumping/jarring movement, head-down positions for flagged retinopathy, weight-bearing activity on an active foot wound."
        case .osteoarthritis:
            return "High-impact, repetitive-loading activity (running, jumping, skiing) especially during flares, daily hard-surface impact, painful deep loaded knee flexion (modify range rather than cut entirely)."
        case .osteoporosisOrOsteopenia:
            return """
            Loaded spinal flexion (toe touches, sit-ups/crunches, rounded-forward bending), spinal twisting, especially combined with flexion, high-impact/jumping activity if bone density loss or a prior fragility fracture is significant.
            """
        case .chronicLowBackPain:
            return "Anything that causes significant pain during or hours after activity. Heavy/loaded flexion or twisting if it's pain-provoking for this individual."
        case .priorInjuryOrSurgeryNotCleared:
            return """
            Loading the affected joint/area at all beyond surgeon/PT-set limits. For shoulder/rotator cuff specifically: overhead pressing, upright rows, heavy/deep bench press, behind-the-neck movements.
            """
        case .priorInjuryOrSurgeryCleared:
            return "Jumping straight back to pre-injury intensity/volume."
        case .musculoskeletalFlare:
            return "Advancing progression during an active flare."
        case .pregnancyUncomplicated:
            return """
            Contact sports, high fall-risk activities (off-road cycling, horseback riding, downhill skiing), scuba/sky diving, hot yoga/hot Pilates. Any of the ACOG warning signs (vaginal bleeding, breathlessness before exertion, dizziness, chest pain, calf pain/swelling, regular painful contractions, decreased fetal movement, fluid leakage) should stop the session immediately.
            """
        case .pregnancyComplicatedOrUnsure:
            return "Any self-directed exercise suggestion."
        case .postpartumUncomplicated:
            return "High-intensity/high-impact activity (running, jumping) before roughly 12 weeks postpartum, or before pelvic-floor/core function is reassessed if symptoms (leaking, heaviness, pain) are present."
        case .postpartumCSectionOrComplications:
            return "Any self-directed resumption of exercise before clearance."
        case .kidneyDiseaseOrDialysis:
            return "Any self-directed intensity suggestion."
        case .eatingDisorderPositiveScreen:
            return "Any calorie-burn-framed or compensatory-exercise suggestion tied to food intake."
        case .eatingDisorderSelfReportedNegativeScreen:
            return "Framing workouts as compensation for eating."
        case .severeFoodAllergy:
            return nil
        case .nonSevereFoodAllergy:
            return nil
        case .otherSeriousConditionOrActiveCancerTreatment:
            return "Any self-directed intensity suggestion."
        case .clinicianPrescribedDietOrMealPlan:
            return nil
        case .noneOfTheAboveBaseline:
            return nil
        }
    }

    /// Section 4.6's required-blocking message, shown in place of any personalized suggestion
    /// under a blocked workout domain. Aliased to `ScreeningCopy.requiredBlockingMessage`
    /// rather than re-transcribed here, so the two copies of this message (screening flow and
    /// guidance catalog) can never drift apart, and so counsel's LAUNCH-01 review reads one
    /// copy, not two.
    public static let referralMessage: String = ScreeningCopy.requiredBlockingMessage

    /// True for exactly the five tags section 2 marks with "should never break the user's
    /// streak or trigger streak-loss messaging": Heart Disease - Recent Event/Symptomatic,
    /// Prior Injury/Surgery - Not Yet Cleared, Pregnancy - Complicated/Unsure, Postpartum -
    /// C-Section/Complications, and Eating Disorder History - Positive Screen. HEALTH-03 names
    /// these five explicitly. Phase 3's Momentum reads this rather than re-deriving the list.
    public static func neverTriggersStreakLoss(_ tag: ConditionTag) -> Bool {
        switch tag {
        case .heartDiseaseRecentEventOrSymptomatic,
             .priorInjuryOrSurgeryNotCleared,
             .pregnancyComplicatedOrUnsure,
             .postpartumCSectionOrComplications,
             .eatingDisorderPositiveScreen:
            return true
        default:
            return false
        }
    }

    /// The permission-checked accessor views must call: consults
    /// `GuidanceCatalog.contentPermission(for:domain:)` for the `.workout` domain first, and
    /// returns `referralMessage` whenever that permission is `.none`, so a view-layer bug can
    /// never reach personalized intensity text past a required-blocking gate (ASVS V4, per
    /// this plan's threat model T-02-01).
    public static func presentableAdjustment(for tag: ConditionTag) -> String {
        guard GuidanceCatalog.contentPermission(for: tag, domain: .workout) != .none else {
            return referralMessage
        }
        return adjustment(for: tag) ?? referralMessage
    }
}
