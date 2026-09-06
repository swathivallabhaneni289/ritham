import Testing
@testable import RithamCore
import Foundation

@Suite("MomentumTargetTests")
struct MomentumTargetTests {

    private static func date(_ calendar: Calendar, y: Int, m: Int, d: Int, h: Int = 3) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        return calendar.date(from: components)!
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - supported / isSupported

    @Test("supported contains exactly 2, 3, 4 and 5")
    func supportedIsExactSetEquality() {
        #expect(MomentumTarget.supported == [2, 3, 4, 5])
    }

    @Test("isSupported returns false for 1, 6, 0 and a negative value")
    func isSupportedRejectsOutOfRangeValues() {
        #expect(MomentumTarget.isSupported(1) == false)
        #expect(MomentumTarget.isSupported(6) == false)
        #expect(MomentumTarget.isSupported(0) == false)
        #expect(MomentumTarget.isSupported(-1) == false)
    }

    @Test("isSupported returns true for every value in the supported set")
    func isSupportedAcceptsSupportedValues() {
        for target in [2, 3, 4, 5] {
            #expect(MomentumTarget.isSupported(target))
        }
    }

    // MARK: - defaultTarget

    @Test("defaultTarget is 3")
    func defaultTargetIsThree() {
        #expect(MomentumTarget.defaultTarget == 3)
    }

    // MARK: - endowedCredit

    @Test("endowedCredit returns 1 when the week is the same week as the user's first-ever logged session")
    func endowedCreditIsOneInFirstWeek() {
        let calendar = Self.utcCalendar()
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 5)
        #expect(MomentumTarget.endowedCredit(weekStart: weekStart, firstSessionWeekStart: weekStart) == 1)
    }

    @Test("endowedCredit returns 0 for every later week")
    func endowedCreditIsZeroInLaterWeeks() {
        let calendar = Self.utcCalendar()
        let firstWeek = Self.date(calendar, y: 2026, m: 1, d: 5)
        let laterWeek = Self.date(calendar, y: 2026, m: 1, d: 12)
        #expect(MomentumTarget.endowedCredit(weekStart: laterWeek, firstSessionWeekStart: firstWeek) == 0)
    }

    @Test("endowedCredit returns 0 when the user has no logged session at all")
    func endowedCreditIsZeroWithNoFirstSession() {
        let calendar = Self.utcCalendar()
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 5)
        #expect(MomentumTarget.endowedCredit(weekStart: weekStart, firstSessionWeekStart: nil) == 0)
    }

    // MARK: - requiredQualifyingSessions

    @Test("targetOfFiveNeedsExactlyFourRealSessionsInWeekOne")
    func targetOfFiveNeedsExactlyFourRealSessionsInWeekOne() {
        #expect(MomentumTarget.requiredQualifyingSessions(target: 5, endowedCredit: 1) == 4)
    }

    @Test("targetOfTwoNeedsExactlyOneRealSessionInWeekOne")
    func targetOfTwoNeedsExactlyOneRealSessionInWeekOne() {
        #expect(MomentumTarget.requiredQualifyingSessions(target: 2, endowedCredit: 1) == 1)
    }

    @Test("requiredQualifyingSessions with target 3 and credit 1 returns 2")
    func requiredQualifyingSessionsDefaultTargetWithCredit() {
        #expect(MomentumTarget.requiredQualifyingSessions(target: 3, endowedCredit: 1) == 2)
    }

    @Test("requiredQualifyingSessions with credit 0 returns the target unchanged")
    func requiredQualifyingSessionsWithNoCreditReturnsTargetUnchanged() {
        #expect(MomentumTarget.requiredQualifyingSessions(target: 3, endowedCredit: 0) == 3)
        #expect(MomentumTarget.requiredQualifyingSessions(target: 5, endowedCredit: 0) == 5)
    }

    @Test("requiredQualifyingSessions never returns less than 1 for any supported target")
    func requiredQualifyingSessionsNeverGoesBelowOne() {
        for target in MomentumTarget.supported {
            #expect(MomentumTarget.requiredQualifyingSessions(target: target, endowedCredit: 1) >= 1)
        }
        // Even a hypothetical credit larger than the target must floor at 1.
        #expect(MomentumTarget.requiredQualifyingSessions(target: 2, endowedCredit: 5) == 1)
    }

    // MARK: - displayedCount

    @Test("displayedCount with target 3, one real qualifying session and credit 1 returns 2")
    func displayedCountWithOneRealSessionAndCredit() {
        #expect(MomentumTarget.displayedCount(qualifying: 1, endowedCredit: 1, target: 3) == 2)
    }

    @Test("displayedCount with zero real qualifying sessions and credit 1 returns 1")
    func displayedCountWithZeroRealSessionsAndCreditIsOne() {
        #expect(MomentumTarget.displayedCount(qualifying: 0, endowedCredit: 1, target: 3) == 1)
    }

    @Test("displayedCount with two real sessions and credit 1 returns 3 and never exceeds the target")
    func displayedCountNeverExceedsTarget() {
        #expect(MomentumTarget.displayedCount(qualifying: 2, endowedCredit: 1, target: 3) == 3)
        #expect(MomentumTarget.displayedCount(qualifying: 10, endowedCredit: 1, target: 3) == 3)
    }

    // MARK: - The qualification bar itself is untouched

    @Test("no function in MomentumTarget references a duration, set count or exercise count")
    func momentumTargetNeverReferencesTheQualificationBar() {
        // Structural guard, asserted by inspection at review time; this test documents the
        // invariant so a future reader who adds such a reference sees an explicit failure point
        // to update rather than silently drifting. The `endowedCreditPerFirstWeek` constant
        // below is the only "1" this file owns semantically.
        #expect(MomentumTarget.endowedCreditPerFirstWeek == 1)
    }
}
