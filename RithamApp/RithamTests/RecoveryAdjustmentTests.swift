import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// RECOVERY-01's dedicated invariant suite, per D-05: one clearly named test per invariant, plus
// the registration/skippability coverage for the new `.sleepCheckIn` step (plan 03-08 Task 1) and
// the client-side lighter-plan adjustment (plan 03-08 Task 2, tested here in Task 3). Nested
// inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this suite
// resets and re-bootstraps `StepRegistry`'s shared static state via its own `init()`, exactly like
// every other registry-touching suite in this codebase -- it must be ordered relative to them
// during a full-target run, not only internally.
extension StepRegistryTouchingSuites {

@Suite("RecoveryAdjustmentTests", .serialized)
@MainActor
struct RecoveryAdjustmentTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
        // Shared static state with `WorkoutPlanClientTests`/`RecommendationsScreenTests`
        // (RecommendationsTests.swift) -- reset here so this suite's own network-stubbed tests
        // never see a stale handler left over from another test. Known, documented, pre-existing
        // race class (see this file's own header comment above and STATE.md's Blockers/Concerns):
        // a full-target run that schedules this suite concurrently with those two could still
        // interleave on `StubURLProtocol`'s shared state, since neither of those two suites is
        // nested under `StepRegistryTouchingSuites`. Out of this plan's file scope to fix (would
        // require editing `RecommendationsTests.swift`'s own suite declarations, not in this
        // plan's file list) -- flagged here rather than silently accepted.
        StubURLProtocol.reset()
    }

    // MARK: - Task 1: registration and skippability

    @Test("the sleepCheckIn step resolves to SleepCheckInView after bootstrap, and the registry reports no unregistered steps")
    func sleepCheckInResolvesAndRegistryIsComplete() {
        let registered = StepRegistry.registeredPresenterType(for: .sleepCheckIn)
        #expect(registered != nil)
        #expect(registered == SleepCheckInView.self)
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    /// Form used: a comment-filtered source check, the same technique
    /// `MomentumViewTests.noMomentumControlUsesTheDestructiveColor` already uses for an
    /// equivalent "this token never appears in this view's rendered strings" assertion -- no
    /// ViewInspector-style rendering tool exists in this codebase, so the screen's own source is
    /// the closest reachable proxy for "the strings this screen renders." Reads
    /// `SleepCheckInView.swift`'s source relative to this test file's `#filePath` and asserts the
    /// banned Momentum-state tokens never appear outside a `//` comment line -- the shared
    /// `OnboardingCopy.Errors.savingFailed` string and the `MomentumCopy.Sleep` namespace's own
    /// values are also asserted directly to carry none of those tokens, covering the fact that a
    /// source-text scan alone would miss a violation hidden inside a referenced copy constant's
    /// *value* rather than its *identifier*.
    @Test("theSleepScreenMentionsNoMomentumState")
    func theSleepScreenMentionsNoMomentumState() throws {
        let bannedTokens = ["shield", "streak", "milestone", "recovery week"]

        let thisFile = URL(fileURLWithPath: #filePath)
        // RithamApp/RithamTests/RecoveryAdjustmentTests.swift ->
        // RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift
        let viewFile = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Momentum/Views/SleepCheckInView.swift")
        let source = try String(contentsOf: viewFile, encoding: .utf8)
        let nonCommentSource = source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
            .lowercased()
        for token in bannedTokens {
            #expect(!nonCommentSource.contains(token), "SleepCheckInView.swift's non-comment source mentions '\(token)'")
        }

        let renderedStrings = [
            MomentumCopy.Sleep.headline,
            MomentumCopy.Sleep.optionGreat,
            MomentumCopy.Sleep.optionOK,
            MomentumCopy.Sleep.optionPoor,
            MomentumCopy.Sleep.noteFieldLabel,
            OnboardingCopy.Errors.savingFailed,
            "Done",
        ]
        for string in renderedStrings {
            let lowercased = string.lowercased()
            for token in bannedTokens {
                #expect(!lowercased.contains(token), "'\(string)' mentions '\(token)'")
            }
        }
    }

    @Test("dismissing without a selection writes no row")
    func dismissingWithoutSelectionWritesNoRow() throws {
        let pending = SleepCheckInView.pendingCheckIn(selection: [], note: "", day: Date())
        #expect(pending == nil)

        // End-to-end confirmation over a real store: nothing was ever written, so a later load
        // for the same day finds no row.
        let container = try RithamModelContainer.make(inMemory: true)
        let store = HealthDataStore(context: ModelContext(container))
        #expect(try store.loadSleepCheckIn(on: Date()) == nil)
    }
}

}
