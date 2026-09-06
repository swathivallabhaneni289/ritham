import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// `MovementSnapshotToggleView`'s picker and its Settings entry point (plan 03-09 Task 1), plus
// (Task 2) `MovementSnapshotView`'s calendar derivation and (Task 3) `HomeHubView`'s opt-in-gated
// routing. Named distinctly from `MovementSnapshotTests.swift` (03-05's own store-level suite for
// `movementSnapshotDays(in:)`/the opt-in accessors) so a filtered run selects exactly one of them
// -- this suite is the view-layer counterpart, following the exact precedent
// `MomentumTargetPickerTests` already set for its own near-identical shipped screen.
//
// Asserted at the data level against `HealthDataStore`/`MomentumCopy`/`SettingsView` directly --
// the same approach `WorkoutFrequencyTests`/`MomentumTargetPickerTests` already use -- rather than
// by rendering either view, since no ViewInspector-style rendering tool exists in this codebase.
extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("MovementSnapshotViewTests", .serialized)
    struct MovementSnapshotViewTests {

        private let calendar = Calendar(identifier: .gregorian)

        private func makeStore() throws -> HealthDataStore {
            let container = try RithamModelContainer.make(inMemory: true)
            return HealthDataStore(context: ModelContext(container), calendar: calendar)
        }

        // MARK: - Task 1: MovementSnapshotOptInOption / toggle behavior

        @Test("the opt-in defaults to off on an empty store")
        func optInDefaultsToOffOnEmptyStore() throws {
            let store = try makeStore()
            #expect(try store.loadMovementSnapshotOptIn() == false)
        }

        @Test("selecting the on option persists true and reloads as selected on reopen")
        func selectingOnOptionPersistsTrueAndReloads() throws {
            let store = try makeStore()
            try store.saveMovementSnapshotOptIn(true)
            #expect(try store.loadMovementSnapshotOptIn() == true)
        }

        @Test("selecting the off option persists false and reloads as selected on reopen")
        func selectingOffOptionPersistsFalseAndReloads() throws {
            let store = try makeStore()
            try store.saveMovementSnapshotOptIn(true)
            try store.saveMovementSnapshotOptIn(false)
            #expect(try store.loadMovementSnapshotOptIn() == false)
        }

        @Test("MovementSnapshotOptInOption.all is exactly the on and off options, on first")
        func optionsAreExactlyOnAndOffOnFirst() {
            #expect(MovementSnapshotOptInOption.all.map(\.isOn) == [true, false])
        }

        @Test("the screen's label, helper and two option strings equal the MomentumCopy.Snapshot constants")
        func screenLabelHelperAndOptionsMatchMomentumCopy() throws {
            #expect(MomentumCopy.Snapshot.toggleLabel == "Show Daily Movement Snapshot")
            #expect(
                MomentumCopy.Snapshot.toggleHelper
                    == "A plain calendar of your activity, with no streak, shield, or target attached."
            )
            #expect(MomentumCopy.Snapshot.toggleOptionOn == "On")
            #expect(MomentumCopy.Snapshot.toggleOptionOff == "Off")

            #expect(MovementSnapshotToggleView.optionTitle(MovementSnapshotOptInOption(isOn: true)) == MomentumCopy.Snapshot.toggleOptionOn)
            #expect(MovementSnapshotToggleView.optionTitle(MovementSnapshotOptInOption(isOn: false)) == MomentumCopy.Snapshot.toggleOptionOff)
        }

        // MARK: - Task 1: Settings entry point

        @Test("the Settings row for the Daily Movement Snapshot uses the expected label")
        func settingsRowLabelForMovementSnapshot() {
            #expect(SettingsView.movementSnapshotRowTitle == "Daily Movement Snapshot")
        }

        @Test("the opt-in loaded for sheet presentation reflects the most recently persisted value, not a cached one")
        func sheetPresentationLoadsFreshValueNotCached() throws {
            let store = try makeStore()

            // `SettingsView.currentMovementSnapshotOptIn()` defers directly to
            // `HealthDataStore.loadMovementSnapshotOptIn()` with no caching of its own (mirroring
            // `currentMomentumTarget()`'s identical pattern) -- proven here at the store level: a
            // second load, after a second persist, reflects the newest value, never a value
            // cached from the first load.
            try store.saveMovementSnapshotOptIn(true)
            #expect(try store.loadMovementSnapshotOptIn() == true)

            try store.saveMovementSnapshotOptIn(false)
            #expect(try store.loadMovementSnapshotOptIn() == false)
        }

        // MARK: - Task 2: MovementSnapshotView's calendar derivation

        private func makeSession(day: Date) throws -> HealthDataStore {
            let store = try makeStore()
            try store.saveCardioSession(CardioSession(
                activityType: .run,
                source: .gps,
                startedAt: day.addingTimeInterval(3_600),
                endedAt: day.addingTimeInterval(5_400),
                progress: CardioProgress(continuousDuration: 1_800, distanceMeters: 5_000)
            ))
            return store
        }

        @Test("a month whose days include a stored cardio session marks exactly that day")
        func monthWithCardioSessionMarksExactlyThatDay() throws {
            let day = calendar.startOfDay(for: Date())
            let store = try makeSession(day: day)

            guard let range = MovementSnapshotView.monthRange(containing: day, calendar: calendar) else {
                Issue.record("expected a resolvable month range")
                return
            }
            let days = try store.movementSnapshotDays(in: range)

            let markedDays = days.filter(\.hasLoggedActivity)
            #expect(markedDays.count == 1)
            #expect(markedDays.first.map { calendar.isDate($0.date, inSameDayAs: day) } == true)
        }

        @Test("a month whose days include a stored lift session marks exactly that day")
        func monthWithLiftSessionMarksExactlyThatDay() throws {
            let day = calendar.startOfDay(for: Date())
            let store = try makeStore()
            try store.saveLiftSession(LiftSession(startedAt: day.addingTimeInterval(3_600), sets: []))

            guard let range = MovementSnapshotView.monthRange(containing: day, calendar: calendar) else {
                Issue.record("expected a resolvable month range")
                return
            }
            let days = try store.movementSnapshotDays(in: range)

            let markedDays = days.filter(\.hasLoggedActivity)
            #expect(markedDays.count == 1)
            #expect(markedDays.first.map { calendar.isDate($0.date, inSameDayAs: day) } == true)
        }

        @Test("a month with a stored session that does not clear the qualification bar still marks that day")
        func monthWithNonQualifyingSessionStillMarksThatDay() throws {
            let day = calendar.startOfDay(for: Date())
            let store = try makeStore()
            // Well under CalibrationThreshold.qualifyingWalkDuration (600s) -- logged, but not
            // qualifying. The snapshot reflects logged activity, never qualifying activity.
            try store.saveCardioSession(CardioSession(
                activityType: .run,
                source: .gps,
                startedAt: day.addingTimeInterval(3_600),
                endedAt: day.addingTimeInterval(3_720),
                progress: CardioProgress(continuousDuration: 120, distanceMeters: 300)
            ))

            guard let range = MovementSnapshotView.monthRange(containing: day, calendar: calendar) else {
                Issue.record("expected a resolvable month range")
                return
            }
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.hasLoggedActivity == true)
        }

        @Test("a month with no stored session renders the catalog's no-entries empty state")
        func monthWithNoSessionRendersEmptyState() throws {
            let day = calendar.startOfDay(for: Date())
            let store = try makeStore()

            guard let range = MovementSnapshotView.monthRange(containing: day, calendar: calendar) else {
                Issue.record("expected a resolvable month range")
                return
            }
            let days = try store.movementSnapshotDays(in: range)

            #expect(days.allSatisfy { !$0.hasLoggedActivity })
            #expect(MomentumCopy.Empty.noSnapshotEntriesHeadline == "No entries yet")
            #expect(MomentumCopy.Empty.noSnapshotEntriesBody == "Movement Snapshot fills in as you log activity.")
        }

        /// Form used: a comment-filtered directory scan, the same technique
        /// `RecoveryAdjustmentTests.theSleepScreenMentionsNoMomentumState` already established
        /// for an equivalent "this feature area references none of these tokens" assertion, here
        /// generalized to every file under the feature's own directory rather than a single file
        /// -- the directory-scoped structural boundary this whole feature is built around
        /// (T-3-15's mitigation, see `MovementSnapshotView.swift`'s own header comment).
        @Test("theSnapshotScreenReferencesNoMomentumType")
        func theSnapshotScreenReferencesNoMomentumType() throws {
            let bannedTokens = [
                "MomentumSummary", "MomentumStateRecord", "MomentumProgressBlocks",
                "ShieldRow", "MilestoneBadgeList", "currentStreak", "shieldCount", "weeklyTarget",
            ]

            let thisFile = URL(fileURLWithPath: #filePath)
            // RithamApp/RithamTests/MovementSnapshotViewTests.swift ->
            // RithamApp/Ritham/MovementSnapshot/
            let featureDirectory = thisFile
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Ritham/MovementSnapshot")

            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: featureDirectory, includingPropertiesForKeys: nil) else {
                Issue.record("could not enumerate \(featureDirectory.path)")
                return
            }

            var scannedAtLeastOneFile = false
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                scannedAtLeastOneFile = true
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                let nonCommentSource = source
                    .components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                    .joined(separator: "\n")
                for token in bannedTokens {
                    #expect(!nonCommentSource.contains(token), "\(fileURL.lastPathComponent)'s non-comment source mentions '\(token)'")
                }
            }
            #expect(scannedAtLeastOneFile)
        }
    }
}

extension StepRegistryTouchingSuites {
    @MainActor
    @Suite("MovementSnapshotRegistrationTests", .serialized)
    struct MovementSnapshotRegistrationTests {

        init() {
            StepRegistry.reset()
            StepBootstrap.registerAllSteps()
        }

        @Test("the movementSnapshot step resolves to MovementSnapshotView after bootstrap")
        func movementSnapshotResolvesToMovementSnapshotView() {
            let registered = StepRegistry.registeredPresenterType(for: .movementSnapshot)
            #expect(registered != nil)
            #expect(registered == MovementSnapshotView.self)
        }

        @Test("the registry reports no unregistered steps after bootstrap")
        func registryReportsNoUnregisteredSteps() {
            #expect(StepRegistry.unregisteredSteps.isEmpty)
        }
    }
}
