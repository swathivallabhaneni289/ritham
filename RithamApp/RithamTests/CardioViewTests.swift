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

// Task 3: training history and opt-in single-user route comparison.
@MainActor
@Suite("CardioHistoryTests")
struct CardioHistoryTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeCardioSession(
        activityType: ActivityType = .run,
        startedAt: Date,
        distanceMeters: Double = 5_000,
        source: CardioCaptureSource = .gps
    ) -> CardioSession {
        CardioSession(
            activityType: activityType,
            source: source,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(1_800),
            progress: CardioProgress(continuousDuration: 1_800, distanceMeters: distanceMeters)
        )
    }

    @Test("registers as the cardio-history step")
    func registersAsHistoryStep() {
        #expect(CardioHistoryView.step == .cardioHistory)
    }

    @Test("an empty store yields the empty state rather than an empty list")
    func emptyStoreYieldsEmptyState() throws {
        let store = try makeStore()
        let model = CardioHistoryModel(store: store)

        model.load()

        #expect(model.isEmpty)
        #expect(model.sessions.isEmpty)
    }

    @Test("loading returns sessions most recent first with the store's own ordering")
    func loadingReturnsSessionsMostRecentFirst() throws {
        let store = try makeStore()
        let earlier = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000))
        let later = makeCardioSession(startedAt: Date(timeIntervalSince1970: 2_000))
        try store.saveCardioSession(earlier)
        try store.saveCardioSession(later)

        let model = CardioHistoryModel(store: store)
        model.load()

        #expect(model.sessions.first?.id == later.id)
        #expect(model.isEmpty == false)
    }

    @Test("a manually entered session is distinguishable from a sensor-verified one via isSensorVerified")
    func manualVersusSensorVerifiedIsDistinguishable() throws {
        let store = try makeStore()
        let manual = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000), source: .manualStopwatch)
        let sensor = makeCardioSession(startedAt: Date(timeIntervalSince1970: 2_000), source: .gps)
        try store.saveCardioSession(manual)
        try store.saveCardioSession(sensor)

        let model = CardioHistoryModel(store: store)
        model.load()

        #expect(model.sessions.first(where: { $0.id == manual.id })?.source.isSensorVerified == false)
        #expect(model.sessions.first(where: { $0.id == sensor.id })?.source.isSensorVerified == true)
    }

    @Test("with the route-comparison opt-in off, the history model produces no comparison entry point")
    func optInOffProducesNoComparisonEntryPoint() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(false)
        let session = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000))
        try store.saveCardioSession(session)

        let model = CardioHistoryModel(store: store)
        model.load()

        #expect(model.comparisonEntryPoint(for: session) == nil)
    }

    @Test("with the opt-in on, the history model produces a comparison entry point")
    func optInOnProducesComparisonEntryPoint() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(true)
        let session = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000))
        try store.saveCardioSession(session)

        let model = CardioHistoryModel(store: store)
        model.load()

        #expect(model.comparisonEntryPoint(for: session) != nil)
    }

    @Test("turning the opt-in off again immediately removes the comparison entry point")
    func togglingOptInOffRemovesEntryPoint() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(true)
        let session = makeCardioSession(startedAt: Date(timeIntervalSince1970: 1_000))
        try store.saveCardioSession(session)

        let model = CardioHistoryModel(store: store)
        model.load()
        #expect(model.comparisonEntryPoint(for: session) != nil)

        try store.saveRouteComparisonOptIn(false)
        model.load()

        #expect(model.comparisonEntryPoint(for: session) == nil)
    }

    @Test("route comparison lists only this user's own sessions of the same activity type within the distance band")
    func routeComparisonListsOnlyMatchingOwnSessions() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(true)
        let sameRoute = makeCardioSession(activityType: .run, startedAt: Date(timeIntervalSince1970: 1_000), distanceMeters: 5_000)
        let sameRouteAgain = makeCardioSession(activityType: .run, startedAt: Date(timeIntervalSince1970: 2_000), distanceMeters: 5_100)
        let differentDistance = makeCardioSession(activityType: .run, startedAt: Date(timeIntervalSince1970: 3_000), distanceMeters: 12_000)
        let differentActivity = makeCardioSession(activityType: .cycle, startedAt: Date(timeIntervalSince1970: 4_000), distanceMeters: 5_050)
        for session in [sameRoute, sameRouteAgain, differentDistance, differentActivity] {
            try store.saveCardioSession(session)
        }

        let model = RouteComparisonModel(activityType: .run, referenceDistanceMeters: 5_000, store: store)
        model.loadMatches()

        let matchedIDs = Set(model.matches.map(\.id))
        #expect(matchedIDs.contains(sameRoute.id))
        #expect(matchedIDs.contains(sameRouteAgain.id))
        #expect(matchedIDs.contains(differentDistance.id) == false)
        #expect(matchedIDs.contains(differentActivity.id) == false)
    }

    @Test("route comparison produces no matches while opted out, even if matching sessions exist")
    func routeComparisonEmptyWhileOptedOut() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(false)
        let session = makeCardioSession(activityType: .run, startedAt: Date(timeIntervalSince1970: 1_000), distanceMeters: 5_000)
        try store.saveCardioSession(session)

        let model = RouteComparisonModel(activityType: .run, referenceDistanceMeters: 5_000, store: store)
        model.loadMatches()

        #expect(model.matches.isEmpty)
    }

    @Test("setting the opt-in on persists it and populates matches immediately")
    func settingOptInOnPersistsAndPopulates() throws {
        let store = try makeStore()
        try store.saveRouteComparisonOptIn(false)
        let session = makeCardioSession(activityType: .walk, startedAt: Date(timeIntervalSince1970: 1_000), distanceMeters: 3_000)
        try store.saveCardioSession(session)

        let model = RouteComparisonModel(activityType: .walk, referenceDistanceMeters: 3_000, store: store)
        model.loadMatches()
        #expect(model.matches.isEmpty)

        model.setOptIn(true)

        #expect(model.matches.contains { $0.id == session.id })
        #expect(try store.loadRouteComparisonOptIn())
    }
}
