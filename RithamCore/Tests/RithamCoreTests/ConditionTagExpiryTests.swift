import Foundation
import Testing
@testable import RithamCore

@Suite("ConditionTagExpiryTests")
struct ConditionTagExpiryTests {

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Self.utcCalendar.date(from: components)!
    }

    @Test("a tag recorded today is active")
    func recordedTodayIsActive() {
        let recordedAt = date(2025, 1, 1)
        let result = ConditionTagValidity.validity(recordedAt: recordedAt, now: recordedAt, calendar: Self.utcCalendar)
        #expect(result == .active)
    }

    @Test("one day before the twelve-month mark is active")
    func oneDayBeforeMarkIsActive() {
        let recordedAt = date(2025, 1, 1)
        let now = date(2025, 12, 31)
        let result = ConditionTagValidity.validity(recordedAt: recordedAt, now: now, calendar: Self.utcCalendar)
        #expect(result == .active)
    }

    @Test("exactly at the twelve-month mark is expiredStillApplied")
    func exactlyAtMarkIsExpired() {
        let recordedAt = date(2025, 1, 1)
        let now = date(2026, 1, 1)
        let result = ConditionTagValidity.validity(recordedAt: recordedAt, now: now, calendar: Self.utcCalendar)
        #expect(result == .expiredStillApplied)
    }

    @Test("one day after the twelve-month mark is expiredStillApplied")
    func oneDayAfterMarkIsExpired() {
        let recordedAt = date(2025, 1, 1)
        let now = date(2026, 1, 2)
        let result = ConditionTagValidity.validity(recordedAt: recordedAt, now: now, calendar: Self.utcCalendar)
        #expect(result == .expiredStillApplied)
    }

    @Test("isReScreenDue is false before and true at/after the twelve-month mark")
    func isReScreenDueBoundary() {
        let recordedAt = date(2025, 1, 1)
        #expect(!ConditionTagValidity.isReScreenDue(recordedAt: recordedAt, now: date(2025, 12, 31), calendar: Self.utcCalendar))
        #expect(ConditionTagValidity.isReScreenDue(recordedAt: recordedAt, now: date(2026, 1, 1), calendar: Self.utcCalendar))
        #expect(ConditionTagValidity.isReScreenDue(recordedAt: recordedAt, now: date(2026, 1, 2), calendar: Self.utcCalendar))
    }

    @Test("an edit six months in resets the window so the original twelve-month mark is still active")
    func editResetsTheWindow() {
        let recordedAt = date(2025, 1, 1)
        let editedAt = date(2025, 7, 1)
        let originalTwelveMonthMark = date(2026, 1, 1)
        let result = ConditionTagValidity.validity(
            recordedAt: recordedAt,
            editedAt: editedAt,
            now: originalTwelveMonthMark,
            calendar: Self.utcCalendar
        )
        #expect(result == .active)
    }

    @Test("ProfessionalClearance.needsReConfirmation follows the same boundary")
    func professionalClearanceBoundary() {
        let grantedAt = date(2025, 1, 1)
        let clearance = ProfessionalClearance(grantedAt: grantedAt)
        #expect(!clearance.needsReConfirmation(now: date(2025, 12, 31), calendar: Self.utcCalendar))
        #expect(clearance.needsReConfirmation(now: date(2026, 1, 1), calendar: Self.utcCalendar))
    }

    @Test("TagValidity declares exactly two cases")
    func tagValidityHasExactlyTwoCases() {
        #expect(TagValidity.allCases.count == 2)
    }

    @Test("D-08: validity never yields a value that drops the restriction, across every branch")
    func validityNeverDropsRestriction() {
        let recordedAt = date(2025, 1, 1)
        let samples: [TagValidity] = [
            ConditionTagValidity.validity(recordedAt: recordedAt, now: recordedAt, calendar: Self.utcCalendar),
            ConditionTagValidity.validity(recordedAt: recordedAt, now: date(2025, 12, 31), calendar: Self.utcCalendar),
            ConditionTagValidity.validity(recordedAt: recordedAt, now: date(2026, 1, 1), calendar: Self.utcCalendar),
            ConditionTagValidity.validity(recordedAt: recordedAt, now: date(2026, 1, 2), calendar: Self.utcCalendar),
            ConditionTagValidity.validity(recordedAt: recordedAt, editedAt: date(2025, 7, 1), now: date(2026, 1, 1), calendar: Self.utcCalendar),
        ]
        for sample in samples {
            // Exhaustive switch over TagValidity.allCases-equivalent coverage: both defined
            // cases keep the restriction applied. If a future `expired`-without-restriction
            // case is ever added, this switch fails to compile until it's handled here too.
            switch sample {
            case .active, .expiredStillApplied:
                break
            }
        }
        #expect(samples.count == 5)
    }
}
