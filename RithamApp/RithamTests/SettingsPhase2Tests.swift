import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// MONETIZE-01: the visible always-free capability list. Asserted directly against the declared
// `AlwaysFreeCapability.all` collection -- the same source `AlwaysFreeListView` renders -- rather
// than by rendering the view itself, the same data-level approach `EditAnswerFlowTests` uses for
// `SettingsView`/`DietPlanView`.
@Suite("AlwaysFreeListTests")
struct AlwaysFreeListTests {

    @Test("the declared capability collection has at least 7 entries")
    func capabilityCollectionHasAtLeastSevenEntries() throws {
        #expect(AlwaysFreeCapability.all.count >= 7)
    }

    @Test("the capability collection names every capability this build actually ships free")
    func capabilityCollectionNamesExpectedCapabilities() throws {
        let combined = AlwaysFreeCapability.all.map { "\($0.title) \($0.detail)".lowercased() }

        func namesCapability(containing fragment: String) -> Bool {
            combined.contains { $0.contains(fragment) }
        }

        #expect(namesCapability(containing: "stopwatch"))
        #expect(namesCapability(containing: "gps"))
        #expect(namesCapability(containing: "history"))
        #expect(namesCapability(containing: "plate"))
        #expect(namesCapability(containing: "one-rep-max") || namesCapability(containing: "1rm"))
        #expect(namesCapability(containing: "superset"))
        #expect(namesCapability(containing: "movement-pattern") || namesCapability(containing: "movement pattern"))
    }

    @Test("no capability entry names heart-rate display, the one capability this build lacks")
    func capabilityCollectionNamesNoHeartRateDisplay() throws {
        let namesHeartRate = AlwaysFreeCapability.all.contains {
            $0.title.localizedCaseInsensitiveContains("heart rate")
                || $0.detail.localizedCaseInsensitiveContains("heart rate")
                || $0.title.localizedCaseInsensitiveContains("heart-rate")
                || $0.detail.localizedCaseInsensitiveContains("heart-rate")
        }
        #expect(!namesHeartRate)
    }

    @Test("no capability entry exposes a purchase, subscribe, or upgrade action -- descriptive text only")
    func capabilityEntriesExposeNoPurchaseAction() throws {
        for capability in AlwaysFreeCapability.all {
            let mirror = Mirror(reflecting: capability)
            for child in mirror.children {
                #expect(!(child.value is () -> Void))
            }

            let text = "\(capability.title) \(capability.detail)".lowercased()
            #expect(!text.contains("purchase"))
            #expect(!text.contains("subscribe"))
            #expect(!text.contains("upgrade"))
        }
    }

    @Test("the forgiveness statement documents that shields/comeback repair/injury guardrail are never monetized, and arrive with Momentum")
    func forgivenessStatementDocumentsMomentumTiming() throws {
        let statement = AlwaysFreeCapability.forgivenessStatement.lowercased()
        #expect(statement.contains("momentum"))
        #expect(statement.contains("never monetized"))
    }
}
