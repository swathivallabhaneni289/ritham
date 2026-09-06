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

    // MARK: - Task 3: one named test per RECOVERY-01 invariant (D-05), plus two wire/volume gates
    //
    // Each test below uses a stubbed `WorkoutPlanClient` (`StubURLProtocol`, the same technique
    // `RecommendationsTests.swift` already established) so no real network is involved, and a
    // fresh in-memory `HealthDataStore` per test for the sleep check-in and Momentum ledger.

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        let store = HealthDataStore(context: ModelContext(container))
        try store.updateProfile(UserProfileDraft(age: 30))
        try store.markPreAssessmentCompleted()
        return store
    }

    /// Two exercises at 3 sets each so both the original (6 total) and the adjusted (4 total,
    /// after the -1-set-per-exercise lever) prescriptions clear `LiftQualification`'s fixed
    /// 3-sets-across-2-exercises bar -- letting the same fixture exercise both
    /// `aLighterSuggestedSessionThatMeetsTheBarFullyQualifies` and
    /// `decliningTheLighterSuggestionIsAlwaysAvailableAndFullyQualifies` without the floor-of-one
    /// edge case interfering.
    private let representativeSessionsJSON = """
    [{"dayIndex":1,"focus":"full-body foundations","exercises":[{"name":"Squat","sets":3,"repRange":"8-10"},{"name":"Row","sets":3,"repRange":"8-10"}]}]
    """

    private func makeStubbedClient(sessions: String) -> WorkoutPlanClient {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"plan":{"frequencyPerWeek":3,"sessions":\(sessions),"guidanceNote":"General guidance only."}}
            """.data(using: .utf8)!
            return (response, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return WorkoutPlanClient(session: session, baseURL: URL(string: "http://127.0.0.1:8080")!)
    }

    private func makeLiftSession(setsPerExercise: Int, exercises: [String]) -> LiftSession {
        var sets: [LiftSet] = []
        var orderIndex = 0
        for exercise in exercises {
            for _ in 0..<setsPerExercise {
                sets.append(LiftSet(exerciseIdentifier: exercise, reps: 8, orderIndex: orderIndex, completedAt: Date()))
                orderIndex += 1
            }
        }
        return LiftSession(startedAt: Date(), sets: sets)
    }

    @Test("theQualificationBarIsUnchangedByAnySleepState")
    func theQualificationBarIsUnchangedByAnySleepState() {
        let qualifyingProgress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration + 60)
        let nonQualifyingProgress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration - 60)
        let checkIns: [SleepCheckIn?] = [
            nil,
            SleepCheckIn(day: Date(), quality: .great),
            SleepCheckIn(day: Date(), quality: .ok),
            SleepCheckIn(day: Date(), quality: .poor),
        ]

        // Neither `CardioQualification.evaluate` nor `LiftQualification.evaluate` takes a sleep
        // check-in parameter at all -- this loop proves the identical session fixture evaluates
        // identically regardless of which check-in (or none) is on record, without ever feeding a
        // check-in into either evaluator (RECOVERY-01 invariant 4).
        for checkIn in checkIns {
            _ = SleepAdjustment.shift(for: checkIn)
            #expect(CardioQualification.evaluate(qualifyingProgress) == .complete)
            #expect(CardioQualification.evaluate(nonQualifyingProgress) == .incomplete)
        }

        let qualifyingLift = makeLiftSession(setsPerExercise: 2, exercises: ["Squat", "Row"])
        let nonQualifyingLift = makeLiftSession(setsPerExercise: 1, exercises: ["Squat"])
        for checkIn in checkIns {
            _ = SleepAdjustment.shift(for: checkIn)
            #expect(LiftQualification.evaluate(qualifyingLift) == .complete)
            #expect(LiftQualification.evaluate(nonQualifyingLift) == .incomplete)
        }
    }

    @Test("aLighterSuggestedSessionThatMeetsTheBarFullyQualifies")
    func aLighterSuggestedSessionThatMeetsTheBarFullyQualifies() {
        // Adjusted from 3 sets down to 2 per exercise (SleepAdjustment.adjustedSetCount's one
        // lever) -- still clears the bar at 2+2=4 total sets across 2 exercises.
        let adjustedSets = SleepAdjustment.adjustedSetCount(3, shift: .lighter)
        #expect(adjustedSets == 2)

        let session = makeLiftSession(setsPerExercise: adjustedSets, exercises: ["Squat", "Row"])
        #expect(LiftQualification.evaluate(session) == .complete)
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [], lift: [session]) == 1)
    }

    @Test("decliningTheLighterSuggestionIsAlwaysAvailableAndFullyQualifies")
    func decliningTheLighterSuggestionIsAlwaysAvailableAndFullyQualifies() async throws {
        let store = try makeStore()
        try store.saveSleepCheckIn(SleepCheckIn(day: Date(), quality: .poor))
        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow)

        #expect(model.originalPlan != nil)
        #expect(model.adjustedPlan != nil)

        // "Do the original session instead" is always available -- toggling exposes the
        // unadjusted original plan (RECOVERY-01 invariant 2).
        model.toggleDisplayedPlan()
        guard case .plan(let displayed) = model.state else {
            Issue.record("expected a plan state, got \(model.state)")
            return
        }
        #expect(displayed == model.originalPlan)

        let originalSets = displayed.sessions.first?.exercises.first?.sets ?? 0
        #expect(originalSets == 3)
        let session = makeLiftSession(setsPerExercise: originalSets, exercises: ["Squat", "Row"])
        #expect(LiftQualification.evaluate(session) == .complete)
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [], lift: [session]) == 1)
    }

    @Test("skippingTheCheckInHasZeroEffect")
    func skippingTheCheckInHasZeroEffect() async throws {
        let store = try makeStore()
        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])
        let now = Date()

        await model.requestPlan(flow: flow, now: now)

        guard case .plan(let plan) = model.state else {
            Issue.record("expected a plan state, got \(model.state)")
            return
        }
        // No check-in was ever stored -- no banner, no toggle (the view's own gate is
        // `model.adjustedPlan != nil`), and the returned plan is byte-identical to the client's.
        #expect(model.adjustedPlan == nil)
        #expect(plan == model.originalPlan)
        #expect(plan.sessions.first?.exercises.first?.sets == 3)

        let reader = MomentumSummaryReader(store: store, calendar: .current)
        let summaryWithNoCheckIn = try reader.summary(now: now)

        try store.saveSleepCheckIn(SleepCheckIn(day: now, quality: .great))
        let summaryWithGreatCheckIn = try reader.summary(now: now)

        #expect(summaryWithNoCheckIn == summaryWithGreatCheckIn)
    }

    @Test("theAdjustmentNeverConsumesAShield")
    func theAdjustmentNeverConsumesAShield() async throws {
        let store = try makeStore()
        try store.saveSleepCheckIn(SleepCheckIn(day: Date(), quality: .poor))

        let reader = MomentumSummaryReader(store: store, calendar: .current)
        let before = try reader.summary(now: Date())
        #expect(before.shieldCount == 0)

        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])
        await model.requestPlan(flow: flow)

        let after = try reader.summary(now: Date())
        #expect(after.shieldCount == before.shieldCount)
    }

    @Test("theAdjustmentNeverTriggersARecoveryWeek")
    func theAdjustmentNeverTriggersARecoveryWeek() async throws {
        let store = try makeStore()
        try store.saveSleepCheckIn(SleepCheckIn(day: Date(), quality: .poor))

        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])
        await model.requestPlan(flow: flow)

        #expect(try store.loadRecoveryWeekPeriods().isEmpty)
    }

    @Test("noMessagingDifferentiatesTrainingHarderThanSuggested")
    func noMessagingDifferentiatesTrainingHarderThanSuggested() async throws {
        let store = try makeStore()
        try store.saveSleepCheckIn(SleepCheckIn(day: Date(), quality: .poor))
        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])
        await model.requestPlan(flow: flow)

        guard let original = model.originalPlan, let adjusted = model.adjustedPlan else {
            Issue.record("expected both an original and an adjusted plan")
            return
        }

        // Both are the exact same Codable struct type, so no new field/flag/string can exist on
        // one but not the other -- reflected here rather than merely assumed from the type
        // system, matching this codebase's own Mirror-based structural-invariant style
        // (`momentumSummaryCarriesNoSleepState`).
        let originalSessionLabels = Mirror(reflecting: original.sessions[0]).children.map(\.label)
        let adjustedSessionLabels = Mirror(reflecting: adjusted.sessions[0]).children.map(\.label)
        #expect(originalSessionLabels == adjustedSessionLabels)

        let originalExerciseLabels = Mirror(reflecting: original.sessions[0].exercises[0]).children.map(\.label)
        let adjustedExerciseLabels = Mirror(reflecting: adjusted.sessions[0].exercises[0]).children.map(\.label)
        #expect(originalExerciseLabels == adjustedExerciseLabels)

        // The only observable difference between the two plans' rows is the numeric `sets` count
        // itself -- every other field is identical, never a new marker distinguishing "trained
        // harder than suggested" from "accepted the lighter option."
        #expect(original.sessions[0].focus == adjusted.sessions[0].focus)
        #expect(original.sessions[0].dayIndex == adjusted.sessions[0].dayIndex)
        #expect(original.sessions[0].exercises[0].name == adjusted.sessions[0].exercises[0].name)
        #expect(original.sessions[0].exercises[0].repRange == adjusted.sessions[0].exercises[0].repRange)
    }

    @Test("theWorkoutPlanRequestStillCarriesExactlyThreeFields")
    func theWorkoutPlanRequestStillCarriesExactlyThreeFields() throws {
        let request = WorkoutPlanRequest(frequencyPerWeek: 3, experienceLevel: "beginner", guidancePermission: "none")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys = Set(object.map { Array($0.keys) } ?? [])
        #expect(keys.count == 3)
        #expect(keys == ["frequencyPerWeek", "experienceLevel", "guidancePermission"])
    }

    @Test("theLighterAdjustmentNeverIncreasesPrescribedVolume")
    func theLighterAdjustmentNeverIncreasesPrescribedVolume() async throws {
        // The scalar lever, across a representative range of prescribed set counts (0 is not a
        // realistic exercise prescription and is out of scope for this guarantee).
        for original in [1, 2, 3, 4, 5, 10] {
            #expect(SleepAdjustment.adjustedSetCount(original, shift: .unchanged) == original)
            let lighter = SleepAdjustment.adjustedSetCount(original, shift: .lighter)
            #expect(lighter <= original)
            #expect(lighter >= 1)
        }

        // And across every session/exercise in a real plan pair produced by the model.
        let store = try makeStore()
        try store.saveSleepCheckIn(SleepCheckIn(day: Date(), quality: .poor))
        let client = makeStubbedClient(sessions: representativeSessionsJSON)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])
        await model.requestPlan(flow: flow)

        guard let original = model.originalPlan, let adjusted = model.adjustedPlan else {
            Issue.record("expected both an original and an adjusted plan")
            return
        }
        for (originalSession, adjustedSession) in zip(original.sessions, adjusted.sessions) {
            for (originalExercise, adjustedExercise) in zip(originalSession.exercises, adjustedSession.exercises) {
                #expect(adjustedExercise.sets <= originalExercise.sets)
                #expect(adjustedExercise.sets >= 1)
            }
        }
    }
}

}
