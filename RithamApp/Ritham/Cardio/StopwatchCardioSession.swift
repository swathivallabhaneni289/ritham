import Foundation
import SwiftUI
import RithamCore

// CARDIO-01's manual fallback and the zero-permission path PROJECT.md's monetization boundary
// requires: the app must be fully functional phone-only, so this timer imports neither
// CoreLocation nor CoreMotion and is never blocked by a permission decision of any kind. Unlike
// `GPSTrackingSession` (plan 02-09, Task 2) this session has nothing to authorize -- it is always
// available, on every device, with no prompt.
//
// This is a peer of Phase 1's `StopwatchSession.swift`, not a reuse of it (02-RESEARCH.md
// Pattern 3): `CalibrationSessionSource` answers a single yes/no completion question for two
// fixed modes and is the wrong shape for a live, multi-activity-type cardio session with its own
// `CardioSession`/`CardioProgress` domain. The class *shape* -- `@Observable`, `@unchecked
// Sendable`, `nonisolated(unsafe)` storage, an injected clock, start/pause/resume/stop plus a
// private live-progress method that adds elapsed time on top of recorded time -- is copied
// directly from that file.
//
// `@unchecked Sendable` is the honest annotation here, not a shortcut: every mutation happens
// through `start`/`pause`/`resume`/`stop`, always called from the main-actor session view, so
// access is serialized in practice even though the compiler cannot prove it statically for a
// plain (non-actor) reference type.
@Observable
final class StopwatchCardioSession: @unchecked Sendable {
    let activityType: ActivityType

    /// The interruption-aware progress as of the most recent pause. Live elapsed time since the
    /// current unbroken start is added on top of this when computing `progress`.
    private nonisolated(unsafe) var recorded = CardioProgress()
    private nonisolated(unsafe) var currentStartedAt: Date?
    private nonisolated(unsafe) var sessionStartedAt: Date?

    private let now: () -> Date

    init(activityType: ActivityType, now: @escaping () -> Date = Date.init) {
        self.activityType = activityType
        self.now = now
    }

    var isRunning: Bool { currentStartedAt != nil }

    var progress: CardioProgress { liveProgress() }

    func start() {
        let startDate = now()
        currentStartedAt = startDate
        if sessionStartedAt == nil { sessionStartedAt = startDate }
    }

    /// Pausing breaks continuity, matching `StopwatchSession.pause()`'s reasoning: it zeroes the
    /// accumulated continuous-duration clock via `CardioProgress.recordInterruption()` and marks
    /// the progress interrupted, while leaving any already-recorded distance/elevation untouched.
    func pause() {
        recorded = liveProgress()
        recorded.recordInterruption()
        currentStartedAt = nil
    }

    func resume() {
        currentStartedAt = now()
    }

    /// Freezes the displayed elapsed time without penalty -- not an interruption, so
    /// `wasInterrupted` is left exactly as already recorded.
    func stop() {
        recorded = liveProgress()
        currentStartedAt = nil
    }

    /// Produces the finished `CardioSession`. The capture source is always `.manualStopwatch`,
    /// so `CardioCaptureSource.isSensorVerified` reports `false` for every session this type
    /// produces.
    func finish() -> CardioSession {
        let finalProgress = liveProgress()
        let endedAt = now()
        return CardioSession(
            activityType: activityType,
            source: .manualStopwatch,
            startedAt: sessionStartedAt ?? endedAt,
            endedAt: endedAt,
            progress: finalProgress
        )
    }

    private func liveProgress() -> CardioProgress {
        guard let currentStartedAt else { return recorded }
        let elapsed = now().timeIntervalSince(currentStartedAt)
        var progress = recorded
        progress.record(distanceMeters: 0, elevationGainMeters: 0, duration: elapsed)
        return progress
    }
}
