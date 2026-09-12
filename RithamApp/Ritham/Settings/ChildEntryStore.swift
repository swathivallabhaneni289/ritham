import SwiftData
import SwiftUI
import RithamCore

/// Thin, on-device-only facade over `HealthDataStore`'s child-entry accessors
/// (`HealthDataStore.swift`'s `// MARK: - Child entries` section), following `PrivacyZoneStore`'s
/// own "an `@Observable` model wraps the store" shape. `KidIdeasView` reads and mutates child
/// entries only through this type, never through `HealthDataStore` directly -- the same isolation
/// `PrivacyZoneStore` gives `PrivacyZonesView` from its own store accessors.
///
/// This facade exists so `KidIdeasView` never calls `HealthDataStore` directly, matching
/// `PrivacyZoneStore`'s own isolation rationale. Per D-09, it exposes no per-idea state of any
/// kind -- it knows nothing about any browsable content catalog, only about child entries.
///
/// `entries` starts empty and is populated only by an explicit `load()` call (never eagerly in
/// `init`), matching `PrivacyZoneStore.load()`'s own deferred-load shape -- `KidIdeasView` calls
/// this from `.onAppear`, the same trigger `PrivacyZonesView` uses.
@MainActor
@Observable
final class ChildEntryStore {
    private(set) var entries: [ChildEntryRecord] = []

    private let store: HealthDataStore

    init(store: HealthDataStore) {
        self.store = store
    }

    /// Reloads every stored child entry. Failure reads back as an empty list rather than
    /// throwing -- matching `PrivacyZoneStore.load()`'s own `(try? ...) ?? []` discipline -- since
    /// this is a Settings preference list, not a screen any correctness guarantee depends on.
    /// `HealthDataStore.loadChildEntries()` already sorts by creation time ascending, so
    /// `entries`' order is the ordinal order and this facade must not re-sort.
    func load() {
        entries = (try? store.loadChildEntries()) ?? []
    }

    /// Adds a new entry with no nickname and reloads, returning `true` on success. Adding an
    /// entry with no nickname is deliberate: the parent gets a usable ordinal-labelled row
    /// immediately and may optionally rename it, which is what keeps a name from ever being
    /// required (04.2-RESEARCH.md Pitfall 2). Returns `false` on a persistence failure, leaving
    /// `entries` unchanged from the last successful `load()`.
    @discardableResult
    func add() -> Bool {
        do {
            _ = try store.addChildEntry()
            load()
            return true
        } catch {
            return false
        }
    }

    /// Renames a stored entry's own nickname and reloads. A no-op (besides a reload) when `id`
    /// no longer matches any stored entry, mirroring `PrivacyZoneStore.rename(id:to:)`.
    func rename(id: UUID, to nickname: String?) {
        try? store.renameChildEntry(id: id, to: nickname)
        load()
    }

    /// Removes a stored entry and reloads. A no-op (besides a reload) when `id` no longer matches
    /// any stored entry, mirroring `PrivacyZoneStore.remove(id:)`.
    func remove(id: UUID) {
        try? store.deleteChildEntry(id: id)
        load()
    }

    /// The pure label rule and the only place it lives: trims `nickname` of whitespace and
    /// newlines; if the result is non-empty returns it, otherwise returns
    /// `KidContentCopy.Children.ordinalLabel(position)`. Declared `nonisolated static` so a test
    /// can call it without main-actor hops, following the precedent plan 03-06 recorded for pure
    /// helpers on main-actor-isolated types.
    nonisolated static func displayLabel(nickname: String?, position: Int) -> String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? KidContentCopy.Children.ordinalLabel(position) : trimmed
    }

    /// Finds `entry`'s index in `entries` and calls `displayLabel(nickname:position:)` with
    /// `position: index + 1`; when the entry is not in `entries` (a stale reference) falls back
    /// to position `1`.
    ///
    /// The ordinal is computed from the entry's current place in creation order and is never
    /// stored, so removing an earlier entry renumbers the rest -- the behaviour plan 04.2-03
    /// pinned in a test, chosen because a stored ordinal would be a second stored fact about a
    /// specific child.
    func displayLabel(for entry: ChildEntryRecord) -> String {
        let position = (entries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 }) ?? 1
        return Self.displayLabel(nickname: entry.nickname, position: position)
    }
}
