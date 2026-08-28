// Transcribed from docs/health-screening.md §2 (Workout Adjustment Rule Table) and §3
// (Nutrition Adjustment Rule Table), which share one Condition Tag vocabulary. Every row
// in both tables — including the modifier tags — has exactly one case here, so no user's
// screening answers can ever resolve to an unnamed condition state.

/// The complete condition-tag vocabulary a user's screening answers can resolve to.
///
/// This is the sole input HEALTH-06's escalation engine (plan 01-06) reasons over, and the
/// sole input the workout/nutrition rule tables key off of. `displayName` is user-facing copy
/// (D-11's persistent disclaimer tag, D-12's multi-condition listing), not a debug description.
public enum ConditionTag: String, CaseIterable, Sendable, Hashable {
    /// §1.1's Q0 routing sets this permanently on the profile for a user under 18 (re-confirmed
    /// at each birthday/re-screen). No producer for this case exists yet in `RithamCore` —
    /// `ageDerivedTags(forAge:)` deliberately does not set it, since it is scoped to the 65+
    /// tag only. It is a separate age-derived content tag from MINOR-01's 13+ eligibility
    /// floor, which plan 01-07 reads as a plain boolean off the raw age. Wiring this case's
    /// producer is tracked as an open gap for plan 01-06/01-07/01-11 — see 01-03-SUMMARY.md.
    case under18Minor
    case age65PlusOrDeconditioned
    case hypertensionManaged
    case hypertensionUncontrolledOrUnsure
    case heartDiseaseStable
    case heartDiseaseRecentEventOrSymptomatic
    case arrhythmiaStable
    case arrhythmiaUncontrolledOrUnsure
    case rateLimitingHeartOrBPMedication
    case diabetesOnHypoglycemiaRiskMedication
    case diabetesNotOnHypoglycemiaRiskMedication
    case prediabetes
    case diabetesRetinopathyOrFootComplication
    case osteoarthritis
    case osteoporosisOrOsteopenia
    case chronicLowBackPain
    case priorInjuryOrSurgeryNotCleared
    case priorInjuryOrSurgeryCleared
    case musculoskeletalFlare
    case pregnancyUncomplicated
    case pregnancyComplicatedOrUnsure
    case postpartumUncomplicated
    case postpartumCSectionOrComplications
    case kidneyDiseaseOrDialysis
    case eatingDisorderPositiveScreen
    case eatingDisorderSelfReportedNegativeScreen
    case severeFoodAllergy
    case nonSevereFoodAllergy
    case otherSeriousConditionOrActiveCancerTreatment
    case clinicianPrescribedDietOrMealPlan
    case noneOfTheAboveBaseline

    /// The human-readable tag name exactly as §2 writes it (the bolded table-cell text, with
    /// the italicized "(modifier — ...)" annotation stripped, since that annotation describes
    /// how the tag combines with others, not the tag's name). This is user-facing copy — it
    /// renders in D-11's persistent disclaimer tag and D-12's multi-condition listing.
    public var displayName: String {
        switch self {
        case .under18Minor:
            return "Under 18 (Minor)"
        case .age65PlusOrDeconditioned:
            return "65+ / Deconditioned / Returning After Inactivity"
        case .hypertensionManaged:
            return "Hypertension: Managed"
        case .hypertensionUncontrolledOrUnsure:
            return "Hypertension: Uncontrolled / Unsure"
        case .heartDiseaseStable:
            return "Heart Disease: Stable"
        case .heartDiseaseRecentEventOrSymptomatic:
            return "Heart Disease: Recent Event / Symptomatic"
        case .arrhythmiaStable:
            return "Arrhythmia: Stable / Rate-Controlled"
        case .arrhythmiaUncontrolledOrUnsure:
            return "Arrhythmia: Uncontrolled / Unsure"
        case .rateLimitingHeartOrBPMedication:
            return "Rate-Limiting Heart/BP Medication"
        case .diabetesOnHypoglycemiaRiskMedication:
            return "Diabetes (Type 1 or Type 2): On Insulin or Hypoglycemia-Risk Medication"
        case .diabetesNotOnHypoglycemiaRiskMedication:
            return "Diabetes (Type 1 or Type 2): Not on Hypoglycemia-Risk Medication"
        case .prediabetes:
            return "Prediabetes"
        case .diabetesRetinopathyOrFootComplication:
            return "Diabetes: Retinopathy / Foot Complication Flagged"
        case .osteoarthritis:
            return "Osteoarthritis"
        case .osteoporosisOrOsteopenia:
            return "Osteoporosis / Osteopenia"
        case .chronicLowBackPain:
            return "Chronic Low Back Pain"
        case .priorInjuryOrSurgeryNotCleared:
            return "Prior Injury / Surgery: Not Yet Cleared"
        case .priorInjuryOrSurgeryCleared:
            return "Prior Injury / Surgery: Cleared"
        case .musculoskeletalFlare:
            return "Musculoskeletal Flare"
        case .pregnancyUncomplicated:
            return "Pregnancy: Uncomplicated"
        case .pregnancyComplicatedOrUnsure:
            return "Pregnancy: Complicated / Unsure"
        case .postpartumUncomplicated:
            return "Postpartum: Uncomplicated"
        case .postpartumCSectionOrComplications:
            return "Postpartum: C-Section / Complications"
        case .kidneyDiseaseOrDialysis:
            return "Kidney Disease / Dialysis"
        case .eatingDisorderPositiveScreen:
            return "Eating Disorder History: Positive Screen / Active Symptoms"
        case .eatingDisorderSelfReportedNegativeScreen:
            return "Eating Disorder History: Self-Reported Only / Negative Screen"
        case .severeFoodAllergy:
            return "Severe Food Allergy"
        case .nonSevereFoodAllergy:
            return "Non-Severe Food Allergy"
        case .otherSeriousConditionOrActiveCancerTreatment:
            return "Other Serious Condition / Active Cancer Treatment"
        case .clinicianPrescribedDietOrMealPlan:
            return "Existing Clinician-Prescribed Diet or Meal Plan"
        case .noneOfTheAboveBaseline:
            return "None of the Above / Baseline"
        }
    }

    /// The sole age-to-content-tag mapping in the product (§1.1's Q0 routing). This is a
    /// content-adjustment concern only — unrelated to MINOR-01's 13+ eligibility floor, which
    /// plan 01-07 reads as a plain boolean off the raw age and never through this function.
    /// It has no opinion on ages below 65, including 13; the 13+ floor is decided elsewhere.
    public static func ageDerivedTags(forAge age: Int) -> Set<ConditionTag> {
        age >= 65 ? [.age65PlusOrDeconditioned] : []
    }
}
