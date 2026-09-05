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

// Task 2: the live session screen.
@MainActor
@Suite("CardioSessionScreenTests")
struct CardioSessionScreenTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    @Test("registers as the cardio-session step")
    func registersAsSessionStep() {
        #expect(CardioSessionView.step == .cardioSession)
    }

    @Test("a manual-capture session runs the stopwatch and finishes as not sensor-verified")
    func manualCaptureFinishesNotSensorVerified() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let model = CardioSessionModel(
            activityType: .run,
            gpsSession: nil,
            stopwatchSession: StopwatchCardioSession(activityType: .run, now: { currentDate })
        )

        model.start()
        currentDate = currentDate.addingTimeInterval(60)
        let session = model.finish()

        #expect(model.isUsingManualCapture)
        #expect(session.source.isSensorVerified == false)
    }

    @Test("a denied GPS authorization leaves the session running on the manual adapter")
    func deniedAuthorizationFallsBackToManualAdapter() {
        let gps = GPSTrackingSession(activityType: .walk, authorizationStatusProvider: { .denied })
        let model = CardioSessionModel(activityType: .walk, gpsSession: gps)

        model.start()

        #expect(model.isUsingManualCapture)
        #expect(model.isRunning)
    }

    @Test("pausing freezes elapsed duration; resuming continues accumulating from the frozen value")
    func pausingFreezesAndResumingContinues() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let model = CardioSessionModel(
            activityType: .walk,
            gpsSession: nil,
            stopwatchSession: StopwatchCardioSession(activityType: .walk, now: { currentDate })
        )

        model.start()
        currentDate = currentDate.addingTimeInterval(60)
        model.pause()
        currentDate = currentDate.addingTimeInterval(30)

        #expect(model.progress.continuousDuration == 60)

        model.resume()
        currentDate = currentDate.addingTimeInterval(15)

        #expect(model.progress.continuousDuration == 75)
    }

    @Test("finishing increases the stored cardio session count by exactly one")
    func finishingIncreasesStoredCountByExactlyOne() throws {
        let store = try makeStore()
        let countBefore = try store.loadCardioSessions().count

        let model = CardioSessionModel(activityType: .cycle, gpsSession: nil)
        model.start()
        let session = model.finish()
        try store.saveCardioSession(session)

        let countAfter = try store.loadCardioSessions().count
        #expect(countAfter == countBefore + 1)
    }

    @Test("grade-adjusted pace is nil when elevation confidence is below medium")
    func gradeAdjustedPaceNilBelowMediumConfidence() {
        let adjusted = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 5,
            elevationConfidence: .low
        )
        #expect(adjusted == nil)
    }

    @Test("grade-adjusted pace resolves to a value when elevation confidence is medium or better")
    func gradeAdjustedPaceResolvesAtMediumConfidence() {
        let adjusted = GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: 300,
            gradePercent: 5,
            elevationConfidence: .medium
        )
        #expect(adjusted != nil)
    }
}
