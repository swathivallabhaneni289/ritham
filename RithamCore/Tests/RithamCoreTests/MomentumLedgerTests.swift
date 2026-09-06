import Testing
@testable import RithamCore
import Foundation

@Suite("MomentumLedgerTests")
struct MomentumLedgerTests {

    private static func date(_ calendar: Calendar, y: Int, m: Int, d: Int, h: Int = 3, min: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        return calendar.date(from: components)!
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - MomentumVisibility

    @Test("visibilityHasExactlyOneCaseWhoseRawValueIsStable")
    func visibilityHasExactlyOneCaseWhoseRawValueIsStable() {
        #expect(MomentumVisibility.allCases.count == 1)
        #expect(MomentumVisibility.privateToDevice.rawValue == "private")
    }

    // MARK: - ComebackWindow.isOpen(now:)

    @Test("ComebackWindow.isOpen is true when unclaimed and now is before closesAt")
    func comebackWindowIsOpenWhenUnclaimedAndBeforeClose() {
        let calendar = Self.utcCalendar()
        let opensAt = Self.date(calendar, y: 2026, m: 1, d: 12)
        let closesAt = Self.date(calendar, y: 2026, m: 1, d: 15)
        let window = ComebackWindow(
            id: UUID(), missedWeekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            opensAt: opensAt, closesAt: closesAt, claimedAt: nil, claimingSessionID: nil,
            streakBeforeMiss: 4
        )
        let now = Self.date(calendar, y: 2026, m: 1, d: 13)
        #expect(window.isOpen(now: now))
    }

    @Test("ComebackWindow.isOpen is false once claimed")
    func comebackWindowIsNotOpenOnceClaimed() {
        let calendar = Self.utcCalendar()
        let opensAt = Self.date(calendar, y: 2026, m: 1, d: 12)
        let closesAt = Self.date(calendar, y: 2026, m: 1, d: 15)
        let window = ComebackWindow(
            id: UUID(), missedWeekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            opensAt: opensAt, closesAt: closesAt,
            claimedAt: Self.date(calendar, y: 2026, m: 1, d: 13), claimingSessionID: UUID(),
            streakBeforeMiss: 4
        )
        let now = Self.date(calendar, y: 2026, m: 1, d: 13)
        #expect(window.isOpen(now: now) == false)
    }

    @Test("ComebackWindow.isOpen is false once now reaches closesAt")
    func comebackWindowIsNotOpenAtOrAfterClose() {
        let calendar = Self.utcCalendar()
        let opensAt = Self.date(calendar, y: 2026, m: 1, d: 12)
        let closesAt = Self.date(calendar, y: 2026, m: 1, d: 15)
        let window = ComebackWindow(
            id: UUID(), missedWeekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            opensAt: opensAt, closesAt: closesAt, claimedAt: nil, claimingSessionID: nil,
            streakBeforeMiss: 4
        )
        #expect(window.isOpen(now: closesAt) == false)
    }

    // MARK: - ComebackWindow.covers(_:)

    @Test("ComebackWindow.covers is true for an instant at opensAt, true just before closesAt, false at closesAt, false before opensAt")
    func comebackWindowCoversIsHalfOpen() {
        let calendar = Self.utcCalendar()
        let opensAt = Self.date(calendar, y: 2026, m: 1, d: 12)
        let closesAt = Self.date(calendar, y: 2026, m: 1, d: 15)
        let window = ComebackWindow(
            id: UUID(), missedWeekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            opensAt: opensAt, closesAt: closesAt, claimedAt: nil, claimingSessionID: nil,
            streakBeforeMiss: 4
        )

        #expect(window.covers(opensAt))
        #expect(window.covers(closesAt.addingTimeInterval(-1)))
        #expect(window.covers(closesAt) == false)
        #expect(window.covers(opensAt.addingTimeInterval(-1)) == false)
    }

    // MARK: - RecoveryWeekPeriod.covers(weekStart:)

    @Test("RecoveryWeekPeriod.covers is true only for its own exact week start")
    func recoveryWeekPeriodCoversOnlyItsOwnWeekStart() {
        let calendar = Self.utcCalendar()
        let flaggedWeek = Self.date(calendar, y: 2026, m: 1, d: 5)
        let otherWeek = Self.date(calendar, y: 2026, m: 1, d: 12)
        let period = RecoveryWeekPeriod(
            id: UUID(), weekStart: flaggedWeek, flaggedAt: Self.date(calendar, y: 2026, m: 1, d: 6)
        )

        #expect(period.covers(weekStart: flaggedWeek))
        #expect(period.covers(weekStart: otherWeek) == false)
    }

    // MARK: - InjuryFreezePeriod.overlaps(weekStart:weekEnd:)

    @Test("InjuryFreezePeriod with a nil end overlaps every week whose end is after its start")
    func injuryFreezeWithNilEndOverlapsEveryFollowingWeek() {
        let calendar = Self.utcCalendar()
        let freeze = InjuryFreezePeriod(
            id: UUID(), startedAt: Self.date(calendar, y: 2026, m: 1, d: 5), endedAt: nil
        )
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 12)
        let weekEnd = Self.date(calendar, y: 2026, m: 1, d: 19)

        #expect(freeze.overlaps(weekStart: weekStart, weekEnd: weekEnd))
    }

    @Test("InjuryFreezePeriod with a nil end does not overlap a week that ended before it started")
    func injuryFreezeWithNilEndDoesNotOverlapAPriorWeek() {
        let calendar = Self.utcCalendar()
        let freeze = InjuryFreezePeriod(
            id: UUID(), startedAt: Self.date(calendar, y: 2026, m: 1, d: 12), endedAt: nil
        )
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 5)
        let weekEnd = Self.date(calendar, y: 2026, m: 1, d: 12)

        #expect(freeze.overlaps(weekStart: weekStart, weekEnd: weekEnd) == false)
    }

    @Test("InjuryFreezePeriod with a non-nil end overlaps only weeks intersecting [startedAt, endedAt)")
    func injuryFreezeWithEndOverlapsOnlyIntersectingWeeks() {
        let calendar = Self.utcCalendar()
        let freeze = InjuryFreezePeriod(
            id: UUID(),
            startedAt: Self.date(calendar, y: 2026, m: 1, d: 5),
            endedAt: Self.date(calendar, y: 2026, m: 1, d: 19)
        )

        // A week fully inside the freeze.
        #expect(freeze.overlaps(
            weekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            weekEnd: Self.date(calendar, y: 2026, m: 1, d: 12)
        ))
        // A week starting exactly at endedAt — not overlapping (half-open).
        #expect(freeze.overlaps(
            weekStart: Self.date(calendar, y: 2026, m: 1, d: 19),
            weekEnd: Self.date(calendar, y: 2026, m: 1, d: 26)
        ) == false)
        // A week entirely before the freeze started.
        #expect(freeze.overlaps(
            weekStart: Self.date(calendar, y: 2025, m: 12, d: 29),
            weekEnd: Self.date(calendar, y: 2026, m: 1, d: 5)
        ) == false)
    }

    // MARK: - MomentumLedger.empty

    @Test("MomentumLedger.empty has streak 0, shield count 0, zero milestones, zero comeback windows, a nil last-reconciled anchor, the default target, and private-to-device visibility")
    func momentumLedgerEmptyHasExpectedDefaults() {
        let empty = MomentumLedger.empty
        #expect(empty.currentStreak == 0)
        #expect(empty.shieldCount == 0)
        #expect(empty.milestones.isEmpty)
        #expect(empty.comebackWindows.isEmpty)
        #expect(empty.lastReconciledWeekStart == nil)
        #expect(empty.weeklyTarget == MomentumTarget.defaultTarget)
        #expect(empty.visibility == .privateToDevice)
    }

    // MARK: - MomentumLedger Equatable

    @Test("MomentumLedger is Equatable: two ledgers with identical field values compare equal")
    func momentumLedgerEquatableComparesByValue() {
        let calendar = Self.utcCalendar()
        let anchor = Self.date(calendar, y: 2026, m: 1, d: 5)
        let award = MilestoneAward(id: UUID(), weekCount: 4, awardedAt: anchor)

        let ledgerA = MomentumLedger(
            currentStreak: 4, streakLabelKind: .fresh, shieldCount: 1, weeksTowardNextShield: 2,
            lastReconciledWeekStart: anchor, weeklyTarget: 3, visibility: .privateToDevice,
            milestones: [award], comebackWindows: []
        )
        let ledgerB = MomentumLedger(
            currentStreak: 4, streakLabelKind: .fresh, shieldCount: 1, weeksTowardNextShield: 2,
            lastReconciledWeekStart: anchor, weeklyTarget: 3, visibility: .privateToDevice,
            milestones: [award], comebackWindows: []
        )

        #expect(ledgerA == ledgerB)
    }

    // MARK: - MomentumMilestone.tiers

    @Test("MomentumMilestone.tiers is exactly [4, 12, 26, 52] in ascending order")
    func momentumMilestoneTiersAreCorrect() {
        #expect(MomentumMilestone.tiers == [4, 12, 26, 52])
    }

    // MARK: - MomentumGuardrails structural independence (D-03)

    @Test("MomentumGuardrails exposes recovery weeks, injury freezes and streak-loss-protection as three separate members")
    func momentumGuardrailsExposesThreeIndependentMembers() {
        let calendar = Self.utcCalendar()
        let recoveryWeek = RecoveryWeekPeriod(
            id: UUID(), weekStart: Self.date(calendar, y: 2026, m: 1, d: 5),
            flaggedAt: Self.date(calendar, y: 2026, m: 1, d: 6)
        )
        let injuryFreeze = InjuryFreezePeriod(
            id: UUID(), startedAt: Self.date(calendar, y: 2026, m: 1, d: 5), endedAt: nil
        )
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [recoveryWeek], injuryFreezes: [injuryFreeze], streakLossProtected: true
        )

        #expect(guardrails.recoveryWeeks == [recoveryWeek])
        #expect(guardrails.injuryFreezes == [injuryFreeze])
        #expect(guardrails.streakLossProtected)
    }

    // MARK: - MomentumLedger constants

    @Test("MomentumLedger.maxShields is 3 and weeksPerShield is 4")
    func momentumLedgerConstantsAreCorrect() {
        #expect(MomentumLedger.maxShields == 3)
        #expect(MomentumLedger.weeksPerShield == 4)
    }

    // MARK: - StreakLabelKind

    @Test("StreakLabelKind has fresh and rebuilt cases")
    func streakLabelKindHasFreshAndRebuiltCases() {
        #expect(StreakLabelKind.fresh.rawValue == "fresh")
        #expect(StreakLabelKind.rebuilt.rawValue == "rebuilt")
    }
}
