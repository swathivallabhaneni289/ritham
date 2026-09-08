import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Closes 04-RESEARCH.md's first Wave 0 gap: no dedicated diet test suite existed anywhere in the
// repo (`find RithamApp/RithamTests -iname "*Diet*"` returned nothing before this file). Proves
// DIET-01's isolation both behaviourally, at the store level the new pickers call directly
// (`aDietaryPatternWriteLeavesEveryConditionTagUntouched` /
// `anAllergenWriteLeavesEveryConditionTagUntouched`), and structurally, at the file level, so a
// future edit to the dashboard-embeddable `DietPlanSectionContent.swift` cannot silently reach the
// screening write path even without a behavioural regression firing first
// (`theDietSectionContentReachesNoScreeningWritePath`). The counterpart guard
// (`theSettingsDietPlanScreenStillOwnsTheScreeningQuestion`) protects against the opposite
// mistake: a careless cleanup deleting the screening question outright now that D-05 narrowed
// where diet controls live.
//
// Nested inside `MomentumContainerTouchingSuites` (`MomentumSuiteSerialization.swift`) because
// this suite instantiates in-memory SwiftData `ModelContainer`s -- STATE.md records an open
// low-frequency crash when unrelated suites do that concurrently, and this parent suite is the
// project's established fix.
extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("DietSectionIsolationTests", .serialized)
    struct DietSectionIsolationTests {

        /// Matches `MovementSnapshotTests`' own helper shape.
        private func makeStore() throws -> HealthDataStore {
            let container = try RithamModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            return HealthDataStore(context: context)
        }

        // MARK: - Behavioural half: a diet/allergen write never touches condition tags

        @Test("a dietary pattern write leaves every stored condition tag untouched")
        func aDietaryPatternWriteLeavesEveryConditionTagUntouched() throws {
            let store = try makeStore()
            try store.updateProfile(UserProfileDraft(age: 15))

            // Any ScreeningAnswers value that resolves to at least one condition tag -- an
            // age-derived tag is the simplest way to guarantee a non-empty matched set without
            // depending on any particular checklist branch's derivation logic.
            let result = GateResolution.resolve(answers: ScreeningAnswers(), ageDerivedTags: [.under18Minor])
            try store.saveScreeningResult(result, answers: ScreeningAnswers(), now: Date())

            let before = Set(try store.activeConditionTags(now: Date()))
            #expect(!before.isEmpty, "fixture must seed at least one condition tag, or this test cannot prove isolation")

            try store.updateProfile(UserProfileDraft(age: 15, dietaryPattern: .vegan))

            let after = Set(try store.activeConditionTags(now: Date()))
            #expect(after == before)
            #expect(try store.loadProfile().dietaryPattern == .vegan)
        }

        @Test("an allergen write leaves every stored condition tag untouched")
        func anAllergenWriteLeavesEveryConditionTagUntouched() throws {
            let store = try makeStore()
            try store.updateProfile(UserProfileDraft(age: 15))

            let result = GateResolution.resolve(answers: ScreeningAnswers(), ageDerivedTags: [.under18Minor])
            try store.saveScreeningResult(result, answers: ScreeningAnswers(), now: Date())

            let before = Set(try store.activeConditionTags(now: Date()))
            #expect(!before.isEmpty, "fixture must seed at least one condition tag, or this test cannot prove isolation")

            try store.saveFoodAllergens([.peanuts, .milk])

            let after = Set(try store.activeConditionTags(now: Date()))
            #expect(after == before)
            #expect(try store.loadFoodAllergens() == [.peanuts, .milk])
        }

        // MARK: - Structural half: the dashboard-embeddable file cannot reach the screening write path

        @Test("the dashboard-embeddable diet section content reaches no screening write path")
        func theDietSectionContentReachesNoScreeningWritePath() throws {
            let bannedTokens = [
                "GateResolution", "saveScreeningResult", "ScreeningAnswers", "checklist", "ChecklistItem", "dismiss",
            ]

            guard let filteredSource = try Self.commentFilteredSource(fileNamed: "DietPlanSectionContent.swift") else {
                Issue.record("could not locate Ritham/Settings/DietPlanSectionContent.swift")
                return
            }

            // Non-vacuous-pass guard: prove the scan really read the intended file before
            // asserting the absence of anything.
            #expect(!filteredSource.isEmpty)
            #expect(filteredSource.contains("saveFoodAllergens"))

            for token in bannedTokens {
                #expect(
                    !filteredSource.contains(token),
                    "DietPlanSectionContent.swift contains a screening-write-path token outside a comment: \(token)"
                )
            }
        }

        @Test("the Settings-presented DietPlanView still owns the screening question")
        func theSettingsDietPlanScreenStillOwnsTheScreeningQuestion() throws {
            guard let filteredSource = try Self.commentFilteredSource(fileNamed: "DietPlanView.swift") else {
                Issue.record("could not locate Ritham/Settings/DietPlanView.swift")
                return
            }

            #expect(!filteredSource.isEmpty)
            #expect(filteredSource.contains("checklistBinding"))
            #expect(filteredSource.contains("resolveAndSaveScreening"))
        }

        /// Resolves `Ritham/Settings/<fileName>` relative to this test file's own `#filePath`
        /// (two `deletingLastPathComponent()` calls then `appendingPathComponent`, exactly as
        /// `Phase3CoverageTests` and `MovementSnapshotViewTests` already do), reads it, and drops
        /// every line whose trimmed form starts with `//` -- the same comment-filtering technique
        /// those suites already established. Returns `nil` when the resolved file does not exist.
        private static func commentFilteredSource(fileNamed fileName: String) throws -> String? {
            let thisFile = URL(fileURLWithPath: #filePath)
            // RithamApp/RithamTests/DietSectionIsolationTests.swift -> RithamApp/Ritham/Settings/<fileName>
            let target = thisFile
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Ritham")
                .appendingPathComponent("Settings")
                .appendingPathComponent(fileName)

            guard FileManager.default.fileExists(atPath: target.path) else {
                return nil
            }

            let source = try String(contentsOf: target, encoding: .utf8)
            return source
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
        }
    }
}
