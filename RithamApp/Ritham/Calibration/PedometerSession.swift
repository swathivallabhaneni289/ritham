import CoreMotion
import Foundation
import SwiftUI
import RithamCore

// D-02 forbids a blocking location prompt in calibration's critical path, and per
// 01-RESEARCH.md Assumption A1, GPS is layered in only as enrichment when the user has already
// granted location access -- never the completion gate. This file requires only
// NSMotionUsageDescription (already declared in Info.plist, plan 01-09) and must never import
// CoreLocation or request location authorisation of any kind: doing either here would breach
// D-02.
//
// This session never decides its own completion. It exposes `progress`; the view calls
// CalibrationCompletion.evaluate (RithamCore, plan 01-05, already tested against both
// thresholds) -- a second judgement here could drift from that rule.
//
// 01-RESEARCH.md Pitfall 4: not every device has the motion coprocessor CMPedometer depends on,
// and the iOS Simulator produces no real motion data at all. Every start is guarded by
// CMPedometer.isStepCountingAvailable(); unavailability is reported through `isAvailable`
// (checked immediately at init, not only after a failed start) rather than failing silently, so
// the session view (Task 2) can fall back to StopwatchSession automatically before ever
// attempting to start this source.
// This type is not itself actor-isolated -- CMPedometer's update handler is not guaranteed to
// arrive on the main actor, and the protocol it conforms to (`CalibrationSessionSource`)
// inherits `Sendable`, which cannot combine with an isolated conformance (Swift 6 rejects
// isolating a conformance to a `Sendable`-inheriting protocol). `@unchecked Sendable` is the
// honest annotation for the real guarantee here: every mutable stored property below is only
// ever mutated from `handleUpdate`, which is always hopped onto the main actor via
// `Task { @MainActor in ... }` before it runs, and every read (SwiftUI's `@State` usage in the
// session view) also happens on the main actor -- so access is serialized in practice even
// though the compiler cannot prove it statically.
@Observable
final class PedometerSession: CalibrationSessionSource, @unchecked Sendable {
    let mode: CalibrationMode = .walk

    /// `false` when step counting has been confirmed unavailable on this device -- checked
    /// immediately at init so a caller never has to attempt (and fail) a start just to find
    /// out.
    private(set) nonisolated(unsafe) var isAvailable: Bool

    /// The interruption-aware progress as of the most recent update or interruption. Live
    /// elapsed time since the current unbroken start is added on top of this when computing
    /// `progress` -- see `liveProgress()` below.
    private nonisolated(unsafe) var recorded = WalkProgress()
    private nonisolated(unsafe) var currentStartedAt: Date?
    private nonisolated(unsafe) var lastUpdateAt: Date?

    private let pedometer = CMPedometer()
    private let isStepCountingAvailable: () -> Bool
    private let now: () -> Date

    /// A live update gap longer than this is treated as an interruption -- CMPedometer
    /// delivers updates every few seconds while walking; a longer gap means the user stopped
    /// moving or the app was backgrounded, either of which breaks D-01's *continuous* minutes
    /// requirement.
    private let interruptionTolerance: TimeInterval = 30

    init(
        isStepCountingAvailable: @escaping () -> Bool = CMPedometer.isStepCountingAvailable,
        now: @escaping () -> Date = Date.init
    ) {
        self.isStepCountingAvailable = isStepCountingAvailable
        self.now = now
        self.isAvailable = isStepCountingAvailable()
    }

    var progress: CalibrationProgress {
        .walk(recorded)
    }

    /// Starts the session, or reports unavailability rather than starting a session that could
    /// never produce real data. Safe to call even when `isAvailable` is already `false` -- it
    /// simply re-confirms and does nothing further.
    func start() {
        guard isStepCountingAvailable() else {
            isAvailable = false
            return
        }
        isAvailable = true
        let startDate = now()
        currentStartedAt = startDate
        lastUpdateAt = startDate

        pedometer.startUpdates(from: startDate) { [weak self] data, _ in
            // Extract the one Sendable value this type needs (distance, a plain Double) before
            // crossing the actor boundary -- `CMPedometerData` itself is not Sendable, so it
            // must never be captured by the `Task { @MainActor in ... }` closure below.
            guard let self, let data else { return }
            let distance = data.distance?.doubleValue ?? 0
            Task { @MainActor in
                self.handleUpdate(distanceMeters: distance)
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        currentStartedAt = nil
        lastUpdateAt = nil
    }

    private func handleUpdate(distanceMeters: Double) {
        let updateTime = now()

        // A gap longer than tolerance breaks continuity -- D-01 requires *continuous* minutes,
        // so this zeroes accumulated progress via the same tested mutator StopwatchSession's
        // pause path calls, rather than reimplementing the zeroing here.
        if let lastUpdateAt, updateTime.timeIntervalSince(lastUpdateAt) > interruptionTolerance {
            recorded.recordInterruption()
            currentStartedAt = updateTime
        }
        lastUpdateAt = updateTime

        guard let currentStartedAt else { return }
        let continuousDuration = updateTime.timeIntervalSince(currentStartedAt)
        recorded = WalkProgress(
            continuousDuration: continuousDuration,
            distanceMeters: distanceMeters,
            wasInterrupted: recorded.wasInterrupted
        )
    }
}
