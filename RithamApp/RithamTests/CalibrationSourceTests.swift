import CoreLocation
import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// D-02/D-04's calibration sources: none of these tests exercise real sensors or real location
// authorization -- every source under test accepts an injected clock, availability check, or
// authorization-status provider, so all of this runs deterministically in the Simulator per
// 01-RESEARCH.md Pitfall 4.
@Suite("CalibrationSourceTests", .serialized)
@MainActor
struct CalibrationSourceTests {

    init() {
        StepRegistry.reset()
    }

    private func makeStore() throws -> HealthDataStore {
        let schema = Schema([UserProfile.self, ConditionTagRecord.self, CalibrationBaselineRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return HealthDataStore(context: context)
    }

    // MARK: - Mode reporting

    @Test("each source reports the mode it claims")
    func eachSourceReportsItsOwnMode() {
        #expect(PedometerSession(isStepCountingAvailable: { true }).mode == .walk)
        #expect(StopwatchSession().mode == .walk)
        #expect(LiftSessionRecorder().mode == .lift)
    }

    // MARK: - PedometerSession availability

    @Test("PedometerSession reports unavailable rather than crashing when step counting is unavailable")
    func pedometerReportsUnavailableWithoutCrashing() {
        let session = PedometerSession(isStepCountingAvailable: { false })
        #expect(session.isAvailable == false)
        session.start()
        #expect(session.isAvailable == false)
    }

    @Test("PedometerSession reports available immediately when step counting is available")
    func pedometerReportsAvailableImmediately() {
        let session = PedometerSession(isStepCountingAvailable: { true })
        #expect(session.isAvailable == true)
    }

    // MARK: - StopwatchSession

    @Test("StopwatchSession accumulates elapsed time from an injected clock and reaches completion at exactly six hundred seconds")
    func stopwatchReachesCompletionAtSixHundredSeconds() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchSession(now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(599)
        #expect(CalibrationCompletion.evaluate(session.progress) == .incomplete)

        currentDate = currentDate.addingTimeInterval(1)
        #expect(CalibrationCompletion.evaluate(session.progress) == .complete)
    }

    @Test("pausing StopwatchSession records an interruption and zeroes the accumulation so it is no longer complete")
    func stopwatchPauseRecordsInterruptionAndZeroesAccumulation() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchSession(now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(600)
        #expect(CalibrationCompletion.evaluate(session.progress) == .complete)

        session.pause()

        guard case .walk(let walk) = session.progress else {
            Issue.record("expected .walk progress")
            return
        }
        #expect(walk.continuousDuration == 0)
        #expect(walk.wasInterrupted == true)
        #expect(CalibrationCompletion.evaluate(session.progress) == .incomplete)
    }

    @Test("stopping StopwatchSession freezes elapsed time without penalty, and resume continues additively from there")
    func stopwatchStopFreezesProgressAndResumeContinuesAdditively() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchSession(now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(300)
        session.stop()

        guard case .walk(let stopped) = session.progress else {
            Issue.record("expected .walk progress")
            return
        }
        #expect(stopped.continuousDuration == 300)
        #expect(stopped.wasInterrupted == false)
        #expect(session.isRunning == false)

        // Time passing while stopped must not advance the displayed duration.
        currentDate = currentDate.addingTimeInterval(120)
        guard case .walk(let stillStopped) = session.progress else {
            Issue.record("expected .walk progress")
            return
        }
        #expect(stillStopped.continuousDuration == 300)

        session.resume()
        currentDate = currentDate.addingTimeInterval(300)
        #expect(CalibrationCompletion.evaluate(session.progress) == .complete)
    }

    // MARK: - LiftSessionRecorder

    @Test("LiftSessionRecorder reaches completion at exactly three working sets across two exercises and not at three across one")
    func liftRecorderRequiresBothSetsAndExerciseSpread() {
        let singleExercise = LiftSessionRecorder()
        singleExercise.recordWorkingSet(exercise: "Squat")
        singleExercise.recordWorkingSet(exercise: "Squat")
        singleExercise.recordWorkingSet(exercise: "Squat")
        #expect(singleExercise.totalWorkingSets == 3)
        #expect(singleExercise.distinctExercises == 1)
        #expect(CalibrationCompletion.evaluate(singleExercise.progress) == .incomplete)

        let twoExercises = LiftSessionRecorder()
        twoExercises.recordWorkingSet(exercise: "Squat")
        twoExercises.recordWorkingSet(exercise: "Squat")
        twoExercises.recordWorkingSet(exercise: "Row")
        #expect(CalibrationCompletion.evaluate(twoExercises.progress) == .complete)
    }

    // MARK: - LocationEnrichment

    @Test("LocationEnrichment stays inert and publishes nothing for notDetermined, denied, and restricted")
    func locationEnrichmentStaysInertWhenNotAuthorized() {
        for status: CLAuthorizationStatus in [.notDetermined, .denied, .restricted] {
            let enrichment = LocationEnrichment(authorizationStatusProvider: { status })
            enrichment.startIfAlreadyAuthorized()
            #expect(enrichment.isEnriching == false)
            #expect(enrichment.enrichedPaceSecondsPerKm == nil)
            #expect(enrichment.enrichedDistanceMeters == nil)
        }
    }

    @Test("LocationEnrichment begins enriching for authorizedWhenInUse and authorizedAlways")
    func locationEnrichmentBeginsWhenAuthorized() {
        for status: CLAuthorizationStatus in [.authorizedWhenInUse, .authorizedAlways] {
            let enrichment = LocationEnrichment(authorizationStatusProvider: { status })
            enrichment.startIfAlreadyAuthorized()
            #expect(enrichment.isEnriching == true)
        }
    }

    @Test("a walk session reaches completion identically whether enrichment is active or inert")
    func walkCompletionIdenticalRegardlessOfEnrichment() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchSession(now: { currentDate })
        session.start()
        currentDate = currentDate.addingTimeInterval(600)

        let activeEnrichment = LocationEnrichment(authorizationStatusProvider: { .authorizedWhenInUse })
        activeEnrichment.startIfAlreadyAuthorized()
        let inertEnrichment = LocationEnrichment(authorizationStatusProvider: { .notDetermined })
        inertEnrichment.startIfAlreadyAuthorized()

        // GPS is enrichment, not a gate: completion is decided from `progress` alone, which
        // neither LocationEnrichment instance ever touches.
        #expect(activeEnrichment.isEnriching == true)
        #expect(inertEnrichment.isEnriching == false)
        #expect(CalibrationCompletion.evaluate(session.progress) == .complete)
    }

    // MARK: - Registration (Task 3)

    @Test("CalibrationRegistration.registerAll resolves a real view for each of the three calibration steps and shrinks unregisteredSteps by exactly those three")
    func registerAllResolvesCalibrationSteps() {
        let steps: [OnboardingStep] = [.calibrationIntro, .calibrationSession, .calibrationComplete]
        let before = Set(StepRegistry.unregisteredSteps)
        for step in steps { #expect(before.contains(step)) }

        CalibrationRegistration.registerAll()

        let after = Set(StepRegistry.unregisteredSteps)
        for step in steps { #expect(!after.contains(step)) }
        #expect(before.subtracting(after) == Set(steps))

        let flow = OnboardingFlow()
        for step in steps {
            _ = StepRegistry.view(for: step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - Routing (Task 3)

    @Test("router routes past calibrationSession and calibrationComplete when calibration was skipped, so skipping blocks nothing")
    func routerRoutesPastSessionAndCompleteWhenSkipped() {
        var answers = OnboardingAnswers()
        answers.calibrationOutcome = .skipped

        let next = OnboardingRouter.nextStep(after: .calibrationIntro, answers: answers)
        #expect(next != .calibrationSession)
        #expect(next != .calibrationComplete)
        #expect(next == OnboardingRouter.nextStep(after: .calibrationComplete, answers: answers))
    }

    @Test("router passes through calibrationSession then calibrationComplete when calibration was not skipped")
    func routerPassesThroughSessionAndCompleteWhenNotSkipped() {
        var answers = OnboardingAnswers()
        answers.calibrationOutcome = .notStarted

        #expect(OnboardingRouter.nextStep(after: .calibrationIntro, answers: answers) == .calibrationSession)
        #expect(OnboardingRouter.nextStep(after: .calibrationSession, answers: answers) == .calibrationComplete)

        answers.calibrationOutcome = .completed(CalibrationBaseline.provisional(establishedAt: Date()))
        #expect(OnboardingRouter.nextStep(after: .calibrationIntro, answers: answers) == .calibrationSession)
        #expect(OnboardingRouter.nextStep(after: .calibrationSession, answers: answers) == .calibrationComplete)
    }

    // MARK: - Skip yields a real provisional baseline, never nil (Task 3)

    @Test("after a skip, the persisted baseline round-trips through HealthDataStore with source .provisional, not nil")
    func skipYieldsProvisionalBaselineNotNil() throws {
        let store = try makeStore()
        let knownDate = Date(timeIntervalSince1970: 1_000_000)

        try store.saveCalibrationBaseline(CalibrationBaseline.provisional(establishedAt: knownDate))

        let loaded = try store.loadCalibrationBaseline()
        #expect(loaded != nil)
        #expect(loaded?.source == .provisional)
        #expect(loaded?.establishedAt == knownDate)
    }
}
