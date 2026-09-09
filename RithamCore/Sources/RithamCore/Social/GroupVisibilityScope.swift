import Foundation

/// HOUSEHOLD-02/GROUPEVENTS-01: the visibility ladder governing who can see a friend-circle
/// completion. `docs/group-events.md` Section 1 describes a three-rung ladder (Only Me ->
/// Household -> this specific group), but HOUSEHOLD-01 (household grouping itself) is a separate,
/// still-Pending Phase 4 requirement -- there is no household tier yet to point a rung at. This
/// phase therefore ships **two reachable rungs** (Only Me -> this specific group) and reserves
/// the household rung's slot, exactly as `MomentumVisibility` did for the identical problem in
/// Phase 3 (`RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift`): ship what's real,
/// reserve the rest in prose, add the case later with no data migration.
///
/// case household = "household" -- reserved for HOUSEHOLD-01; not yet implemented. Do not decode
/// or persist this raw value anywhere until the case above exists. `GroupVisibilityScope(rawValue:
/// "household")` returns `nil` today by construction -- there is no case for it to resolve to, so
/// no persisted or network value can ever select a rung this phase does not implement.
public enum GroupVisibilityScope: String, CaseIterable, Sendable, Equatable, Codable {
    case onlyMe = "onlyMe"
    case group = "group"
}
