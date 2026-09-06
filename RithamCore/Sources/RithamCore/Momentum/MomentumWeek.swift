import Foundation

// MOMENTUM-03's Monday-3am-local week boundary (docs/roadmap.md §4: "to absorb travel,
// time-zone shifts, and late/irregular schedules without a false break"), as a pure function of
// dates so it is independently unit-testable across DST fixtures without a running app or
// simulator. Follows `ConditionTagValidity`'s injected-Calendar, fail-safe-never-crash precedent
// (RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift) — the pattern to copy, not
// the exact formula, since this boundary is weekday+hour based rather than month-based.
//
// Plan 03-03's reconciliation fold is keyed on `weekStart`'s return value being a *stable
// per-week anchor* — every fallback in this file is therefore derived from the candidate day,
// never from the call instant, so two calls at different instants on the same day always agree.

/// The Monday-3am-local week boundary Momentum's weekly consistency mechanic resets on.
///
/// A session belongs to the Momentum week containing its `startedAt` timestamp, matching the
/// existing `HealthDataStore.loadCardioSessions(in:)`/`loadLiftSessions(in:)` predicates, which
/// already filter on `startedAt`. A session started 02:50 Monday and ended 03:30 Monday belongs
/// to the *previous* week — this is a locked decision (03-RESEARCH.md Week-Boundary Arithmetic),
/// not an implicit side effect of the arithmetic below.
public enum MomentumWeek {

    /// Gregorian weekday numbering is fixed (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    /// regardless of locale. This value is deliberately NOT derived from `calendar.firstWeekday`
    /// (a user's regional first-weekday preference) — Momentum's week starts on Monday for every
    /// user, unconditionally (03-RESEARCH.md Anti-Patterns: "Reading `calendar.firstWeekday` at
    /// all for this feature").
    public static let anchorWeekday: Int = 2

    /// The local hour, on the anchor weekday, the Momentum week resets at.
    public static let anchorHour: Int = 3

    /// Returns the start instant of the Momentum week containing `now`: the most recent Monday
    /// at 03:00 local time at or before `now`.
    ///
    /// CRITICAL correction to 03-RESEARCH.md's sketch (locked deviation, stated here per the
    /// plan): the research sketch's failure fallback returns `now` itself. This function does
    /// NOT do that — doing so would make the result depend on the call instant rather than on
    /// the week, silently breaking plan 03-03's reconciliation idempotence on a DST transition
    /// day. Every fallback here is derived from the *candidate day* via `boundaryInstant`, never
    /// from `now`.
    ///
    /// Takes `calendar` as a required, non-defaulted parameter, and never reads the process-wide
    /// current calendar or constructs a current-instant `Date` internally — the caller (in
    /// `RithamApp`) supplies both.
    public static func weekStart(containing now: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: now)
        let daysSinceMonday = (weekday - anchorWeekday + 7) % 7

        guard let candidateDay = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now) else {
            // Out-of-range overflow, not reachable for realistic dates. Fail-safe: derive from
            // `now`'s own day rather than crashing, matching `ConditionTagValidity`'s discipline.
            return boundaryInstant(forCandidateDay: now, calendar: calendar)
        }

        let candidateBoundary = boundaryInstant(forCandidateDay: candidateDay, calendar: calendar)

        if candidateBoundary > now {
            // `now` is Monday but before 3am local -- still inside the *previous* Momentum week.
            guard let previousCandidateDay = calendar.date(byAdding: .day, value: -7, to: candidateDay) else {
                return calendar.date(byAdding: .day, value: -7, to: candidateBoundary) ?? candidateBoundary
            }
            return boundaryInstant(forCandidateDay: previousCandidateDay, calendar: calendar)
        }

        return candidateBoundary
    }

    /// Sets the wall-clock `anchorHour` on `candidateDay`, with a fail-safe fallback that is
    /// always derived from `candidateDay` itself — never from any other instant — so that two
    /// calls with the same `candidateDay` always return the identical `Date`, even on a
    /// synthetic day where the local `anchorHour` cannot be produced (e.g. a DST spring-forward
    /// gap in some non-US regions covering that hour).
    ///
    /// Exposed at `internal` visibility (not `public`) so `MomentumWeekTests` can exercise the
    /// fallback path directly via `@testable import`, without needing to fabricate a calendar
    /// whose every top-level `weekStart` call happens to hit the non-existent-hour case.
    static func boundaryInstant(forCandidateDay candidateDay: Date, calendar: Calendar) -> Date {
        if let boundary = calendar.date(bySettingHour: anchorHour, minute: 0, second: 0, of: candidateDay) {
            return boundary
        }
        let startOfCandidateDay = calendar.startOfDay(for: candidateDay)
        if let fallback = calendar.date(byAdding: .hour, value: anchorHour, to: startOfCandidateDay) {
            return fallback
        }
        return startOfCandidateDay
    }

    /// Returns exactly seven calendar days after `weekStart`, computed via calendar day
    /// arithmetic — never fixed-seconds arithmetic — so a week spanning a DST transition is
    /// correctly 167 or 169 wall hours, never a hardcoded 168.
    public static func weekEnd(startingAt weekStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    /// The half-open range `[weekStart, nextWeekStart)`, represented as a `ClosedRange<Date>`
    /// whose upper bound is one millisecond before `nextWeekStart` (never a whole second, which
    /// would incorrectly exclude a session started in that week's final second).
    public static func weekRange(containing now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = weekStart(containing: now, calendar: calendar)
        let end = weekEnd(startingAt: start, calendar: calendar)
        return start...end.addingTimeInterval(-0.001)
    }

    /// The start of the week immediately following `weekStart` — identical to
    /// `weekEnd(startingAt:calendar:)`, exposed under this name for reconciliation call sites
    /// (plan 03-03) that walk forward week-by-week.
    public static func nextWeekStart(after weekStart: Date, calendar: Calendar) -> Date {
        weekEnd(startingAt: weekStart, calendar: calendar)
    }
}
