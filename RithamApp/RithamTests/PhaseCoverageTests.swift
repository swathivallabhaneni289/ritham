import Foundation
import Testing
import RithamCore
@testable import Ritham

// The phase's completeness gate: the assertions below are only meaningful once every screen
// group plan (01-13, 01-15, 01-16) and this plan's own `OnboardingCompletionRegistration` have
// landed, which is why this suite lives in the phase's last wave rather than any earlier plan.
//
// `.serialized` + `StepRegistry.reset()` in `init()` matches the pattern every other suite in
// this phase that touches `StepRegistry`'s shared static state uses (`AppShellTests`,
// `AboutYouStepTests`, `CalibrationSourceTests`, `ScreeningFlowTests`) -- running registration
// assertions concurrently with another suite touching the registry would make them
// order-dependent. `@MainActor` because `StepRegistry`/`StepBootstrap`/`OnboardingFlow` are all
// main-actor isolated.
//
// Per-Task Verification Map row -> suite that actually covers it (01-VALIDATION.md, "Per-Task
// Verification Map" table), so a reviewer can confirm no row was dropped:
//   - the two escalation rows (T-01-26 "not sure resolves cautious", T-01-25 "multi-tag
//     most-restrictive wins") and the eating-pattern trigger row (T-01-28 "SCOFF trigger") --
//     all Task 01-06-T2 -> RithamCoreTests/GateResolutionTests.swift
//     (testNotSureResolvesCautious, testMultiTagMostRestrictiveWins, testSCOFFTrigger)
//   - the tag expiry row (T-01-12, Task 01-03-T3) -> RithamCoreTests/ConditionTagExpiryTests.swift
//   - the calibration threshold row (T-01-20, Task 01-05-T1) -> RithamCoreTests/CalibrationThresholdTests.swift
//   - the no-fork row (T-01-34, Task 01-07-T3) -> RithamCoreTests/OnboardingFlowStateTests.swift
//   - the build row (T-01-50, Task 01-09-T2) -> `Scripts/build-app.sh build`
//
// These run under `RithamCore/Scripts/test-core.sh` rather than the `xcodebuild` invocations
// 01-VALIDATION.md originally drafted, because the pure-Swift core was extracted into its own
// package precisely so these gates could run before Xcode was installed on the development
// machine (01-VALIDATION.md's Toolchain Note); the behaviours asserted are unchanged.
//
// This file's own row (T-01-114, Task 01-18-T2, "every onboarding step resolves to a real
// screen") is covered directly below: `unregisteredStepsIsEmpty`,
// `everyStepResolvesWithoutTrapping`, and the `reachablePathsVisitOnlyRegisteredSteps` group.
@Suite("PhaseCoverageTests", .serialized)
@MainActor
struct PhaseCoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    // MARK: - unregisteredSteps is empty

    @Test("StepRegistry.unregisteredSteps is empty once StepBootstrap.registerAllSteps() has run")
    func unregisteredStepsIsEmpty() {
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    // MARK: - every step resolves without trapping

    @Test("StepRegistry.view(for:flow:) returns a view for every OnboardingStep without trapping")
    func everyStepResolvesWithoutTrapping() {
        let flow = OnboardingFlow()
        for step in OnboardingStep.allCases {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        // Reaching this line means no OnboardingStep case fell through to the unimplemented
        // fallback and no factory crashed while building its view.
        #expect(true)
    }

    // MARK: - registerAllSteps() is idempotent

    @Test("calling StepBootstrap.registerAllSteps() twice leaves unregisteredSteps empty and every step still resolvable")
    func registerAllStepsIsIdempotent() {
        StepBootstrap.registerAllSteps()
        StepBootstrap.registerAllSteps()

        #expect(StepRegistry.unregisteredSteps.isEmpty)

        let flow = OnboardingFlow()
        for step in OnboardingStep.allCases {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - reachable paths visit only registered steps

    /// Walks `OnboardingRouter.nextStep` from `.welcome` until it returns `nil` or repeats an
    /// already-visited step (the only self-loop in the router is `.ageIneligible`, which none
    /// of this suite's answer profiles reach). Mirrors `OnboardingRouter.isReachable`'s own
    /// loop-guarded walk.
    private func walk(_ answers: OnboardingAnswers) -> [OnboardingStep] {
        var visited: [OnboardingStep] = [.welcome]
        var seen: Set<OnboardingStep> = [.welcome]
        var current: OnboardingStep = .welcome
        while let next = OnboardingRouter.nextStep(after: current, answers: answers), !seen.contains(next) {
            visited.append(next)
            seen.insert(next)
            current = next
        }
        return visited
    }

    /// Asserts a completed walk terminates at `.home` (the router's own terminal step) and
    /// that every step visited along the way is registered -- i.e. never in
    /// `StepRegistry.unregisteredSteps` -- so no reachable path could have landed on the
    /// unimplemented-step fallback.
    private func assertReachesHomeThroughOnlyRegisteredSteps(_ answers: OnboardingAnswers) {
        let visited = walk(answers)
        #expect(visited.last == .home)

        let unregistered = Set(StepRegistry.unregisteredSteps)
        for step in visited {
            #expect(!unregistered.contains(step), "\(step) is unregistered but was reached by this walk")
        }
    }

    @Test("a baseline eligible-adult path (no gate triggers, no checklist selection, calibration completed) reaches .home through only registered steps")
    func baselinePathReachesHomeThroughOnlyRegisteredSteps() {
        var answers = OnboardingAnswers()
        answers.age = 30
        answers.screening.g1HeartConditionOrHighBP = .no
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no
        answers.screening.g4OtherOngoingCondition = .no
        answers.screening.g5MedicationOrPrescribedDiet = .no
        answers.screening.g6BoneJointSoftTissueProblem = .no
        answers.screening.g7MedicallySupervisedOnly = .no

        assertReachesHomeThroughOnlyRegisteredSteps(answers)
    }

    @Test("a skipped-calibration path bypasses the session/complete screens and still reaches .home through only registered steps")
    func skippedCalibrationPathReachesHomeThroughOnlyRegisteredSteps() {
        var answers = OnboardingAnswers()
        answers.age = 40
        answers.calibrationOutcome = .skipped
        answers.screening.g1HeartConditionOrHighBP = .no
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no
        answers.screening.g4OtherOngoingCondition = .no
        answers.screening.g5MedicationOrPrescribedDiet = .no
        answers.screening.g6BoneJointSoftTissueProblem = .no
        answers.screening.g7MedicallySupervisedOnly = .no

        let visited = walk(answers)
        #expect(!visited.contains(.calibrationSession))
        #expect(!visited.contains(.calibrationComplete))
        assertReachesHomeThroughOnlyRegisteredSteps(answers)
    }

    @Test("a gate-triggered path (G1 = yes) passes through the clearance interstitial and still reaches .home through only registered steps")
    func gateTriggeredPathReachesHomeThroughOnlyRegisteredSteps() {
        var answers = OnboardingAnswers()
        answers.age = 55
        answers.screening.g1HeartConditionOrHighBP = .yes
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no

        let visited = walk(answers)
        #expect(visited.contains(.clearanceInterstitial))
        assertReachesHomeThroughOnlyRegisteredSteps(answers)
    }

    @Test("a SCOFF-triggering checklist selection (eating-disorder-history) reaches severityFollowUps and scoffFollowUp, then .home, through only registered steps")
    func scoffTriggeredPathReachesHomeThroughOnlyRegisteredSteps() {
        var answers = OnboardingAnswers()
        answers.age = 22
        answers.screening.g1HeartConditionOrHighBP = .no
        answers.screening.g2ChestPainOrBreathlessness = .no
        answers.screening.g3DizzinessOrLossOfConsciousness = .no
        answers.screening.g4OtherOngoingCondition = .no
        answers.screening.g5MedicationOrPrescribedDiet = .no
        answers.screening.g6BoneJointSoftTissueProblem = .no
        answers.screening.g7MedicallySupervisedOnly = .no
        answers.screening.checklist.toggle(.eatingDisorderHistory)

        let visited = walk(answers)
        #expect(visited.contains(.severityFollowUps))
        #expect(visited.contains(.scoffFollowUp))
        assertReachesHomeThroughOnlyRegisteredSteps(answers)
    }

    // MARK: - every ConditionTag has a defined gate in both domains

    @Test("GateEscalation.baseGates(for:) returns a value for every ConditionTag case")
    func everyConditionTagHasADefinedGateInBothDomains() {
        for tag in ConditionTag.allCases {
            let gates = GateEscalation.baseGates(for: tag)
            // `ClearanceGate` has no optional/undefined state -- reaching this line for every
            // case already proves `baseGates(for:)`'s switch is exhaustive (a non-exhaustive
            // switch over a `CaseIterable` enum fails to build). The membership checks below
            // additionally pin that both domains resolved to one of the three recognized gate
            // levels, not merely "compiled."
            #expect(ClearanceGate.allCases.contains(gates.workout))
            #expect(ClearanceGate.allCases.contains(gates.nutrition))
        }
    }

    // MARK: - every ConditionTag has a non-empty, unique displayName

    @Test("every ConditionTag case has a non-empty, unique displayName")
    func everyConditionTagHasANonEmptyUniqueDisplayName() {
        var seen: Set<String> = []
        for tag in ConditionTag.allCases {
            let name = tag.displayName
            #expect(!name.isEmpty)
            #expect(!seen.contains(name), "duplicate displayName: \(name)")
            seen.insert(name)
        }
        #expect(seen.count == ConditionTag.allCases.count)
    }
}
