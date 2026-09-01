import Testing
@testable import RithamCore

@Suite("OnboardingFlowStateTests")
struct OnboardingFlowStateTests {

    // MARK: - Helpers

    /// Walks `OnboardingRouter.nextStep` forward from `.welcome`, collecting every step
    /// visited in order. Guards against `.ageIneligible`'s self-loop by stopping once a step
    /// repeats, so an under-13 traversal terminates instead of looping forever.
    private func traverse(answers: OnboardingAnswers) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [.welcome]
        var seen: Set<OnboardingStep> = [.welcome]
        var current: OnboardingStep = .welcome

        while let next = OnboardingRouter.nextStep(after: current, answers: answers) {
            if seen.contains(next) {
                break
            }
            steps.append(next)
            seen.insert(next)
            current = next
        }

        return steps
    }

    private func answers(age: Int) -> OnboardingAnswers {
        OnboardingAnswers(age: age)
    }

    // MARK: - CROSSGEN-05: no-fork guarantee at the routing level (T-01-34)

    @Test("every visited step across ages 8, 15, 40, 70 is a case of OnboardingStep")
    func everyVisitedStepIsAKnownCase() {
        for age in [8, 15, 40, 70] {
            let visited = traverse(answers: answers(age: age))
            #expect(!visited.isEmpty)
            for step in visited {
                #expect(OnboardingStep.allCases.contains(step))
            }
        }
    }

    @Test("ages 15, 40, and 70 traverse byte-for-byte identical sequences")
    func eligibleAgesTraverseIdentically() {
        let traversal15 = traverse(answers: answers(age: 15))
        let traversal40 = traverse(answers: answers(age: 40))
        let traversal70 = traverse(answers: answers(age: 70))

        #expect(traversal15 == traversal40)
        #expect(traversal40 == traversal70)
    }

    @Test("only age 8's traversal differs from the eligible ages, stopping at ageIneligible")
    func onlyIneligibleAgeDiverges() {
        let traversal8 = traverse(answers: answers(age: 8))
        let traversal15 = traverse(answers: answers(age: 15))

        #expect(traversal8 != traversal15)
        #expect(traversal8.last == .ageIneligible)
    }

    // MARK: - MINOR-01: the 13+ floor (T-01-32 / T-01-73B's routing-level counterpart)

    @Test("an under-13 age never advances past ageIneligible across repeated calls")
    func under13NeverAdvancesPastAgeIneligible() {
        let under13 = answers(age: 8)

        #expect(OnboardingRouter.nextStep(after: .age, answers: under13) == .ageIneligible)
        for _ in 0..<3 {
            #expect(OnboardingRouter.nextStep(after: .ageIneligible, answers: under13) == .ageIneligible)
        }
    }

    @Test("correcting the age to 13+ on a subsequent call routes straight to privacyExplainer")
    func correctedAgeRoutesForwardLikeAnyOtherUser() {
        let corrected = answers(age: 13)

        #expect(OnboardingRouter.nextStep(after: .age, answers: corrected) == .privacyExplainer)
        #expect(OnboardingRouter.nextStep(after: .ageIneligible, answers: corrected) == .privacyExplainer)
    }

    @Test("an unanswered age never falls through to the screening flow")
    func unansweredAgeNeverFallsThroughToScreening() {
        let unanswered = OnboardingAnswers()

        #expect(OnboardingRouter.nextStep(after: .age, answers: unanswered) == .age)
        #expect(!OnboardingRouter.isReachable(.privacyExplainer, answers: unanswered))
        #expect(!OnboardingRouter.isReachable(.gateSection, answers: unanswered))
    }

    @Test("privacyExplainer immediately follows age for every eligible age")
    func privacyExplainerImmediatelyFollowsAgeForEligibleAges() {
        for age in [13, 15, 40, 70] {
            #expect(OnboardingRouter.nextStep(after: .age, answers: answers(age: age)) == .privacyExplainer)
        }
    }

    @Test("every eligible age reaches gateSection and conditionChecklist, ending at screeningComplete/home")
    func everyEligibleAgeReachesTheFullScreening() {
        for age in [13, 15, 40, 70] {
            let visited = traverse(answers: answers(age: age))
            #expect(visited.contains(.gateSection))
            #expect(visited.contains(.conditionChecklist))
            #expect(visited.contains(.screeningComplete))
            #expect(visited.last == .home)
        }
    }

    // MARK: - D-10: the SCOFF step is conditional on the eating-disorder checklist item

    @Test("scoffFollowUp is skipped when the eating-disorder item is unselected")
    func scoffFollowUpSkippedWhenNotSelected() {
        var checklist = ChecklistSelection()
        checklist.toggle(.highBloodPressure)
        var subject = answers(age: 30)
        subject.screening.checklist = checklist

        let visited = traverse(answers: subject)
        #expect(!visited.contains(.scoffFollowUp))
        #expect(visited.contains(.severityFollowUps))
        #expect(visited.contains(.universalFollowUp))
    }

    @Test("scoffFollowUp is visited when the eating-disorder item is selected")
    func scoffFollowUpVisitedWhenSelected() {
        var checklist = ChecklistSelection()
        checklist.toggle(.eatingDisorderHistory)
        var subject = answers(age: 30)
        subject.screening.checklist = checklist

        let visited = traverse(answers: subject)
        #expect(visited.contains(.scoffFollowUp))
        #expect(subject.isSCOFFTriggered)
    }

    // MARK: - Calibration is no longer part of onboarding (2026-09-01)

    @Test("no walk from welcome ever visits a calibration step, regardless of calibrationOutcome")
    func onboardingNeverVisitsCalibration() {
        for outcome: CalibrationOutcome in [.notStarted, .skipped, .completed(CalibrationBaseline.provisional(establishedAt: .distantPast))] {
            var subject = answers(age: 30)
            subject.calibrationOutcome = outcome

            let visited = traverse(answers: subject)
            #expect(!visited.contains(.calibrationIntro))
            #expect(!visited.contains(.calibrationSession))
            #expect(!visited.contains(.calibrationComplete))
            #expect(visited.contains(.screeningOpeningDisclaimer))
        }

        #expect(!OnboardingRouter.isReachable(.calibrationIntro, answers: answers(age: 30)))
    }

    @Test("privacyExplainer routes straight to screeningOpeningDisclaimer, skipping calibration entirely")
    func privacyExplainerSkipsCalibration() {
        #expect(OnboardingRouter.nextStep(after: .privacyExplainer, answers: answers(age: 30)) == .screeningOpeningDisclaimer)
    }

    @Test("the three calibration steps' own switch arms still resolve correctly when invoked directly, since a future flow reuses them")
    func calibrationStepArmsStillResolveDirectly() {
        var skipped = answers(age: 30)
        skipped.calibrationOutcome = .skipped
        #expect(OnboardingRouter.nextStep(after: .calibrationIntro, answers: skipped) == .screeningOpeningDisclaimer)

        var notStarted = answers(age: 30)
        notStarted.calibrationOutcome = .notStarted
        #expect(OnboardingRouter.nextStep(after: .calibrationIntro, answers: notStarted) == .calibrationSession)
        #expect(OnboardingRouter.nextStep(after: .calibrationSession, answers: notStarted) == .calibrationComplete)
        #expect(OnboardingRouter.nextStep(after: .calibrationComplete, answers: notStarted) == .screeningOpeningDisclaimer)
    }

    // MARK: - Determinism

    @Test("nextStep is deterministic: identical answers yield identical results across repeated calls")
    func nextStepIsDeterministic() {
        // age 40, no gate-section "yes" answers -> deterministically .conditionChecklist,
        // not merely "some repeated value" (a run of nils would satisfy a same-value-only
        // assertion without proving anything).
        let subject = answers(age: 40)
        let results = (0..<5).map { _ in OnboardingRouter.nextStep(after: .gateSection, answers: subject) }
        #expect(results.allSatisfy { $0 == .conditionChecklist })
    }

    // MARK: - isReachable

    @Test("isReachable reflects the traversal a given answers value actually produces")
    func isReachableMatchesTraversal() {
        let eligible = answers(age: 40)
        #expect(OnboardingRouter.isReachable(.gateSection, answers: eligible))
        #expect(OnboardingRouter.isReachable(.home, answers: eligible))

        let ineligible = answers(age: 8)
        #expect(OnboardingRouter.isReachable(.ageIneligible, answers: ineligible))
        #expect(!OnboardingRouter.isReachable(.privacyExplainer, answers: ineligible))
    }

    // MARK: - invalidate

    @Test("invalidating .dietaryPattern clears allergens along with the pattern itself")
    func invalidatingDietaryPatternClearsAllergens() {
        var subject = OnboardingAnswers()
        subject.dietaryPattern = .vegetarian
        subject.allergens = [.peanuts, .shellfish]

        subject.invalidate(section: .dietaryPattern)

        #expect(subject.dietaryPattern == nil)
        #expect(subject.allergens.isEmpty)
    }
}
