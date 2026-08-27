import Foundation
import SwiftUI
import RithamCore

// D-02's manual fallback: this session works standalone with no sensor and no permission of
// any kind -- CMPedometer, CoreMotion, and CoreLocation are never imported here. It is also the
// only calibration path that can be genuinely exercised in the iOS Simulator (01-RESEARCH.md
// Pitfall 4), since the Simulator produces no real motion data for PedometerSession to consume.
//
// This session never decides its own completion -- it exposes `progress`; the view calls
// CalibrationCompletion.evaluate (RithamCore, plan 01-05) exactly like PedometerSession does.
// Not itself actor-isolated -- see PedometerSession.swift's header comment for why an isolated
// conformance cannot combine with `CalibrationSessionSource`'s inherited `Sendable` requirement.
// `@unchecked Sendable` is the honest annotation: every mutation happens through `start`/
// `pause`/`resume`, always called from the main-actor session view, and every read goes through
// the same main-actor view -- access is serialized in practice even though the compiler cannot
// prove it statically for a plain (non-actor) reference type.
@Observable
final class StopwatchSession: CalibrationSessionSource, @unchecked Sendable {
    let mode: CalibrationMode = .walk

    /// The interruption-aware progress as of the most recent pause. Live elapsed time since the
    /// current unbroken start is added on top of this when computing `progress`.
    private nonisolated(unsafe) var recorded = WalkProgress()
    private nonisolated(unsafe) var currentStartedAt: Date?

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var isRunning: Bool { currentStartedAt != nil }

    var progress: CalibrationProgress {
        .walk(liveProgress())
    }

    func start() {
        currentStartedAt = now()
    }

    /// Pausing breaks continuity -- D-01 requires *continuous* minutes, so a pause zeroes the
    /// accumulated duration via WalkProgress.recordInterruption(), the same already-tested
    /// mutator core provides, rather than reimplementing that zeroing logic here.
    func pause() {
        recorded = liveProgress()
        recorded.recordInterruption()
        currentStartedAt = nil
    }

    func resume() {
        currentStartedAt = now()
    }

    private func liveProgress() -> WalkProgress {
        guard let currentStartedAt else { return recorded }
        let elapsed = now().timeIntervalSince(currentStartedAt)
        return WalkProgress(
            continuousDuration: recorded.continuousDuration + elapsed,
            distanceMeters: recorded.distanceMeters,
            wasInterrupted: recorded.wasInterrupted
        )
    }
}
