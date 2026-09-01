// The fixed-choice answer vocabulary for docs/health-screening.md §1's intake flow. HEALTH-01
// forbids free text anywhere in this flow, so every answer type below is a closed enum with
// no `String` payload beyond an enum's own `RawValue` identity — the only numeric input in
// the entire questionnaire is Q0's age, which lives outside this file on `ScreeningAnswers`.

/// A plain yes/no answer. Used by every gate/follow-up question in §1.2/§1.4 whose option
/// list is literally `Yes / No` (G1-G7, MED-2, CV-1, MSK-1, PP-1, KR-1, ED-1 through ED-5,
/// OS-1, U-1).
public enum YesNo: Sendable, CaseIterable, Codable {
    case yes
    case no
}

/// A yes/no/not-sure answer. Used by every follow-up whose option list is
/// `Yes / No / Not sure` (MED-1, M-1, M-2, PG-1, KR-2, FA-1).
public enum YesNoUnsure: Sendable, CaseIterable, Codable {
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
public enum BloodPressureControl: Sendable, CaseIterable, Codable {
    case wellControlled
    case notSureOrNotChecked
    case doctorSaysHigh
}

/// CV-2b's heart-rhythm-control answer.
public enum RhythmControl: Sendable, CaseIterable, Codable {
    case yes
    case notSure
    case no
}

/// MSK-2's surgical/PT-clearance answer.
public enum SurgicalClearance: Sendable, CaseIterable, Codable {
    case fullyCleared
    case stillInRecoveryNotCleared
    case notApplicable
}

/// PP-2's weeks-postpartum answer.
public enum PostpartumWeeks: Sendable, CaseIterable, Codable {
    case underSix
    case sixToTwelve
    case overTwelve
}

/// The nine condition categories §1.3's checklist is organized into, plus a tenth sentinel
/// category for `ChecklistItem.noneOfTheAbove`, which is not itself a condition category but
/// still needs a well-defined, testable `category` value (see `ChecklistItem.category`).
public enum ChecklistCategory: String, CaseIterable, Sendable, Codable {
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
public enum ChecklistItem: String, CaseIterable, Sendable, Hashable, Codable {
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

    /// The checkbox label exactly as §1.3 writes it. User-facing copy (plan 01-16's condition
    /// checklist screen), mirroring the `ConditionTag.displayName` pattern (plan 01-06) so every
    /// screening-flow label has one addressable, verbatim source rather than being re-transcribed
    /// per call site.
    public var displayName: String {
        switch self {
        case .highBloodPressure:
            return "High blood pressure"
        case .heartDisease:
            return "Heart disease (including a prior heart attack, heart failure, coronary artery disease, or a cardiac surgery/procedure)"
        case .irregularHeartbeat:
            return "Irregular heartbeat (arrhythmia, e.g., atrial fibrillation)"
        case .otherHeartOrCirculatoryCondition:
            return "Another heart or circulatory condition"
        case .type1Diabetes:
            return "Type 1 diabetes"
        case .type2Diabetes:
            return "Type 2 diabetes"
        case .prediabetes:
            return "Prediabetes"
        case .otherMetabolicCondition:
            return "Another metabolic condition"
        case .osteoarthritis:
            return "Osteoarthritis (knee, hip, or other joint)"
        case .osteoporosisOrOsteopenia:
            return "Osteoporosis or osteopenia (low bone density)"
        case .chronicLowBackPain:
            return "Chronic or ongoing low back pain"
        case .priorInjuryOrSurgery:
            return "A prior injury or surgery (e.g., joint replacement, ACL repair, rotator cuff repair)"
        case .currentlyPregnant:
            return "Currently pregnant"
        case .postpartum:
            return "Postpartum (gave birth within the last 12 months)"
        case .kidneyDiseaseCKD:
            return "Diagnosed kidney disease (CKD)"
        case .currentlyOnDialysis:
            return "Currently on dialysis"
        case .eatingDisorderHistory:
            return "Current or past eating disorder, disordered eating, or a difficult relationship with food or exercise"
        case .foodAllergies:
            return "I have one or more food allergies"
        case .activeCancerTreatment:
            return "Currently undergoing treatment for cancer (e.g., chemotherapy or radiation)"
        case .otherSeriousOrComplexCondition:
            return "Another serious or complex condition not listed above"
        case .noneOfTheAbove:
            return "None of the above"
        }
    }
}

/// The user's current condition-checklist selection. §1.3 states that choosing "None of the
/// above" clears any other selection; that rule is enforced inside `toggle`, the type's only
/// item-level mutator, so no view can ever produce a contradictory selection containing both
/// `noneOfTheAbove` and another item.
public struct ChecklistSelection: Sendable, Equatable, Codable {
    public private(set) var items: Set<ChecklistItem>

    /// Categories the user has explicitly confirmed "none of these apply to me" for, via
    /// `toggleNoneForSection(_:sectionItems:)`. Kept separate from `items` being merely empty --
    /// live-review feedback (2026-09-01) wanted each checklist section to carry its own "None of
    /// the above" rather than one global one at the end, and a health screening should be able to
    /// tell "the user reviewed this section and confirmed nothing applies" apart from "the user
    /// hasn't looked at this section yet." `.noneOfTheAbove` (the global sentinel `toggle`
    /// enforces above) still means "nothing anywhere, full stop" and remains untouched by this.
    public private(set) var noneConfirmedCategories: Set<ChecklistCategory>

    public init(items: Set<ChecklistItem> = [], noneConfirmedCategories: Set<ChecklistCategory> = []) {
        self.items = items
        self.noneConfirmedCategories = noneConfirmedCategories
    }

    /// Toggles `item`'s membership in the selection. Selecting `noneOfTheAbove` empties the
    /// set first (then adds it back) and clears every section's confirmation, since the global
    /// sentinel already implies all of them; selecting any other item removes `noneOfTheAbove`
    /// and that item's own section confirmation before applying the normal add/remove toggle.
    public mutating func toggle(_ item: ChecklistItem) {
        if item == .noneOfTheAbove {
            if items.contains(.noneOfTheAbove) {
                items.remove(.noneOfTheAbove)
            } else {
                items = [.noneOfTheAbove]
                noneConfirmedCategories.removeAll()
            }
            return
        }

        items.remove(.noneOfTheAbove)
        noneConfirmedCategories.remove(item.category)
        if items.contains(item) {
            items.remove(item)
        } else {
            items.insert(item)
        }
    }

    /// Toggles a per-section "none of these apply" confirmation. `sectionCategories` is normally
    /// one category, except the pregnancy/postpartum view groups two under a single confirmation
    /// (`ConditionChecklistView` follows §1.3's visual grouping, not `ChecklistCategory`'s split --
    /// see that view's own comment). Turning the confirmation on clears any already-selected
    /// items in `sectionItems`; selecting any of those items back through `toggle(_:)` clears the
    /// confirmation off again, the same way selecting any item already clears the global
    /// `noneOfTheAbove` sentinel above.
    public mutating func toggleNoneForSection(
        _ sectionCategories: Set<ChecklistCategory>,
        sectionItems: Set<ChecklistItem>
    ) {
        if noneConfirmedCategories.isSuperset(of: sectionCategories) {
            noneConfirmedCategories.subtract(sectionCategories)
        } else {
            noneConfirmedCategories.formUnion(sectionCategories)
            items.subtract(sectionItems)
            items.remove(.noneOfTheAbove)
        }
    }
}

/// The full set of answers a user has given through the screening flow. Every field is
/// optional because the flow fills them progressively and branches skip inapplicable
/// questions (e.g. CV-2 only exists once "High blood pressure" is checked).
public struct ScreeningAnswers: Sendable, Equatable, Codable {
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
