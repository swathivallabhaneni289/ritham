import Foundation

// `SupersetGroupID` is defined here, ahead of `SupersetGrouping`'s join/ungroup/groups
// operations (added by a later plan task), because `LiftSession.swift`'s `LiftSet.supersetGroupID`
// field needs this identity type to compile. Both types genuinely belong in this file — see
// 02-RESEARCH.md Pattern 5 ("Superset as a grouping key on `LiftSet`, not a separate session
// type") for the full rationale, applied when `SupersetGrouping` is added alongside this type.

/// Stable identity for a group of `LiftSet`s joined into one superset. A `nil` group ID on a
/// `LiftSet` means "not part of a superset" — the common case.
public struct SupersetGroupID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
