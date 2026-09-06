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
}
