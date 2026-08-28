// Per 01-PATTERNS.md's shared-flow-state rule, `OnboardingAnswers` is the single home for
// every branching-relevant answer the onboarding flow collects. No view may hold wizard
// answers in local state — back-navigation would lose them, and cross-step branching
// (OnboardingRouter) could not query them if they lived anywhere else.
//
// There is no `consentState` field and no consent-state machine carried anywhere on this
// type — D-14 removed tiered consent entirely, so the raw `age: Int?` below is the only
// thing an age answer needs to hold; `isAgeEligible` is the only age-derived routing signal
// this aggregate exposes.

/// Every independently editable unit of the onboarding/screening flow. D-09: editing one
/// answer later (e.g. from Settings) re-checks only that specific section, not the entire
/// questionnaire.
///
/// `dietaryPattern` is editable with no re-screen consequence at all — DIET-01 gives dietary
/// pattern no expiry.
public enum EditableSection: Sendable, CaseIterable, Codable {
    case dietaryPattern
    case gateSection
    case conditionChecklist
    case severityFollowUps
    case scoff
}

/// The outcome of the calibration step of onboarding.
///
/// Per D-03, skipping calibration is a first-class outcome that still yields a usable
/// provisional baseline — `skipped` is a real state, not an absence. The provisional
/// baseline for a skipped session is derived at read time via
/// `CalibrationBaseline.provisional(establishedAt:)`; skipping never blocks progress.
public enum CalibrationOutcome: Sendable, Equatable, Codable {
    case notStarted
    case skipped
    case completed(CalibrationBaseline)
}

/// Everything the onboarding/screening flow collects, aggregated into one place so
/// `OnboardingRouter` and every step's view read the same source of truth.
public struct OnboardingAnswers: Sendable, Equatable, Codable {
    public var age: Int?
    public var dietaryPattern: DietaryPattern?
    public var privacyExplainerAcknowledged: Bool
    public var calibrationOutcome: CalibrationOutcome
    public var screening: ScreeningAnswers
    public var completedSteps: Set<OnboardingStep>

    public init(
        age: Int? = nil,
        dietaryPattern: DietaryPattern? = nil,
        privacyExplainerAcknowledged: Bool = false,
        calibrationOutcome: CalibrationOutcome = .notStarted,
        screening: ScreeningAnswers = ScreeningAnswers(),
        completedSteps: Set<OnboardingStep> = []
    ) {
        self.age = age
        self.dietaryPattern = dietaryPattern
        self.privacyExplainerAcknowledged = privacyExplainerAcknowledged
        self.calibrationOutcome = calibrationOutcome
        self.screening = screening
        self.completedSteps = completedSteps
    }

    /// The *only* age-derived routing signal on this aggregate: whether the raw age clears
    /// MINOR-01's 13+ floor. `nil` when age is unset. There is no `tier` property and no
    /// `consentGate` property — every age 13 and up takes the identical path, so a boolean is
    /// the entire vocabulary MINOR-01 needs here now.
    public var isAgeEligible: Bool? {
        age.map { $0 >= 13 }
    }

    /// The pre-existing 65+/deconditioned content-adjustment tag (`ConditionTag.ageDerivedTags`,
    /// plan 01-03), empty when age is unset. Unrelated to `isAgeEligible` — this is a content
    /// concern, not an eligibility concern, and neither derives from the other.
    public var ageDerivedTags: Set<ConditionTag> {
        guard let age else { return [] }
        return ConditionTag.ageDerivedTags(forAge: age)
    }

    /// Whether the SCOFF screen applies to this user's checklist selection — D-10: the SCOFF
    /// screen is shown only to users who selected the eating-disorder-history checklist item.
    public var isSCOFFTriggered: Bool {
        SCOFFResponses.isTriggered(by: screening.checklist)
    }

    /// Clears the answers and completed-step markers belonging to exactly one editable
    /// section, supporting D-09's "editing one answer later re-checks only that section" rule.
    public mutating func invalidate(section: EditableSection) {
        switch section {
        case .dietaryPattern:
            dietaryPattern = nil
            completedSteps.remove(.dietaryPattern)

        case .gateSection:
            screening.g1HeartConditionOrHighBP = nil
            screening.g2ChestPainOrBreathlessness = nil
            screening.g3DizzinessOrLossOfConsciousness = nil
            screening.g4OtherOngoingCondition = nil
            screening.g5MedicationOrPrescribedDiet = nil
            screening.g6BoneJointSoftTissueProblem = nil
            screening.g7MedicallySupervisedOnly = nil
            screening.med1RateLimitingHeartOrBPMedication = nil
            screening.med2ClinicianPrescribedDietOrMealPlan = nil
            completedSteps.remove(.gateSection)
            completedSteps.remove(.clearanceInterstitial)

        case .conditionChecklist:
            screening.checklist = ChecklistSelection()
            completedSteps.remove(.conditionChecklist)

        case .severityFollowUps:
            screening.cv1RecentCardiacEvent = nil
            screening.cv2BloodPressureControl = nil
            screening.cv2bRhythmControl = nil
            screening.m1InsulinOrHypoglycemiaRiskMedication = nil
            screening.m2RetinopathyNeuropathyOrFootWound = nil
            screening.msk1CurrentFlare = nil
            screening.msk2SurgicalClearance = nil
            screening.pg1PregnancyComplications = nil
            screening.pp1CSectionOrDeliveryComplications = nil
            screening.pp2WeeksPostpartum = nil
            screening.kr1CurrentlyOnDialysis = nil
            screening.kr2SpecificDietaryLimits = nil
            screening.fa1SevereAllergyOrEpinephrine = nil
            screening.os1NewDiagnosisOrTreatmentChange = nil
            completedSteps.remove(.severityFollowUps)

        case .scoff:
            screening.scoff = nil
            completedSteps.remove(.scoffFollowUp)
        }
    }
}
