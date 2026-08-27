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
}
