import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Nested under `MomentumContainerTouchingSuites` (`MomentumSuiteSerialization.swift`'s own doc
// comment: "every new container-creating suite this phase adds nests under this parent") so this
// suite's in-memory `ModelContainer` construction is ordered relative to every other
// container-touching suite during a full-target run, rather than risking the pre-existing
// cross-suite `ModelContainer` concurrency flake `STATE.md` records.
extension MomentumContainerTouchingSuites {

@MainActor
@Suite("KidIdeasTests", .serialized)
struct KidIdeasTests {

    // MARK: - Task 1 helpers

    /// Builds an in-memory container over the full `RithamModelContainer` model list -- the
    /// production schema, not a hand-picked subset -- mirroring `PrivacyZoneTests.makeStore()`.
    private func makeStore() throws -> (store: HealthDataStore, container: ModelContainer) {
        let container = try RithamModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        return (HealthDataStore(context: context), container)
    }

    /// A second `HealthDataStore` over the *same* in-memory container but a fresh `ModelContext`
    /// -- proves a value round-trips through actual persistence rather than merely surviving in
    /// the first context's live object graph. Mirrors `PrivacyZoneTests.reopenStore(_:)`.
    private func reopenStore(_ container: ModelContainer) -> HealthDataStore {
        HealthDataStore(context: ModelContext(container))
    }

    // MARK: - Label rule

    @Test("a nil nickname falls back to the ordinal label")
    func nilNicknameFallsBackToOrdinalLabel() {
        #expect(ChildEntryStore.displayLabel(nickname: nil, position: 1) == KidContentCopy.Children.ordinalLabel(1))
        #expect(ChildEntryStore.displayLabel(nickname: nil, position: 2) == KidContentCopy.Children.ordinalLabel(2))
    }

    @Test("a non-empty nickname is returned unchanged, trimmed of surrounding whitespace")
    func nonEmptyNicknameIsReturnedTrimmed() {
        #expect(ChildEntryStore.displayLabel(nickname: "Sam", position: 1) == "Sam")
        #expect(ChildEntryStore.displayLabel(nickname: "  Sam  ", position: 1) == "Sam")
    }

    @Test("a whitespace-only nickname falls back to the ordinal label")
    func whitespaceOnlyNicknameFallsBackToOrdinalLabel() {
        #expect(ChildEntryStore.displayLabel(nickname: "   ", position: 3) == KidContentCopy.Children.ordinalLabel(3))
    }

    // MARK: - Real-store behaviour

    @Test("load on an empty store leaves entries empty")
    func loadOnEmptyStoreLeavesEntriesEmpty() throws {
        let (store, _) = try makeStore()
        let childStore = ChildEntryStore(store: store)
        childStore.load()
        #expect(childStore.entries.isEmpty)
    }

    @Test("two adds produce two entries whose display labels are the first and second ordinal labels")
    func twoAddsProduceFirstAndSecondOrdinalLabels() throws {
        let (store, container) = try makeStore()
        let childStore = ChildEntryStore(store: store)
        childStore.load()

        #expect(childStore.add())
        #expect(childStore.add())

        let reloaded = ChildEntryStore(store: reopenStore(container))
        reloaded.load()
        #expect(reloaded.entries.count == 2)
        #expect(reloaded.displayLabel(for: reloaded.entries[0]) == KidContentCopy.Children.ordinalLabel(1))
        #expect(reloaded.displayLabel(for: reloaded.entries[1]) == KidContentCopy.Children.ordinalLabel(2))
    }

    @Test("renaming the first entry changes only its label")
    func renamingFirstEntryChangesOnlyItsLabel() throws {
        let (store, container) = try makeStore()
        let childStore = ChildEntryStore(store: store)
        childStore.load()
        childStore.add()
        childStore.add()

        let firstID = try #require(childStore.entries.first?.id)
        childStore.rename(id: firstID, to: "Sam")

        let reloaded = ChildEntryStore(store: reopenStore(container))
        reloaded.load()
        #expect(reloaded.displayLabel(for: reloaded.entries[0]) == "Sam")
        #expect(reloaded.displayLabel(for: reloaded.entries[1]) == KidContentCopy.Children.ordinalLabel(2))
    }

    @Test("removing the first of three entries renumbers the remaining entries")
    func removingFirstOfThreeEntriesRenumbersRemaining() throws {
        let (store, container) = try makeStore()
        let childStore = ChildEntryStore(store: store)
        childStore.load()
        childStore.add()
        childStore.add()
        childStore.add()

        let firstID = try #require(childStore.entries.first?.id)
        childStore.remove(id: firstID)

        let reloaded = ChildEntryStore(store: reopenStore(container))
        reloaded.load()
        #expect(reloaded.entries.count == 2)
        #expect(reloaded.displayLabel(for: reloaded.entries[0]) == KidContentCopy.Children.ordinalLabel(1))
        #expect(reloaded.displayLabel(for: reloaded.entries[1]) == KidContentCopy.Children.ordinalLabel(2))
    }

    @Test("add returns true on success")
    func addReturnsTrueOnSuccess() throws {
        let (store, _) = try makeStore()
        let childStore = ChildEntryStore(store: store)
        childStore.load()
        #expect(childStore.add())
    }
}

}
