import Foundation

// HEALTH-02's twelve-month condition-tag validity rule (docs/health-screening.md §1.6), as a
// pure function of dates so it is testable before Xcode exists on this machine. The SwiftData
// model (plan 01-11) calls into these functions rather than reimplementing the rule.

/// Whether a condition tag is inside its twelve-month validity window.
///
/// There is deliberately no `expired` case that drops the restriction. D-08 requires that
/// while a tag is overdue but not yet re-screened, the app keeps applying the existing
/// restriction rather than reverting to generic guidance — over-restrict briefly, never
/// silently under-restrict. A future reader will otherwise be tempted to add the missing
/// case; don't.
public enum TagValidity: Sendable, Equatable, CaseIterable {
    case active
    /// The twelve-month window has elapsed (or was overdue when last measured), but the
    /// tag's restriction is still applied — see the type-level doc comment above.
    case expiredStillApplied
}

/// Pure date-arithmetic implementation of §1.6's validity window, re-screen prompt, and
/// edit-resets-the-window rule.
public struct ConditionTagValidity: Sendable {

    /// §1.6's validity window, in months, added via `Calendar` date arithmetic (not a
    /// hardcoded seconds count) so leap years and DST do not shift the boundary.
    ///
    /// Deviation from the plan's literal `public static let validityWindow: TimeInterval`:
    /// a twelve-month window cannot be represented as a fixed `TimeInterval` (a fixed
    /// seconds count) without reintroducing the leap-year/DST drift this rule exists to
    /// avoid — the plan's own preferred alternative, `expiry(from:calendar:)` built on
    /// `calendar.date(byAdding:)`, is exactly what's implemented below, and this constant is
    /// what it's derived from. See 01-03-SUMMARY.md for the full rationale (Rule 1).
    private static let validityWindowMonths = 12

    /// `recordedAt` plus the twelve-month validity window, per `Calendar`'s own month
    /// arithmetic.
    public static func expiry(from recordedAt: Date, calendar: Calendar) -> Date {
        // `calendar.date(byAdding:)` only returns nil on an out-of-range overflow, which is
        // not reachable for realistic recorded dates. If it ever were, falling back to
        // `recordedAt` itself (rather than, say, `Date.distantFuture`) keeps the fail-safe
        // direction consistent with D-08: an already-elapsed expiry means `isReScreenDue`
        // still fires, never that the window silently extends forever.
        calendar.date(byAdding: .month, value: validityWindowMonths, to: recordedAt) ?? recordedAt
    }

    /// Whether a tag recorded at `recordedAt` is still active, or overdue, as of `now`.
    /// `.active` while `now` is strictly before the computed expiry; `.expiredStillApplied`
    /// at or after it.
    public static func validity(recordedAt: Date, now: Date, calendar: Calendar) -> TagValidity {
        validity(recordedAt: recordedAt, editedAt: nil, now: now, calendar: calendar)
    }

    /// §1.6: a tag stays valid for twelve months *or until the user edits an answer,
    /// whichever comes first*, and D-09 scopes an edit to its own section. When `editedAt`
    /// is non-nil, the window is measured from `editedAt` instead of `recordedAt`.
    public static func validity(
        recordedAt: Date,
        editedAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> TagValidity {
        let effectiveRecordedAt = editedAt ?? recordedAt
        let expiryDate = expiry(from: effectiveRecordedAt, calendar: calendar)
        return now < expiryDate ? .active : .expiredStillApplied
    }

    /// True exactly when `validity` is `.expiredStillApplied`. D-07 makes this a
    /// non-blocking banner signal only — no caller may use this to gate access; it says
    /// "prompt", never "block".
    public static func isReScreenDue(recordedAt: Date, now: Date, calendar: Calendar) -> Bool {
        validity(recordedAt: recordedAt, now: now, calendar: calendar) == .expiredStillApplied
    }
}

/// §1.6: the "I've talked to a professional" toggle is not a permanent unlock — it re-prompts
/// at each re-screen point. Modeled as a dated grant, never a standing boolean.
public struct ProfessionalClearance: Sendable, Equatable {
    public var grantedAt: Date

    public init(grantedAt: Date) {
        self.grantedAt = grantedAt
    }

    /// Whether this grant is due to re-prompt "has anything changed since you last checked
    /// in?", using the same twelve-month window as a condition tag.
    public func needsReConfirmation(now: Date, calendar: Calendar) -> Bool {
        ConditionTagValidity.isReScreenDue(recordedAt: grantedAt, now: now, calendar: calendar)
    }
}
