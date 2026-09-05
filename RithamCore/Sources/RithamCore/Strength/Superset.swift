import Foundation

// Per 02-RESEARCH.md Pattern 5 ("Superset as a grouping key on `LiftSet`, not a separate session
// type"): a superset is a grouping attribute on existing `LiftSet` identity, never a separate
// top-level entity that owns its own sets. This resolves Pattern 5's stated open design point
// (set-level vs. exercise-level grouping) once, here: grouping is applied at
// exercise-within-session granularity — joining an exercise into a superset assigns the group ID
// to all of that exercise's working sets in that session — because STRENGTH-03's stated
// interaction is tapping "add to superset" on two consecutive *exercises*, not on two individual
// sets. The storage remains a per-`LiftSet` field (`supersetGroupID`), so nothing about merge or
// split (`SessionRevision`) needs to change to accommodate this.

/// Stable identity for a group of `LiftSet`s joined into one superset. A `nil` group ID on a
/// `LiftSet` means "not part of a superset" — the common case.
public struct SupersetGroupID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A resolved superset: its group ID and the ordered `LiftSet.id` values belonging to it.
public struct SupersetGroup: Sendable, Equatable {
    public let id: SupersetGroupID
    public let setIDs: [UUID]

    public init(id: SupersetGroupID, setIDs: [UUID]) {
        self.id = id
        self.setIDs = setIDs
    }
}

/// Pure functions over `LiftSession.sets[].supersetGroupID`. Every function returns a new
/// session value — no mutation of a shared reference, matching how every other RithamCore
/// domain type behaves.
public enum SupersetGrouping {

    /// Assigns `groupID` to every **working** set (warm-ups excluded) whose
    /// `exerciseIdentifier` is in `exerciseIdentifiers`. If any of those sets already belonged
    /// to a different group, this moves them into `groupID` rather than producing a second
    /// membership — a set's `supersetGroupID` is a single field, so assignment is inherently
    /// exclusive. Never recreates a set: `id` is unchanged on every affected set.
    public static func join(
        exerciseIdentifiers: [String],
        in session: LiftSession,
        groupID: SupersetGroupID
    ) -> LiftSession {
        var result = session
        result.sets = session.sets.map { set in
            guard !set.isWarmUp, exerciseIdentifiers.contains(set.exerciseIdentifier) else {
                return set
            }
            var updated = set
            updated.supersetGroupID = groupID
            return updated
        }
        return result
    }

    /// Clears `supersetGroupID` on exactly the sets currently belonging to `groupID`, leaving
    /// every other set's group membership untouched. Never recreates a set.
    public static func ungroup(_ groupID: SupersetGroupID, in session: LiftSession) -> LiftSession {
        var result = session
        result.sets = session.sets.map { set in
            guard set.supersetGroupID == groupID else { return set }
            var updated = set
            updated.supersetGroupID = nil
            return updated
        }
        return result
    }

    /// One `SupersetGroup` per distinct non-nil `supersetGroupID` present in `session`, in the
    /// order each group first appears among `session.sets`. Empty for a session with no
    /// supersets.
    public static func groups(in session: LiftSession) -> [SupersetGroup] {
        var order: [SupersetGroupID] = []
        var setIDsByGroup: [SupersetGroupID: [UUID]] = [:]

        for set in session.sets {
            guard let groupID = set.supersetGroupID else { continue }
            if setIDsByGroup[groupID] == nil {
                order.append(groupID)
                setIDsByGroup[groupID] = []
            }
            setIDsByGroup[groupID]?.append(set.id)
        }

        return order.map { SupersetGroup(id: $0, setIDs: setIDsByGroup[$0] ?? []) }
    }
}
