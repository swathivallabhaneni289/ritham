// The fixed-choice answer vocabulary for docs/health-screening.md §1's intake flow. HEALTH-01
// forbids free text anywhere in this flow, so every answer type below is a closed enum with
// no `String` payload beyond an enum's own `RawValue` identity — the only numeric input in
// the entire questionnaire is Q0's age, which lives outside this file on `ScreeningAnswers`.

/// A plain yes/no answer. Used by every gate/follow-up question in §1.2/§1.4 whose option
/// list is literally `Yes / No` (G1-G7, MED-2, CV-1, MSK-1, PP-1, KR-1, ED-1 through ED-5,
/// OS-1, U-1).
public enum YesNo: Sendable, CaseIterable {
    case yes
    case no
}

/// A yes/no/not-sure answer. Used by every follow-up whose option list is
/// `Yes / No / Not sure` (MED-1, M-1, M-2, PG-1, KR-2, FA-1).
public enum YesNoUnsure: Sendable, CaseIterable {
    case yes
    case no
    case notSure

    /// HEALTH-06's governing principle (§5) is that "Not sure" always resolves to the more
    /// cautious branch, same as an explicit "yes". Expressing that once here means plan
    /// 01-06 cannot forget it at an individual rule site.
    public var isCautiousBranch: Bool {
        switch self {
        case .yes, .notSure:
            return true
        case .no:
            return false
        }
    }
}

/// CV-2's blood-pressure-control answer.
public enum BloodPressureControl: Sendable, CaseIterable {
    case wellControlled
    case notSureOrNotChecked
    case doctorSaysHigh
}

/// CV-2b's heart-rhythm-control answer.
public enum RhythmControl: Sendable, CaseIterable {
    case yes
    case notSure
    case no
}

/// MSK-2's surgical/PT-clearance answer.
public enum SurgicalClearance: Sendable, CaseIterable {
    case fullyCleared
    case stillInRecoveryNotCleared
    case notApplicable
}

/// PP-2's weeks-postpartum answer.
public enum PostpartumWeeks: Sendable, CaseIterable {
    case underSix
    case sixToTwelve
    case overTwelve
}

/// The nine condition categories §1.3's checklist is organized into, plus a tenth sentinel
/// category for `ChecklistItem.noneOfTheAbove`, which is not itself a condition category but
/// still needs a well-defined, testable `category` value (see `ChecklistItem.category`).
public enum ChecklistCategory: String, CaseIterable, Sendable {
    case cardiovascular
    case metabolic
    case musculoskeletalJoint
    case pregnancy
    case postpartum
    case kidneyRenal
    case eatingDisorderHistory
    case foodAllergies
    case otherSeriousCondition
    /// Not one of §1.3's nine condition categories — the exclusionary sentinel selection.
    case none
}

/// One checkbox from §1.3's condition checklist, plus the `noneOfTheAbove` sentinel.
public enum ChecklistItem: String, CaseIterable, Sendable, Hashable {
    // Cardiovascular
    case highBloodPressure
    case heartDisease
    case irregularHeartbeat
    case otherHeartOrCirculatoryCondition

    // Metabolic
    case type1Diabetes
    case type2Diabetes
    case prediabetes
    case otherMetabolicCondition

    // Musculoskeletal / Joint
    case osteoarthritis
    case osteoporosisOrOsteopenia
    case chronicLowBackPain
    case priorInjuryOrSurgery

    // Pregnancy
    case currentlyPregnant

    // Postpartum
    case postpartum

    // Kidney / Renal
    case kidneyDiseaseCKD
    case currentlyOnDialysis

    // Eating Disorder History
    case eatingDisorderHistory

    // Food Allergies
    case foodAllergies

    // Other Serious Condition
    case activeCancerTreatment
    case otherSeriousOrComplexCondition

    // Exclusionary sentinel
    case noneOfTheAbove

    public var category: ChecklistCategory {
        switch self {
        case .highBloodPressure, .heartDisease, .irregularHeartbeat, .otherHeartOrCirculatoryCondition:
            return .cardiovascular
        case .type1Diabetes, .type2Diabetes, .prediabetes, .otherMetabolicCondition:
            return .metabolic
        case .osteoarthritis, .osteoporosisOrOsteopenia, .chronicLowBackPain, .priorInjuryOrSurgery:
            return .musculoskeletalJoint
        case .currentlyPregnant:
            return .pregnancy
        case .postpartum:
            return .postpartum
        case .kidneyDiseaseCKD, .currentlyOnDialysis:
            return .kidneyRenal
        case .eatingDisorderHistory:
            return .eatingDisorderHistory
        case .foodAllergies:
            return .foodAllergies
        case .activeCancerTreatment, .otherSeriousOrComplexCondition:
            return .otherSeriousCondition
        case .noneOfTheAbove:
            return .none
        }
    }
}

/// The user's current condition-checklist selection. §1.3 states that choosing "None of the
/// above" clears any other selection; that rule is enforced inside `toggle`, the type's only
/// mutator, so no view can ever produce a contradictory selection containing both
/// `noneOfTheAbove` and another item.
public struct ChecklistSelection: Sendable, Equatable {
    public private(set) var items: Set<ChecklistItem>

    public init(items: Set<ChecklistItem> = []) {
        self.items = items
    }

    /// Toggles `item`'s membership in the selection. Selecting `noneOfTheAbove` empties the
    /// set first (then adds it back); selecting any other item removes `noneOfTheAbove`
    /// before applying the normal add/remove toggle.
    public mutating func toggle(_ item: ChecklistItem) {
        if item == .noneOfTheAbove {
            if items.contains(.noneOfTheAbove) {
                items.remove(.noneOfTheAbove)
            } else {
                items = [.noneOfTheAbove]
            }
            return
        }

        items.remove(.noneOfTheAbove)
        if items.contains(item) {
            items.remove(item)
        } else {
            items.insert(item)
        }
    }
}

/// The full set of answers a user has given through the screening flow. Every field is
/// optional because the flow fills them progressively and branches skip inapplicable
/// questions (e.g. CV-2 only exists once "High blood pressure" is checked).
public struct ScreeningAnswers: Sendable, Equatable {
    // §1.1
    public var age: Int?

    // §1.2 gate section (G1-G7) and its immediate MED-1/MED-2 follow-ups
    public var g1HeartConditionOrHighBP: YesNo?
    public var g2ChestPainOrBreathlessness: YesNo?
    public var g3DizzinessOrLossOfConsciousness: YesNo?
    public var g4OtherOngoingCondition: YesNo?
    public var g5MedicationOrPrescribedDiet: YesNo?
    public var g6BoneJointSoftTissueProblem: YesNo?
    public var g7MedicallySupervisedOnly: YesNo?
    public var med1RateLimitingHeartOrBPMedication: YesNoUnsure?
    public var med2ClinicianPrescribedDietOrMealPlan: YesNo?

    // §1.3 condition checklist
    public var checklist: ChecklistSelection

    // §1.4 severity/context follow-ups
    public var cv1RecentCardiacEvent: YesNo?
    public var cv2BloodPressureControl: BloodPressureControl?
    public var cv2bRhythmControl: RhythmControl?
    public var m1InsulinOrHypoglycemiaRiskMedication: YesNoUnsure?
    public var m2RetinopathyNeuropathyOrFootWound: YesNoUnsure?
    public var msk1CurrentFlare: YesNo?
    public var msk2SurgicalClearance: SurgicalClearance?
    public var pg1PregnancyComplications: YesNoUnsure?
    public var pp1CSectionOrDeliveryComplications: YesNo?
    public var pp2WeeksPostpartum: PostpartumWeeks?
    public var kr1CurrentlyOnDialysis: YesNo?
    public var kr2SpecificDietaryLimits: YesNoUnsure?
    public var scoff: SCOFFResponses?
    public var fa1SevereAllergyOrEpinephrine: YesNoUnsure?
    public var os1NewDiagnosisOrTreatmentChange: YesNo?
    public var u1AgeOrDeconditioned: YesNo?

    public init(
        age: Int? = nil,
        g1HeartConditionOrHighBP: YesNo? = nil,
        g2ChestPainOrBreathlessness: YesNo? = nil,
        g3DizzinessOrLossOfConsciousness: YesNo? = nil,
        g4OtherOngoingCondition: YesNo? = nil,
        g5MedicationOrPrescribedDiet: YesNo? = nil,
        g6BoneJointSoftTissueProblem: YesNo? = nil,
        g7MedicallySupervisedOnly: YesNo? = nil,
        med1RateLimitingHeartOrBPMedication: YesNoUnsure? = nil,
        med2ClinicianPrescribedDietOrMealPlan: YesNo? = nil,
        checklist: ChecklistSelection = ChecklistSelection(),
        cv1RecentCardiacEvent: YesNo? = nil,
        cv2BloodPressureControl: BloodPressureControl? = nil,
        cv2bRhythmControl: RhythmControl? = nil,
        m1InsulinOrHypoglycemiaRiskMedication: YesNoUnsure? = nil,
        m2RetinopathyNeuropathyOrFootWound: YesNoUnsure? = nil,
        msk1CurrentFlare: YesNo? = nil,
        msk2SurgicalClearance: SurgicalClearance? = nil,
        pg1PregnancyComplications: YesNoUnsure? = nil,
        pp1CSectionOrDeliveryComplications: YesNo? = nil,
        pp2WeeksPostpartum: PostpartumWeeks? = nil,
        kr1CurrentlyOnDialysis: YesNo? = nil,
        kr2SpecificDietaryLimits: YesNoUnsure? = nil,
        scoff: SCOFFResponses? = nil,
        fa1SevereAllergyOrEpinephrine: YesNoUnsure? = nil,
        os1NewDiagnosisOrTreatmentChange: YesNo? = nil,
        u1AgeOrDeconditioned: YesNo? = nil
    ) {
        self.age = age
        self.g1HeartConditionOrHighBP = g1HeartConditionOrHighBP
        self.g2ChestPainOrBreathlessness = g2ChestPainOrBreathlessness
        self.g3DizzinessOrLossOfConsciousness = g3DizzinessOrLossOfConsciousness
        self.g4OtherOngoingCondition = g4OtherOngoingCondition
        self.g5MedicationOrPrescribedDiet = g5MedicationOrPrescribedDiet
        self.g6BoneJointSoftTissueProblem = g6BoneJointSoftTissueProblem
        self.g7MedicallySupervisedOnly = g7MedicallySupervisedOnly
        self.med1RateLimitingHeartOrBPMedication = med1RateLimitingHeartOrBPMedication
        self.med2ClinicianPrescribedDietOrMealPlan = med2ClinicianPrescribedDietOrMealPlan
        self.checklist = checklist
        self.cv1RecentCardiacEvent = cv1RecentCardiacEvent
        self.cv2BloodPressureControl = cv2BloodPressureControl
        self.cv2bRhythmControl = cv2bRhythmControl
        self.m1InsulinOrHypoglycemiaRiskMedication = m1InsulinOrHypoglycemiaRiskMedication
        self.m2RetinopathyNeuropathyOrFootWound = m2RetinopathyNeuropathyOrFootWound
        self.msk1CurrentFlare = msk1CurrentFlare
        self.msk2SurgicalClearance = msk2SurgicalClearance
        self.pg1PregnancyComplications = pg1PregnancyComplications
        self.pp1CSectionOrDeliveryComplications = pp1CSectionOrDeliveryComplications
        self.pp2WeeksPostpartum = pp2WeeksPostpartum
        self.kr1CurrentlyOnDialysis = kr1CurrentlyOnDialysis
        self.kr2SpecificDietaryLimits = kr2SpecificDietaryLimits
        self.scoff = scoff
        self.fa1SevereAllergyOrEpinephrine = fa1SevereAllergyOrEpinephrine
        self.os1NewDiagnosisOrTreatmentChange = os1NewDiagnosisOrTreatmentChange
        self.u1AgeOrDeconditioned = u1AgeOrDeconditioned
    }
}
