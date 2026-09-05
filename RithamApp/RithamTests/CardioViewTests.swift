import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Phase 2 Plan 10's cardio-UI test suites, at the model/data level per the plan's own explicit
// instruction (not by rendering) -- the same discipline `AppShellTests`/`DisclaimerTagTests`
// already use. `CardioActivityPickerTests` (Task 1) is followed by `CardioSessionScreenTests`
// (Task 2) and `CardioHistoryTests` (Task 3) as this same file grows across the plan's tasks.
@MainActor
@Suite("CardioActivityPickerTests")
struct CardioActivityPickerTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    @Test("registers as the activity-picker step")
    func registersAsActivityPickerStep() {
        #expect(CardioActivityPickerView.step == .cardioActivityPicker)
    }

    @Test("selecting an activity type stores it as the model's selection")
    func selectingStoresSelection() {
        let model = CardioActivityPickerModel()

        model.select(.cycle)

        #expect(model.selectedActivityType == .cycle)
    }

    @Test("starting pushes the session step and carries the chosen activity type and capture mode")
    func startingPushesSessionStepWithCarriedState() {
        let model = CardioActivityPickerModel()
        let flow = OnboardingFlow(path: [.home, .cardioActivityPicker])
        model.select(.hike)

        model.start(mode: .gps, on: flow)

        #expect(flow.path.last == .cardioSession)
        #expect(flow.cardioActivityType == .hike)
        #expect(flow.cardioCaptureMode == .gps)
    }

    @Test("starting the manual path also carries the chosen activity type and mode")
    func startingManualPathCarriesState() {
        let model = CardioActivityPickerModel()
        let flow = OnboardingFlow(path: [.home, .cardioActivityPicker])
        model.select(.swim)

        model.start(mode: .manual, on: flow)

        #expect(flow.path.last == .cardioSession)
        #expect(flow.cardioActivityType == .swim)
        #expect(flow.cardioCaptureMode == .manual)
    }

    @Test("starting with nothing selected pushes nothing")
    func startingWithNoSelectionIsANoOp() {
        let model = CardioActivityPickerModel()
        let flow = OnboardingFlow(path: [.home, .cardioActivityPicker])

        model.start(mode: .manual, on: flow)

        #expect(flow.path.last == .cardioActivityPicker)
    }

    @Test("accepting a detection candidate carries its activity type into the selection")
    func acceptingDetectionCarriesActivityType() {
        let model = CardioActivityPickerModel()
        let candidate = MotionDetectionCandidate(activityType: .run, confidence: .high, detectedAt: Date())

        model.acceptDetection(candidate)

        #expect(model.selectedActivityType == .run)
    }

    @Test("dismissing a detection candidate leaves the stored cardio-session count unchanged")
    func dismissingDetectionLeavesStoredSessionCountUnchanged() throws {
        let store = try makeStore()
        try store.saveCardioSession(CardioSession(
            activityType: .walk,
            source: .manualStopwatch,
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 600),
            progress: CardioProgress(continuousDuration: 600, distanceMeters: 800)
        ))
        let countBefore = try store.loadCardioSessions().count

        let model = CardioActivityPickerModel()
        model.dismissDetection()

        let countAfter = try store.loadCardioSessions().count
        #expect(countAfter == countBefore)
    }
}
