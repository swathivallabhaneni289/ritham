import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// `MomentumTargetView`'s picker and its Settings entry point (plan 03-07). Named distinctly from
// `RithamCore`'s own `MomentumTargetTests` suite (which covers `MomentumTarget`'s pure domain
// math) so a filtered run selects exactly one of them. Nested inside
// `MomentumContainerTouchingSuites` and `.serialized`, the same cross-suite SwiftData
// `ModelContainer` concurrency discipline `MomentumStoreTests`/`MomentumSummaryTests` already use.
//
// Asserted at the data level against `HealthDataStore` and `MomentumCopy` directly -- the same
// approach `WorkoutFrequencyTests` (`SettingsPhase2Tests.swift`) already uses for its own,
// near-identical shipped screen -- rather than by rendering `MomentumTargetView` itself.
extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("MomentumTargetPickerTests", .serialized)
    struct MomentumTargetPickerTests {

        private func makeStore() throws -> HealthDataStore {
            let container = try RithamModelContainer.make(inMemory: true)
            return HealthDataStore(context: ModelContext(container))
        }

        // MARK: - Task 1: MomentumTargetOption / picker behavior

        @Test("MomentumTargetOption.all's values, as a set, equal HealthDataStore.supportedMomentumTargets")
        func pickerOptionsMatchTheStoreSupportedTargets() throws {
            let expected = HealthDataStore.supportedMomentumTargets
            #expect(Set(MomentumTargetOption.all.map(\.target)) == expected)
        }

        @Test(
            "selecting each supported value persists it and reloads identically",
            arguments: [2, 3, 4, 5]
        )
        func selectingEachSupportedValuePersistsAndReloadsIdentically(_ target: Int) throws {
            let store = try makeStore()
            try store.saveMomentumTarget(target)
            #expect(try store.loadMomentumTarget() == target)
        }

        @Test("the screen's prompt and helper strings equal the MomentumCopy.Target constants")
        func screenPromptAndHelperMatchMomentumCopy() throws {
            #expect(MomentumCopy.Target.pickerPrompt == "Weekly Momentum target")
            #expect(
                MomentumCopy.Target.pickerHelper
                    == "How many qualifying sessions do you want to aim for each week? Change this anytime."
            )
        }

        @Test(
            "persisting an unsupported value throws and leaves the previously stored value in place",
            arguments: [0, 1, 6, 10, -1]
        )
        func persistingUnsupportedValueThrowsAndLeavesStoredValueInPlace(_ target: Int) throws {
            let store = try makeStore()
            try store.saveMomentumTarget(4)

            #expect(throws: HealthDataStoreError.unsupportedMomentumTarget) {
                try store.saveMomentumTarget(target)
            }
            #expect(try store.loadMomentumTarget() == 4)
        }
    }
}
