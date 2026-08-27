import Foundation
import SwiftData
import RithamCore

// One persisted condition tag. Validity and re-screen-due status delegate entirely to
// `ConditionTagValidity` (RithamCore) — this file contains no date arithmetic of its own,
// because that rule is already tested against explicit boundary dates there, and a second
// implementation here would be able to drift from it (T-01-62).
//
// D-08 (01-CONTEXT.md): expiry is a query-time check and never a deletion. While a tag is
// overdue but not yet re-screened, the app keeps applying its restriction rather than reverting
// to generic guidance — over-restrict briefly, never silently under-restrict. There is
// deliberately no mutator here that drops a tag's restriction on expiry; `TagValidity` itself
// (RithamCore) has no case that means "expired and no longer applies," so nothing in this file
// could accidentally add one.
@Model
public final class ConditionTagRecord {
    public var tagRaw: String
    public var recordedAt: Date
    public var editedAt: Date?
    public var professionalClearanceGrantedAt: Date?

    public init(
        tagRaw: String,
        recordedAt: Date,
        editedAt: Date? = nil,
        professionalClearanceGrantedAt: Date? = nil
    ) {
        self.tagRaw = tagRaw
        self.recordedAt = recordedAt
        self.editedAt = editedAt
        self.professionalClearanceGrantedAt = professionalClearanceGrantedAt
    }

    /// `nil` rather than a trap when `tagRaw` no longer matches a known `ConditionTag` case
    /// (T-01-64) — e.g. after a future schema change removes or renames a case.
    public var tag: ConditionTag? {
        ConditionTag(rawValue: tagRaw)
    }

    /// Delegates to `ConditionTagValidity.validity(recordedAt:editedAt:now:calendar:)`. Per
    /// §1.6, the twelve-month window is measured from `editedAt` when present (an edit resets
    /// the window), otherwise from `recordedAt`.
    public func validity(now: Date, calendar: Calendar) -> TagValidity {
        ConditionTagValidity.validity(recordedAt: recordedAt, editedAt: editedAt, now: now, calendar: calendar)
    }

    /// Delegates to `ConditionTagValidity.isReScreenDue`, resolving the same
    /// `editedAt ?? recordedAt` window start `validity(now:calendar:)` above uses, so the two
    /// methods can never disagree about which date governs this record.
    public func isReScreenDue(now: Date, calendar: Calendar) -> Bool {
        ConditionTagValidity.isReScreenDue(recordedAt: editedAt ?? recordedAt, now: now, calendar: calendar)
    }
}
