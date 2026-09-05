import Foundation

// STRENGTH-05's retroactive editing (merge two sessions into one; split one session into two)
// only works because `LiftSet.id` and `LiftSet.supersetGroupID` are independent of the session
// that currently holds them (see `LiftSession.swift`'s header comment and 02-RESEARCH.md's
// Anti-Patterns entry on value-typed sets with no independent identity). Both functions below
// preserve that invariant by construction: they reparent existing `LiftSet` values wholesale —
// copying `id` and `supersetGroupID` through unchanged — rather than rebuilding sets from their
// field values, so a retroactive edit can never silently lose or silently rewrite logged work.

/// Retroactive session-merge and session-split operations. Both are pure functions: a revision
/// returns new session value(s) rather than mutating either input.
public enum SessionRevision {

    /// Merges `first` and `second` into one session containing the union of both inputs' sets.
    ///
    /// Returns `nil` when the two sessions share an `id` — merging a session with itself would
    /// otherwise silently duplicate every one of its sets.
    ///
    /// The merged session keeps the earlier `startedAt` and the later `endedAt` of the two
    /// inputs (falling back to whichever side has a non-nil `endedAt` if only one does, and to
    /// `nil` if neither does). Its `sets` are the union of both inputs' sets sorted by
    /// `completedAt`, with `orderIndex` renumbered contiguously from zero. Every set's `id` and
    /// `supersetGroupID` pass through untouched.
    public static func merge(_ first: LiftSession, _ second: LiftSession) -> LiftSession? {
        guard first.id != second.id else { return nil }

        let startedAt = min(first.startedAt, second.startedAt)
        let endedAt: Date?
        switch (first.endedAt, second.endedAt) {
        case let (a?, b?):
            endedAt = max(a, b)
        case let (a?, nil):
            endedAt = a
        case let (nil, b?):
            endedAt = b
        case (nil, nil):
            endedAt = nil
        }

        let mergedSets = renumbered((first.sets + second.sets).sorted { $0.completedAt < $1.completedAt })

        return LiftSession(
            startedAt: startedAt,
            endedAt: endedAt,
            sets: mergedSets,
            notes: first.notes ?? second.notes
        )
    }

    /// Splits `session` at `index` (a position within `session.sets`) into two sessions whose
    /// sets partition the original exactly: no set lost, none duplicated, every `id` preserved.
    ///
    /// Returns `nil` for an index of zero, an index at or beyond the set count, or an empty
    /// session — any of these would otherwise produce a degenerate, empty half.
    ///
    /// The first result keeps the original session's `id` and `startedAt`, with `endedAt` set to
    /// its last set's `completedAt` (when that half's work actually ended). The second result
    /// gets a fresh session `id`, starts at its first set's `completedAt`, and keeps the
    /// original's `endedAt` (it is the tail end of the original timeline). `orderIndex` is
    /// renumbered contiguously within each half; every set's `id` and `supersetGroupID` pass
    /// through untouched.
    public static func split(_ session: LiftSession, atSetIndex index: Int) -> (LiftSession, LiftSession)? {
        let sets = session.sets
        guard !sets.isEmpty, index > 0, index < sets.count else { return nil }

        let firstSets = renumbered(Array(sets[..<index]))
        let secondSets = renumbered(Array(sets[index...]))

        let firstSession = LiftSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: firstSets.last?.completedAt,
            sets: firstSets,
            notes: session.notes
        )

        let secondSession = LiftSession(
            startedAt: secondSets[0].completedAt,
            endedAt: session.endedAt,
            sets: secondSets
        )

        return (firstSession, secondSession)
    }

    /// Reassigns `orderIndex` contiguously from zero, preserving every other field (including
    /// `id` and `supersetGroupID`) and the input's relative ordering.
    private static func renumbered(_ sets: [LiftSet]) -> [LiftSet] {
        sets.enumerated().map { index, set in
            var updated = set
            updated.orderIndex = index
            return updated
        }
    }
}
