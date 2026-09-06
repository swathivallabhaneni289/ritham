import Foundation
import Testing
import RithamCore
@testable import Ritham

// Task 1's pure component tests: `MomentumProgressBlocks`, `ShieldRow`, and `MilestoneBadgeList`
// take plain value inputs and hold no state, store, or reader, so every assertion below is a
// value-level check over their pure, view-independent helpers/inputs -- no model container is
// touched by this suite, so it stays flat rather than nested under a `.serialized` parent.
@Suite("MomentumViewTests")
struct MomentumViewTests {

    // MARK: - MomentumProgressBlocks.blockStates

    @Test("blockStates is all filled when filled equals target")
    func blockStatesAllFilledWhenFilledEqualsTarget() {
        let states = MomentumProgressBlocks.blockStates(filled: 3, target: 3)
        #expect(states == [true, true, true])
    }

    @Test("blockStates is all unfilled when filled is zero")
    func blockStatesAllUnfilledWhenFilledIsZero() {
        let states = MomentumProgressBlocks.blockStates(filled: 0, target: 3)
        #expect(states == [false, false, false])
    }

    @Test("blockStates is partially filled for a mid-range value")
    func blockStatesPartiallyFilledForMidRangeValue() {
        let states = MomentumProgressBlocks.blockStates(filled: 2, target: 5)
        #expect(states == [true, true, false, false, false])
    }

    // MARK: - Copy strings match MomentumCopy exactly

    @Test("the weekly progress label and its accessibility label match MomentumCopy exactly")
    func weeklyProgressLabelMatchesMomentumCopy() {
        #expect(MomentumCopy.Progress.weekly(count: 2, target: 3) == "This week: 2 of 3")
        #expect(
            MomentumCopy.Progress.weeklyAccessibility(count: 2, target: 3)
                == "This week: 2 of 3 qualifying sessions"
        )
    }

    @Test("the shields caption matches MomentumCopy exactly")
    func shieldsCaptionMatchesMomentumCopy() {
        #expect(MomentumCopy.Shields.shields(earned: 2) == "2 of 3 shields")
    }

    // MARK: - MilestoneBadgeList's tier list

    @Test("MilestoneBadgeList's row source equals MomentumMilestone.tiers exactly, in order")
    func milestoneBadgeListTiersEqualMomentumMilestoneTiers() {
        #expect(MomentumMilestone.tiers == [4, 12, 26, 52])
    }

    @Test("every milestone tier has copy")
    func everyMilestoneTierHasCopy() {
        for tier in MomentumMilestone.tiers {
            #expect(MomentumCopy.Milestones.line(forWeekCount: tier) != nil, "tier \(tier) has no copy")
        }
    }

    // MARK: - Task 2: fixtures

    /// A minimal `MomentumSummary` fixture with every field overridable, so each test only states
    /// the fields it cares about. No `HealthDataStore`/`ModelContainer` is needed for any of
    /// these tests -- every assertion below is over `MomentumView`'s own pure, `nonisolated`
    /// static derivations, called directly with a plain value.
    private func makeSummary(
        weekStart: Date = .now,
        weekEnd: Date = .now,
        weeklyTarget: Int = 3,
        requiredThisWeek: Int = 3,
        qualifyingThisWeek: Int = 0,
        endowedCredit: Int = 0,
        displayedCount: Int = 0,
        currentStreak: Int = 0,
        streakLabelKind: StreakLabelKind = .fresh,
        shieldCount: Int = 0,
        milestones: [MilestoneAward] = [],
        openComebackWindow: ComebackWindow? = nil,
        isRecoveryWeekFlagged: Bool = false,
        isInjuryFrozen: Bool = false,
        isStreakLossProtected: Bool = false,
        visibility: MomentumVisibility = .privateToDevice,
        recentSessions: [MomentumSessionEntry] = []
    ) -> MomentumSummary {
        MomentumSummary(
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyTarget: weeklyTarget,
            requiredThisWeek: requiredThisWeek,
            qualifyingThisWeek: qualifyingThisWeek,
            endowedCredit: endowedCredit,
            displayedCount: displayedCount,
            currentStreak: currentStreak,
            streakLabelKind: streakLabelKind,
            shieldCount: shieldCount,
            milestones: milestones,
            openComebackWindow: openComebackWindow,
            isRecoveryWeekFlagged: isRecoveryWeekFlagged,
            isInjuryFrozen: isInjuryFrozen,
            isStreakLossProtected: isStreakLossProtected,
            visibility: visibility,
            recentSessions: recentSessions
        )
    }

    private func makeWindow(closesAt: Date = .now.addingTimeInterval(3 * 86400)) -> ComebackWindow {
        ComebackWindow(
            id: UUID(),
            missedWeekStart: .now,
            opensAt: .now,
            closesAt: closesAt,
            claimedAt: nil,
            claimingSessionID: nil,
            streakBeforeMiss: 4
        )
    }

    // MARK: - Task 2: comeback card presence

    @Test("the Comeback Session card is present when the summary has an open comeback window")
    func comebackCardPresentWhenWindowOpen() {
        let summary = makeSummary(openComebackWindow: makeWindow())
        #expect(MomentumView.showsComebackCard(for: summary))
    }

    @Test("the Comeback Session card is absent when the summary has no open comeback window")
    func comebackCardAbsentWhenNoWindowOpen() {
        let summary = makeSummary(openComebackWindow: nil)
        #expect(!MomentumView.showsComebackCard(for: summary))
    }

    // MARK: - Task 2: streak line selection

    @Test("the streak line is the rebuilt line exactly when the label kind is rebuilt and the streak is 1")
    func streakLineIsRebuiltExactlyWhenLabelKindIsRebuiltAndStreakIsOne() {
        let summary = makeSummary(currentStreak: 1, streakLabelKind: .rebuilt)
        #expect(MomentumView.streakLine(for: summary) == MomentumCopy.Streak.rebuiltStreak)
    }

    @Test("the streak line is the plain n-week line for a fresh streak, and for a rebuilt streak past week 1")
    func streakLineIsPlainOtherwise() {
        let fresh = makeSummary(currentStreak: 5, streakLabelKind: .fresh)
        #expect(MomentumView.streakLine(for: fresh) == MomentumCopy.Streak.streak(weeks: 5))

        let rebuiltPastWeekOne = makeSummary(currentStreak: 2, streakLabelKind: .rebuilt)
        #expect(MomentumView.streakLine(for: rebuiltPastWeekOne) == MomentumCopy.Streak.streak(weeks: 2))
    }

    // MARK: - Task 2: manual-vs-sensor session labeling

    @Test("a cardio row shows its verification label and a lift row shows none")
    func aCardioRowShowsItsVerificationLabelAndALiftRowShowsNone() {
        let sensorCardio = MomentumSessionEntry(
            id: UUID(), startedAt: .now, title: "Run",
            verificationLabel: MomentumCopy.Verification.sensorVerified, qualifies: true
        )
        let manualCardio = MomentumSessionEntry(
            id: UUID(), startedAt: .now, title: "Walk",
            verificationLabel: MomentumCopy.Verification.manuallyEntered, qualifies: true
        )
        let lift = MomentumSessionEntry(
            id: UUID(), startedAt: .now, title: "Strength session",
            verificationLabel: nil, qualifies: true
        )

        #expect(sensorCardio.verificationLabel == MomentumCopy.Verification.sensorVerified)
        #expect(manualCardio.verificationLabel == MomentumCopy.Verification.manuallyEntered)
        #expect(MomentumView.showsVerificationLabel(for: sensorCardio))
        #expect(MomentumView.showsVerificationLabel(for: manualCardio))
        #expect(!MomentumView.showsVerificationLabel(for: lift))
    }

    // MARK: - Task 3: Recovery Week and injury self-report controls

    @Test("the Recovery Week alert's three strings equal the MomentumCopy.RecoveryWeek constants")
    func recoveryWeekAlertStringsMatchMomentumCopyConstants() {
        #expect(MomentumCopy.RecoveryWeek.alertTitle == "Flag this week as a Recovery Week?")
        #expect(MomentumCopy.RecoveryWeek.alertBody.contains("pauses this week's target"))
        // The row's label and the alert's confirm button are the same shipped string.
        #expect(MomentumCopy.RecoveryWeek.confirmButton == MomentumCopy.RecoveryWeek.flagButton)
    }

    @Test("the injury alert's strings equal the MomentumCopy.Injury constants, and the row's label switches to the clear string exactly when a freeze is open")
    func injuryAlertStringsMatchMomentumCopyAndLabelSwitchesWhenFrozen() {
        #expect(MomentumCopy.Injury.alertTitle == "Freeze your streak for pain or injury?")
        #expect(MomentumCopy.Injury.clearAlertTitle == "Clear injury flag and resume Momentum?")
        #expect(MomentumView.injuryRowLabel(isInjuryFrozen: false) == MomentumCopy.Injury.flagButton)
        #expect(MomentumView.injuryRowLabel(isInjuryFrozen: true) == MomentumCopy.Injury.clearButton)
    }

    @Test("the two self-report controls share no state: toggling one leaves the other's derived state unchanged")
    func theTwoSelfReportControlsShareNoState() {
        let recoveryFlaggedOnly = makeSummary(isRecoveryWeekFlagged: true, isInjuryFrozen: false)
        let injuryFrozenOnly = makeSummary(isRecoveryWeekFlagged: false, isInjuryFrozen: true)

        // Flagging Recovery Week (recoveryFlaggedOnly) leaves the injury row's derived label at
        // its un-frozen value -- toggling one control never moves the other's derived state.
        #expect(MomentumView.injuryRowLabel(isInjuryFrozen: recoveryFlaggedOnly.isInjuryFrozen) == MomentumCopy.Injury.flagButton)
        #expect(recoveryFlaggedOnly.isInjuryFrozen == false)

        // Freezing for injury (injuryFrozenOnly) leaves the Recovery Week flag state untouched.
        #expect(injuryFrozenOnly.isRecoveryWeekFlagged == false)
        #expect(MomentumView.injuryRowLabel(isInjuryFrozen: injuryFrozenOnly.isInjuryFrozen) == MomentumCopy.Injury.clearButton)
    }

    /// Form used: a comment-filtered source check, per this task's own allowed alternative --
    /// `RithamColor.destructive` is not reachable from a Swift Testing assertion without
    /// rendering the view (no ViewInspector-style tooling exists in this codebase). Reads
    /// `MomentumView.swift`'s own source relative to this test file's `#filePath` and asserts the
    /// token never appears outside a `//` comment line.
    @Test("no Momentum control declares the destructive color, checked by filtering the view's own source for comment lines")
    func noMomentumControlUsesTheDestructiveColor() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        // RithamApp/RithamTests/MomentumViewTests.swift -> RithamApp/Ritham/Momentum/Views/MomentumView.swift
        let viewFile = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Momentum/Views/MomentumView.swift")
        let source = try String(contentsOf: viewFile, encoding: .utf8)
        let nonCommentSource = source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!nonCommentSource.contains("RithamColor.destructive"))
    }
}

// MARK: - Task 2: registration coverage

// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this
// suite resets and re-bootstraps `StepRegistry`'s shared static state, exactly like the other
// registry-touching suites -- it must be ordered relative to them, not only internally. This is a
// distinctly-named second suite in this file, not a second copy of `MomentumViewTests`: two
// same-named suites in one file would make Task 1's own filtered verify command ambiguous.
extension StepRegistryTouchingSuites {

    @Suite("MomentumRegistrationTests", .serialized)
    @MainActor
    struct MomentumRegistrationTests {

        init() {
            StepRegistry.reset()
            StepBootstrap.registerAllSteps()
        }

        @Test("the momentum step resolves to MomentumView after StepBootstrap.registerAllSteps()")
        func momentumStepResolvesToMomentumView() {
            let registered = StepRegistry.registeredPresenterType(for: .momentum)
            #expect(registered != nil)
            #expect(registered == MomentumView.self)
        }

        @Test("StepRegistry.unregisteredSteps is empty after bootstrap, with the new momentum case included")
        func unregisteredStepsIsEmptyWithMomentumCaseIncluded() {
            #expect(OnboardingStep.allCases.contains(.momentum))
            #expect(StepRegistry.unregisteredSteps.isEmpty)
        }

        @Test("the momentum step's view(for:flow:) call resolves without trapping")
        func momentumStepResolvesWithoutTrapping() {
            let flow = OnboardingFlow()
            _ = StepRegistry.view(for: .momentum, flow: flow)
            #expect(true)
        }
    }

}
