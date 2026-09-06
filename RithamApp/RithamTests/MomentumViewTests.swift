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
