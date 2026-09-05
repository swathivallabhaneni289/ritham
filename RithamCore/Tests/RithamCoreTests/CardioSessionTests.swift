import Foundation
import Testing
@testable import RithamCore

@Suite("CardioSessionTests")
struct CardioSessionTests {

    // MARK: - ActivityType

    @Test("the six known activity types round-trip through their raw value")
    func knownActivityTypesRoundTripThroughRawValue() {
        for activity in ActivityType.known {
            #expect(ActivityType(rawValue: activity.rawValue) == activity)
        }
    }

    @Test("an activity type outside known can be constructed without a source edit")
    func unknownActivityTypeIsUsableButNotInKnown() {
        let rowing = ActivityType(rawValue: "rowing")

        #expect(rowing.rawValue == "rowing")
        #expect(!ActivityType.known.contains(rowing))
        #expect(rowing.displayName == "Rowing")
    }

    @Test("known() lists exactly the six documented activities in display order")
    func knownListsExactlySixActivitiesInOrder() {
        #expect(ActivityType.known == [.run, .walk, .cycle, .hike, .swim, .elliptical])
    }

    // MARK: - CardioCaptureSource

    @Test("manualStopwatch is not sensor-verified")
    func manualStopwatchIsNotSensorVerified() {
        #expect(CardioCaptureSource.manualStopwatch.isSensorVerified == false)
    }

    @Test("gps and autoDetected are sensor-verified")
    func gpsAndAutoDetectedAreSensorVerified() {
        #expect(CardioCaptureSource.gps.isSensorVerified == true)
        #expect(CardioCaptureSource.autoDetected.isSensorVerified == true)
    }

    // MARK: - CardioProgress.record

    @Test("record accumulates distance, elevation gain, and continuous duration across calls")
    func recordAccumulatesAcrossCalls() {
        var progress = CardioProgress()

        progress.record(distanceMeters: 100, elevationGainMeters: 5, duration: 60)
        progress.record(distanceMeters: 50, elevationGainMeters: 2, duration: 30)

        #expect(progress.distanceMeters == 150)
        #expect(progress.elevationGainMeters == 7)
        #expect(progress.continuousDuration == 90)
    }

    @Test("recordInterruption zeroes continuous duration, sets wasInterrupted, and preserves distance")
    func recordInterruptionZeroesContinuousDurationOnly() {
        var progress = CardioProgress()
        progress.record(distanceMeters: 100, elevationGainMeters: 5, duration: 60)

        progress.recordInterruption()

        #expect(progress.continuousDuration == 0)
        #expect(progress.wasInterrupted == true)
        #expect(progress.distanceMeters == 100)
    }

    // MARK: - CardioQualification

    @Test("CardioQualification.evaluate is incomplete one second short of the shared qualifying bar")
    func evaluateIsIncompleteOneSecondShort() {
        let progress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration - 1)
        #expect(CardioQualification.evaluate(progress) == .incomplete)
    }

    @Test("CardioQualification.evaluate is complete at exactly the shared qualifying bar")
    func evaluateIsCompleteAtExactlyTheBar() {
        let progress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration)
        #expect(CardioQualification.evaluate(progress) == .complete)
    }

    @Test("CardioQualification.evaluate is complete beyond the shared qualifying bar")
    func evaluateIsCompleteBeyondTheBar() {
        let progress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration + 1)
        #expect(CardioQualification.evaluate(progress) == .complete)
    }

    // MARK: - CardioSession construction

    @Test("a CardioSession round-trips its stored properties")
    func cardioSessionRoundTripsStoredProperties() {
        let id = UUID()
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 600)
        var progress = CardioProgress()
        progress.record(distanceMeters: 1000, elevationGainMeters: 10, duration: 600)

        let session = CardioSession(
            id: id,
            activityType: .run,
            source: .gps,
            startedAt: start,
            endedAt: end,
            progress: progress,
            notes: "felt good"
        )

        #expect(session.id == id)
        #expect(session.activityType == .run)
        #expect(session.source == .gps)
        #expect(session.startedAt == start)
        #expect(session.endedAt == end)
        #expect(session.progress == progress)
        #expect(session.notes == "felt good")
    }
}
