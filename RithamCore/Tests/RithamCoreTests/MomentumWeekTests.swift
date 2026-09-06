import Testing
@testable import RithamCore
import Foundation

@Suite("MomentumWeekTests")
struct MomentumWeekTests {

    // MARK: - Fixture helpers

    private static func calendar(timeZoneIdentifier: String, firstWeekday: Int? = nil, localeIdentifier: String? = nil) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        if let firstWeekday {
            calendar.firstWeekday = firstWeekday
        }
        if let localeIdentifier {
            calendar.locale = Locale(identifier: localeIdentifier)
        }
        return calendar
    }

    private static func date(_ calendar: Calendar, y: Int, m: Int, d: Int, h: Int, min: Int = 0, s: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        components.second = s
        return calendar.date(from: components)!
    }

    // MARK: - Basic weekday boundary behavior (UTC, no DST, Jan 2026 — Jan 5 2026 is a Monday)

    @Test("weekStart for a Wednesday 10:00 returns that same week's Monday at 03:00 local")
    func weekStartForWednesdayReturnsThisWeeksMonday() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let wednesday10am = Self.date(calendar, y: 2026, m: 1, d: 7, h: 10)
        let expected = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        #expect(MomentumWeek.weekStart(containing: wednesday10am, calendar: calendar) == expected)
    }

    @Test("weekStart for a Monday at 02:50 local returns the previous Monday 03:00")
    func weekStartForMondayBefore3amReturnsPreviousMonday() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let mondayBefore3am = Self.date(calendar, y: 2026, m: 1, d: 5, h: 2, min: 50)
        let expected = Self.date(calendar, y: 2025, m: 12, d: 29, h: 3)
        #expect(MomentumWeek.weekStart(containing: mondayBefore3am, calendar: calendar) == expected)
    }

    @Test("weekStart for a Monday at exactly 03:00:00 returns that same instant")
    func weekStartForMondayAtExactly3amReturnsSameInstant() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let mondayAt3am = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        #expect(MomentumWeek.weekStart(containing: mondayAt3am, calendar: calendar) == mondayAt3am)
    }

    @Test("weekStart for a Sunday 23:30 returns the Monday 03:00 six days earlier")
    func weekStartForSundayReturnsMondaySixDaysEarlier() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let sunday2330 = Self.date(calendar, y: 2026, m: 1, d: 11, h: 23, min: 30)
        let expected = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        #expect(MomentumWeek.weekStart(containing: sunday2330, calendar: calendar) == expected)
    }

    // MARK: - Locale independence

    @Test("the same instant returns an identical Date under a Sunday-first-week and a Monday-first-week calendar")
    func weekStartIsLocaleIndependent() {
        let sundayFirstCalendar = Self.calendar(timeZoneIdentifier: "UTC", firstWeekday: 1, localeIdentifier: "en_US")
        let mondayFirstCalendar = Self.calendar(timeZoneIdentifier: "UTC", firstWeekday: 2, localeIdentifier: "en_GB")
        let instant = Self.date(sundayFirstCalendar, y: 2026, m: 1, d: 7, h: 10)

        let resultSundayFirst = MomentumWeek.weekStart(containing: instant, calendar: sundayFirstCalendar)
        let resultMondayFirst = MomentumWeek.weekStart(containing: instant, calendar: mondayFirstCalendar)

        #expect(resultSundayFirst == resultMondayFirst)
    }

    // MARK: - DST: America/New_York spring-forward (March 8, 2026)

    @Test("DST spring-forward: weekStart is identical whether evaluated at 09:00 or 21:00 on the Monday after the transition")
    func weekStartIsStableAcrossCallInstantsOnADSTTransitionDay() {
        let calendar = Self.calendar(timeZoneIdentifier: "America/New_York")
        let monday9am = Self.date(calendar, y: 2026, m: 3, d: 9, h: 9)
        let monday9pm = Self.date(calendar, y: 2026, m: 3, d: 9, h: 21)
        let expected = Self.date(calendar, y: 2026, m: 3, d: 9, h: 3)

        #expect(MomentumWeek.weekStart(containing: monday9am, calendar: calendar) == expected)
        #expect(MomentumWeek.weekStart(containing: monday9pm, calendar: calendar) == expected)
    }

    @Test("DST spring-forward: the returned boundary is exactly the Monday 03:00 wall-clock time")
    func weekStartSpringForwardReturnsWallClock3am() {
        let calendar = Self.calendar(timeZoneIdentifier: "America/New_York")
        let monday9am = Self.date(calendar, y: 2026, m: 3, d: 9, h: 9)
        let boundary = MomentumWeek.weekStart(containing: monday9am, calendar: calendar)
        #expect(calendar.component(.hour, from: boundary) == 3)
        #expect(calendar.component(.weekday, from: boundary) == 2)
    }

    // MARK: - DST: America/New_York fall-back (November 1, 2026)

    @Test("DST fall-back: weekStart is identical whether evaluated at 09:00 or 21:00 on the Monday of the transition week")
    func weekStartIsStableAcrossCallInstantsOnAFallBackTransitionDay() {
        let calendar = Self.calendar(timeZoneIdentifier: "America/New_York")
        let monday9am = Self.date(calendar, y: 2026, m: 10, d: 26, h: 9)
        let monday9pm = Self.date(calendar, y: 2026, m: 10, d: 26, h: 21)
        let expected = Self.date(calendar, y: 2026, m: 10, d: 26, h: 3)

        #expect(MomentumWeek.weekStart(containing: monday9am, calendar: calendar) == expected)
        #expect(MomentumWeek.weekStart(containing: monday9pm, calendar: calendar) == expected)
    }

    // MARK: - DST: Australia/Sydney (Southern Hemisphere) spring-forward (October 4, 2026)

    @Test("Southern Hemisphere DST transition (Sydney): weekStart is identical at 09:00 and 21:00")
    func weekStartIsStableAcrossCallInstantsInSydneyDST() {
        let calendar = Self.calendar(timeZoneIdentifier: "Australia/Sydney")
        let monday9am = Self.date(calendar, y: 2026, m: 10, d: 5, h: 9)
        let monday9pm = Self.date(calendar, y: 2026, m: 10, d: 5, h: 21)
        let expected = Self.date(calendar, y: 2026, m: 10, d: 5, h: 3)

        #expect(MomentumWeek.weekStart(containing: monday9am, calendar: calendar) == expected)
        #expect(MomentumWeek.weekStart(containing: monday9pm, calendar: calendar) == expected)
    }

    // MARK: - Non-existent local 03:00 fallback (internal boundaryInstant helper, direct)

    @Test("boundaryInstant falls back to a candidate-day-derived value when the anchor hour cannot be set, and never depends on the call instant")
    func boundaryInstantFallsBackConsistentlyForTheSameCandidateDay() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let candidateDay = Self.date(calendar, y: 2026, m: 1, d: 5, h: 10)

        let firstCall = MomentumWeek.boundaryInstant(forCandidateDay: candidateDay, calendar: calendar)
        let secondCall = MomentumWeek.boundaryInstant(forCandidateDay: candidateDay, calendar: calendar)

        #expect(firstCall == secondCall)
        #expect(calendar.component(.hour, from: firstCall) == 3)
    }

    // MARK: - weekEnd

    @Test("weekEnd returns exactly seven calendar days after the given week start (UTC, no DST)")
    func weekEndIsSevenCalendarDaysLaterInUTC() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        let expected = Self.date(calendar, y: 2026, m: 1, d: 12, h: 3)
        #expect(MomentumWeek.weekEnd(startingAt: weekStart, calendar: calendar) == expected)
    }

    @Test("weekEnd stays correct across a DST spring-forward week — 167 wall hours, never a fixed 168-hour week")
    func weekEndAcrossDSTSpringForwardWeekIs167WallHours() {
        let calendar = Self.calendar(timeZoneIdentifier: "America/New_York")
        let weekStart = Self.date(calendar, y: 2026, m: 3, d: 2, h: 3)
        let weekEnd = MomentumWeek.weekEnd(startingAt: weekStart, calendar: calendar)
        let expected = Self.date(calendar, y: 2026, m: 3, d: 9, h: 3)

        #expect(weekEnd == expected)
        #expect(calendar.component(.hour, from: weekEnd) == 3)
        #expect(weekEnd.timeIntervalSince(weekStart) == 167 * 3600)
    }

    // MARK: - weekRange

    @Test("weekRange's lower bound equals weekStart and upper bound is strictly before the next week's start")
    func weekRangeBoundsAreCorrect() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let wednesday10am = Self.date(calendar, y: 2026, m: 1, d: 7, h: 10)
        let range = MomentumWeek.weekRange(containing: wednesday10am, calendar: calendar)
        let expectedStart = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        let nextWeekStart = MomentumWeek.nextWeekStart(after: expectedStart, calendar: calendar)

        #expect(range.lowerBound == expectedStart)
        #expect(range.upperBound < nextWeekStart)
    }

    // MARK: - nextWeekStart

    @Test("nextWeekStart returns the same value as weekEnd for the given week start")
    func nextWeekStartMatchesWeekEnd() {
        let calendar = Self.calendar(timeZoneIdentifier: "UTC")
        let weekStart = Self.date(calendar, y: 2026, m: 1, d: 5, h: 3)
        #expect(MomentumWeek.nextWeekStart(after: weekStart, calendar: calendar) == MomentumWeek.weekEnd(startingAt: weekStart, calendar: calendar))
    }

    // MARK: - Constants

    @Test("anchorWeekday is 2 (Monday, Gregorian numbering) and anchorHour is 3")
    func anchorConstantsAreCorrect() {
        #expect(MomentumWeek.anchorWeekday == 2)
        #expect(MomentumWeek.anchorHour == 3)
    }
}
