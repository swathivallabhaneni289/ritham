// The single source of truth for onboarding branching. Per 01-PATTERNS.md's shared-flow-state
// rule, no view computes its own next step — every step's view (plan 01-12's app-side
// observable wrapper included) delegates to `nextStep(after:answers:)` rather than
// reimplementing any part of this decision.
//
// There is no capability-gate type consulted anywhere in this function.
// `answers.isAgeEligible` is read once, at exactly one fork (right after `.age`), and nothing
// downstream of `.dietaryPattern` branches on age at all. Per D-15, every user who clears
// MINOR-01's 13+ floor reaches the complete safety screening — gate section, condition
// checklist, SCOFF — identically, with zero parental involvement and no age-based divergence
// above the floor.

/// Decides what onboarding screen comes after `current`, given the answers collected so far.
///
/// This is the *only* branching authority in the onboarding flow — the single fork on age
/// lives here, at exactly one place, within one shared `OnboardingStep` vocabulary.
public enum OnboardingRouter {

    /// Returns the step that should be shown after `current`, or `nil` when the flow is
    /// finished (there is nothing after `.home`).
    public static func nextStep(after current: OnboardingStep, answers: OnboardingAnswers) -> OnboardingStep? {
        switch current {
        case .welcome:
            return .age

        case .age, .ageIneligible:
            // The one fork in the entire flow: age changes *which case comes next*, never
            // *which hierarchy the user is in*. An unanswered age (`nil`) must never fall
            // through to the screening flow — the gate section is equivalent to being
            // permitted to submit health data (see this plan's threat model), so "no age on
            // file" holds at `.age` exactly like "under 13" holds at `.ageIneligible`, rather
            // than defaulting forward. Re-evaluated from the live `answers.age` every call,
            // never a cached flag, so a corrected age routes forward exactly like any other
            // user's first attempt would, from either case.
            guard let isEligible = answers.isAgeEligible else { return .age }
            return isEligible ? .dietaryPattern : .ageIneligible

        case .dietaryPattern:
            // DIET-01: Q0b directly after age, unconditionally, for every user who clears
            // the floor — no exception case.
            return .privacyExplainer

        case .privacyExplainer:
            return .calibrationIntro

        case .calibrationIntro:
            // D-03: skipping calibration never blocks progress. A skipped session routes
            // straight past the session screen to the step that follows `.calibrationComplete`
            // in the normal sequence, rather than showing either the session or the
            // completion screen for a session that never happened.
            if answers.calibrationOutcome == .skipped {
                return nextStep(after: .calibrationComplete, answers: answers)
            }
            return .calibrationSession

        case .calibrationSession:
            return .calibrationComplete

        case .calibrationComplete:
            // Per D-15 there is no capability gate here at all anymore — every user who
            // cleared the 13+ floor proceeds directly and unconditionally to the complete
            // safety screening.
            return .screeningOpeningDisclaimer

        case .screeningOpeningDisclaimer:
            return .gateSection

        case .gateSection:
            return hasAnyGateYes(answers.screening) ? .clearanceInterstitial : .conditionChecklist

        case .clearanceInterstitial:
            // §1.2: the user proceeds to the checklist after either interstitial variant.
            return .conditionChecklist

        case .conditionChecklist:
            return needsSeverityFollowUps(answers.screening.checklist) ? .severityFollowUps : .universalFollowUp

        case .severityFollowUps:
            // D-10: the SCOFF step is not shown to every user, only those whose checklist
            // selection triggers it.
            return answers.isSCOFFTriggered ? .scoffFollowUp : .universalFollowUp

        case .scoffFollowUp:
            return .universalFollowUp

        case .universalFollowUp:
            return .screeningComplete

        case .screeningComplete:
            return .home

        case .home:
            return nil
        }
    }

    /// Whether `step` is reachable from `.welcome` given `answers`, by walking `nextStep`
    /// forward. Views use this rather than re-deriving reachability themselves.
    public static func isReachable(_ step: OnboardingStep, answers: OnboardingAnswers) -> Bool {
        var visited: Set<OnboardingStep> = []
        var current: OnboardingStep? = .welcome

        while let candidate = current {
            // A step that returns itself (only `.ageIneligible` does this) would otherwise
            // loop forever; once a step has been visited its reachability is already
            // decided, so stop walking.
            guard !visited.contains(candidate) else { break }
            visited.insert(candidate)

            if candidate == step { return true }
            current = nextStep(after: candidate, answers: answers)
        }

        return false
    }

    /// True when any of the gate-section questions (G1-G7) was answered "yes" — §1.2's
    /// branch to the clearance interstitial.
    private static func hasAnyGateYes(_ screening: ScreeningAnswers) -> Bool {
        [
            screening.g1HeartConditionOrHighBP,
            screening.g2ChestPainOrBreathlessness,
            screening.g3DizzinessOrLossOfConsciousness,
            screening.g4OtherOngoingCondition,
            screening.g5MedicationOrPrescribedDiet,
            screening.g6BoneJointSoftTissueProblem,
            screening.g7MedicallySupervisedOnly,
        ].contains(.yes)
    }

    /// True when the checklist selection includes at least one category whose §1.4 severity
    /// follow-ups need to be asked. The eating-disorder-history category counts — its
    /// follow-up is the SCOFF screen, reached via `.severityFollowUps` -> `.scoffFollowUp` —
    /// so a user who selects only that item still reaches `.severityFollowUps` and then, per
    /// D-10, `.scoffFollowUp`. `noneOfTheAbove` and an empty selection never need follow-ups.
    ///
    /// The one documented exception (§1.4): the Metabolic category's M-1/M-2 follow-ups do
    /// not apply when "Prediabetes" is the *only* metabolic item selected.
    private static func needsSeverityFollowUps(_ checklist: ChecklistSelection) -> Bool {
        let items = checklist.items
        guard !items.isEmpty, items != [.noneOfTheAbove] else { return false }

        let metabolicItems = items.filter { $0.category == .metabolic }
        let prediabetesAloneExemptsMetabolic = metabolicItems == [.prediabetes]

        for item in items where item != .noneOfTheAbove {
            if item.category == .metabolic, prediabetesAloneExemptsMetabolic {
                continue
            }
            return true
        }
        return false
    }
}
