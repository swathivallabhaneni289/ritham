import Foundation
import Testing
import RithamCore
@testable import Ritham

// D-02/D-04's cardio capture adapters (02-09): none of these tests exercise real sensors --
// `StopwatchCardioSessionTests` drives an injected clock exactly like Phase 1's
// `CalibrationSourceTests` does for `StopwatchSession`, and `MotionActivityDetectorTests` drives
// the detector's pure confidence-mapping/candidate-threshold logic directly against synthetic
// inputs, since the Simulator cannot produce real `CMMotionActivityManager` classification
// (02-RESEARCH.md Pitfall 4).
@Suite("StopwatchCardioSessionTests")
struct StopwatchCardioSessionTests {

    @Test("starting then advancing the clock by 60 seconds reports 60 seconds of continuous duration")
    func startingThenAdvancingReportsContinuousDuration() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .run, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(60)

        #expect(session.progress.continuousDuration == 60)
    }

    @Test("pausing freezes the reported duration; resuming continues accumulating from the frozen value")
    func pausingFreezesAndResumingContinuesAccumulating() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .walk, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(30)
        session.pause()

        // Pausing zeroes the continuous-duration clock (an interruption), matching
        // `StopwatchSession.pause()`'s reasoning -- time passing while paused must not advance
        // the displayed duration.
        currentDate = currentDate.addingTimeInterval(45)
        #expect(session.progress.continuousDuration == 0)

        session.resume()
        currentDate = currentDate.addingTimeInterval(20)
        #expect(session.progress.continuousDuration == 20)
    }

    @Test("pausing marks the progress as interrupted")
    func pausingMarksInterrupted() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .run, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(10)
        #expect(session.progress.wasInterrupted == false)

        session.pause()
        #expect(session.progress.wasInterrupted == true)
    }

    @Test("stopping produces a CardioSession whose capture source reports as not sensor-verified")
    func stoppingProducesManuallySourcedSession() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .run, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(120)
        session.stop()

        let finished = session.finish()
        #expect(finished.source == .manualStopwatch)
        #expect(finished.source.isSensorVerified == false)
    }

    @Test("the produced session carries the activity type it was constructed with")
    func producedSessionCarriesConstructedActivityType() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .cycle, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(60)
        session.stop()

        #expect(session.finish().activityType == .cycle)
    }

    @Test("stopping freezes elapsed time without penalty, and resume continues additively from there")
    func stoppingFreezesProgressAndResumeContinuesAdditively() {
        var currentDate = Date(timeIntervalSince1970: 0)
        let session = StopwatchCardioSession(activityType: .hike, now: { currentDate })

        session.start()
        currentDate = currentDate.addingTimeInterval(300)
        session.stop()

        #expect(session.progress.continuousDuration == 300)
        #expect(session.progress.wasInterrupted == false)
        #expect(session.isRunning == false)

        currentDate = currentDate.addingTimeInterval(120)
        #expect(session.progress.continuousDuration == 300)

        session.resume()
        currentDate = currentDate.addingTimeInterval(60)
        #expect(session.progress.continuousDuration == 360)
    }
}
