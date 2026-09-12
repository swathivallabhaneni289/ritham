import Foundation
import SwiftData

// KIDCONTENT-02's entire persisted fact: a parent has recorded that a preteen exists, nothing
// more (D-07). Mirrors `PrivacyZoneRecord.swift`'s per-entry-UUID identity shape exactly --
// including its plain (non-unique-constrained) `id: UUID` -- because D-07 lets a parent record
// MORE than one child and edit each independently. Identity and no-duplication are enforced by
// `HealthDataStore`'s fetch-by-id accessors (`// MARK: - Child entries`), never by a SwiftData-
// level uniqueness constraint, the same discipline `PrivacyZoneRecord` already establishes.
//
// This record deliberately carries no age, birthdate, weight, height, growth, avatar, photo, or
// session/activity-history field -- and per D-06 no age band either, because this phase's scope
// is exactly one preteen band and any richer shape would become identifying or health-adjacent
// data about a specific child, which is exactly what this phase's COPPA-avoidance reasoning
// forbids.
//
// `nickname` is optional; a `nil` value renders as an ordinal label ("Child 1", "Child 2", ...)
// computed at the view layer from creation order, never stored here as a second source of truth
// for that position.
//
// Per D-09, no per-idea viewed/tried/favourited state is stored anywhere in this phase, so this
// record must never grow a relationship to `KidContentCatalog` content.
//
// Adding any field to this record is a design-decision point that needs the same scrutiny D-07
// already received, not a routine schema addition.
@Model
public final class ChildEntryRecord {
    public var id: UUID
    public var nickname: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), nickname: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.nickname = nickname
        self.createdAt = createdAt
    }
}
