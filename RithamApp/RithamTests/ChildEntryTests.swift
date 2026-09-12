import Foundation
import SwiftData
import Testing
@testable import Ritham

// Nested under `MomentumContainerTouchingSuites` (`MomentumSuiteSerialization.swift`'s own doc
// comment: "every new container-creating suite this phase adds nests under this parent") so this
// suite's in-memory `ModelContainer` construction is ordered relative to every other
// container-touching suite during a full-target run, rather than risking the pre-existing
// cross-suite `ModelContainer` concurrency flake `STATE.md` records.
//
// Deviation from 04.2-VALIDATION.md's row TBD-04, which named
// `-only-testing:RithamTests/HealthDataStoreTests`: these tests live in their own file instead,
// because `HealthDataStoreTests.makeStore()` builds a hand-picked four-model schema that omits
// `ChildEntryRecord` entirely, and because that suite is one of the pre-existing unserialized
// container-creating suites `MomentumSuiteSerialization.swift`'s header deliberately leaves
// untouched. Extending it would either break its schema helper for every other test in it or add
// a fourth unserialized container creator.
extension MomentumContainerTouchingSuites {

@MainActor
@Suite("ChildEntryTests", .serialized)
struct ChildEntryTests {

    /// Builds an in-memory container over the full `RithamModelContainer` model list -- the
    /// production schema, not a hand-picked subset -- so every test below fails at first fetch if
    /// `ChildEntryRecord.self` is missing from the models array. No separate registration grep is
    /// needed because of this.
    private func makeStore() throws -> (store: HealthDataStore, container: ModelContainer) {
        let container = try RithamModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        return (HealthDataStore(context: context), container)
    }

    /// A second `HealthDataStore` over the *same* in-memory container but a fresh `ModelContext`
    /// -- proves a value round-trips through actual persistence rather than merely surviving in
    /// the first context's live object graph.
    private func reopenStore(_ container: ModelContainer) -> HealthDataStore {
        HealthDataStore(context: ModelContext(container))
    }

    // MARK: - Empty store

    @Test("an empty store loads zero child entries")
    func emptyStoreLoadsZeroEntries() throws {
        let (store, _) = try makeStore()
        #expect(try store.loadChildEntries().isEmpty)
    }

    // MARK: - Add, reopen, creation order

    @Test("adding two entries and reopening loads both, oldest first, with distinct identifiers")
    func addingTwoEntriesRoundTripsInCreationOrder() throws {
        let (store, container) = try makeStore()
        let firstID = try store.addChildEntry(nickname: "Robin")
        let secondID = try store.addChildEntry(nickname: "Sam")

        #expect(firstID != secondID)

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.count == 2)
        #expect(loaded[0].id == firstID)
        #expect(loaded[1].id == secondID)
    }

    // MARK: - Per-entry rename isolation (the core KIDCONTENT-02 gate)

    @Test("renaming one entry leaves its siblings untouched -- the core KIDCONTENT-02 gate")
    func renameTouchesOnlyTheTargetedEntry() throws {
        let (store, container) = try makeStore()
        let firstID = try store.addChildEntry(nickname: "Robin")
        let secondID = try store.addChildEntry(nickname: "Sam")
        let thirdID = try store.addChildEntry(nickname: "Alex")

        try store.renameChildEntry(id: secondID, to: "Sammy")

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.count == 3)
        #expect(loaded.first { $0.id == firstID }?.nickname == "Robin")
        #expect(loaded.first { $0.id == secondID }?.nickname == "Sammy")
        #expect(loaded.first { $0.id == thirdID }?.nickname == "Alex")
    }

    // MARK: - Per-entry delete isolation

    @Test("deleting one entry leaves exactly its two siblings")
    func deleteTouchesOnlyTheTargetedEntry() throws {
        let (store, container) = try makeStore()
        let firstID = try store.addChildEntry(nickname: "Robin")
        let secondID = try store.addChildEntry(nickname: "Sam")
        let thirdID = try store.addChildEntry(nickname: "Alex")

        try store.deleteChildEntry(id: secondID)

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.count == 2)
        #expect(Set(loaded.map(\.id)) == Set([firstID, thirdID]))
    }

    // MARK: - Not-found errors

    @Test("renameChildEntry throws childEntryNotFound for an identifier that was never stored")
    func renameThrowsNotFoundForUnknownIdentifier() throws {
        let (store, _) = try makeStore()
        #expect(throws: HealthDataStoreError.childEntryNotFound) {
            try store.renameChildEntry(id: UUID(), to: "Anyone")
        }
    }

    @Test("deleteChildEntry throws childEntryNotFound for an identifier that was never stored")
    func deleteThrowsNotFoundForUnknownIdentifier() throws {
        let (store, _) = try makeStore()
        #expect(throws: HealthDataStoreError.childEntryNotFound) {
            try store.deleteChildEntry(id: UUID())
        }
    }

    // MARK: - Nickname normalization

    @Test("an entry added with a whitespace-only nickname reads back with a nil nickname")
    func whitespaceOnlyNicknameNormalizesToNil() throws {
        let (store, container) = try makeStore()
        let id = try store.addChildEntry(nickname: "   \n  ")

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.first { $0.id == id }?.nickname == nil)
    }

    @Test("an entry renamed to a space-padded nickname reads back trimmed")
    func renamedNicknamePaddedWithSpacesReadsBackTrimmed() throws {
        let (store, container) = try makeStore()
        let id = try store.addChildEntry(nickname: "Robin")
        try store.renameChildEntry(id: id, to: "  Sammy  ")

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.first { $0.id == id }?.nickname == "Sammy")
    }

    @Test("an entry renamed to nil reads back nil")
    func renamedToNilReadsBackNil() throws {
        let (store, container) = try makeStore()
        let id = try store.addChildEntry(nickname: "Robin")
        try store.renameChildEntry(id: id, to: nil)

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.first { $0.id == id }?.nickname == nil)
    }

    // MARK: - Ordinal renumbering, pinned as a decision

    @Test("deleting the first of three entries renumbers the remaining two into positions 0 and 1")
    func deletingFirstEntryRenumbersRemainingEntries() throws {
        let (store, container) = try makeStore()
        let firstID = try store.addChildEntry(nickname: "Robin")
        let secondID = try store.addChildEntry(nickname: "Sam")
        let thirdID = try store.addChildEntry(nickname: "Alex")

        try store.deleteChildEntry(id: firstID)

        let reopened = reopenStore(container)
        let loaded = try reopened.loadChildEntries()
        #expect(loaded.count == 2)
        // Asserting the identifiers, not merely the positions, is what makes this test
        // discriminate -- any two-element array trivially occupies positions 0 and 1. What this
        // proves is that the entry the view previously labelled "Child 2" now occupies the first
        // position and will therefore relabel to "Child 1"; plan 04.2-04's own label-level test
        // pins the visible half of this same behaviour.
        //
        // This is the chosen behaviour: ordinal labels are always recomputed from current
        // creation-order position, never a stored, never-reused ordinal. A stored ordinal was
        // rejected because it would be a second stored fact about a specific child -- exactly
        // what D-06/D-07 forbid.
        #expect(loaded[0].id == secondID)
        #expect(loaded[1].id == thirdID)
    }

    // MARK: - Record shape

    @Test("ChildEntryRecord declares no age, body, growth, or activity-history field")
    func recordDeclaresNoForbiddenField() {
        let record = ChildEntryRecord(nickname: "Robin")
        let labels = Mirror(reflecting: record).children.compactMap(\.label)

        // Positive control (`PrivacyZoneTests.recordDeclaresNoForeignIdentifierField`'s own
        // precedent): confirm Mirror actually sees this record's own stored properties before
        // trusting the negative assertion below.
        let sawKnownStoredProperty = labels.contains { $0.lowercased().contains("nickname") }
        #expect(sawKnownStoredProperty, "Mirror did not see ChildEntryRecord's own stored properties -- this test's negative assertion below cannot be trusted until it does")

        // "name" is deliberately absent from this list -- it is a substring of the legitimately
        // present "nickname". "age" is included precisely because an age field is the single
        // most likely future addition D-06 and D-07 rule out.
        let forbiddenSubstrings = [
            "age", "weight", "height", "growth", "birth", "bmi", "session", "activity", "photo", "avatar",
        ]
        let sawForbiddenField = labels.contains { label in
            forbiddenSubstrings.contains { label.lowercased().contains($0) }
        }
        #expect(!sawForbiddenField, "ChildEntryRecord must carry no age, body, growth, or activity-history field")
    }
}

}
