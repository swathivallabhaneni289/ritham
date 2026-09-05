import CoreMotion
import Foundation
import SwiftUI
import RithamCore

// This wraps `CMMotionActivityManager`, a distinct CoreMotion API from Phase 1's
// `PedometerSession` (`CMPedometer`): `CMPedometer` reports step count/distance for walking
// specifically, while `CMMotionActivityManager` classifies *which* activity is happening
// (walking, running, stationary, automotive, cycling) with a `.low`/`.medium`/`.high` confidence
// level that ramps up over roughly 5-15 seconds of sustained activity. The duplication with
// `PedometerSession` is deliberate, not accidental (02-RESEARCH.md Pattern 3) -- these are two
// different questions answered by two different framework classes.
//
// Per CROSSGEN-02's passive-first-capture decision (02-CONTEXT.md), this type only ever offers a
// detection candidate -- it exposes no method that creates, saves, or starts a session. The only
// way a detection becomes a logged session is a user confirming the prompt plan 02-10's view
// presents; there is no silent background auto-logging path in this version. That absence is the
// enforcement of the decision, not a convention this type merely documents.
//
// Requires only `NSMotionUsageDescription`, already declared in `Info.plist` and reworded in
// Task 2 to cover this use -- no new usage-description key is needed.
//
// Not itself actor-isolated, matching `PedometerSession`'s reasoning: `CMMotionActivityManager`'s
// update handler is not guaranteed to arrive on the main actor, and `@unchecked Sendable` is the
// honest annotation for the real guarantee here -- every mutable stored property is only ever
// mutated from `handleUpdate`, always hopped onto the main actor via `Task { @MainActor in ... }`
// before it runs, and every read (SwiftUI's usage of this `@Observable` type) also happens on the
// main actor.
@Observable
final class MotionActivityDetector: @unchecked Sendable {
    /// `false` when activity classification has been confirmed unavailable on this device --
    /// checked immediately at init, and re-checked on `startObserving()`, so a device without
    /// the capability degrades to manual capture rather than appearing broken.
    private(set) nonisolated(unsafe) var isAvailable: Bool

    /// The most recent detection candidate offered, or `nil` when nothing currently qualifies.
    /// Publishing this value is the only effect this type has -- nothing here writes a session.
    private(set) nonisolated(unsafe) var detectionCandidate: MotionDetectionCandidate?

    private let activityManager = CMMotionActivityManager()
    private let isActivityAvailable: () -> Bool
    private let queue = OperationQueue()

    init(isActivityAvailable: @escaping () -> Bool = CMMotionActivityManager.isActivityAvailable) {
        self.isActivityAvailable = isActivityAvailable
        self.isAvailable = isActivityAvailable()
    }

    /// Starts activity classification updates. The caller (plan 02-10's session view) is
    /// responsible for calling this only while the app is foregrounded and calling
    /// `stopObserving()` on backgrounding, so no detection stream runs behind the user's back.
    func startObserving() {
        guard isActivityAvailable() else {
            isAvailable = false
            return
        }
        isAvailable = true
        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            let walking = activity.walking
            let running = activity.running
            let confidence = activity.confidence
            let timestamp = activity.startDate
            Task { @MainActor in
                self.handleUpdate(walking: walking, running: running, confidence: confidence, timestamp: timestamp)
            }
        }
    }

    func stopObserving() {
        activityManager.stopActivityUpdates()
        detectionCandidate = nil
    }

    private func handleUpdate(walking: Bool, running: Bool, confidence: CMMotionActivityConfidence, timestamp: Date) {
        detectionCandidate = Self.makeCandidate(
            walking: walking,
            running: running,
            confidence: confidence,
            timestamp: timestamp
        )
    }

    /// Pure mapping from CoreMotion's raw classification signals to a `MotionDetectionCandidate`,
    /// kept separate from the framework callback above so it can be exercised with synthetic
    /// inputs -- the Simulator produces no real `CMMotionActivityManager` classification
    /// (02-RESEARCH.md Pitfall 4). Returns `nil` when neither walking nor running is reported, or
    /// when confidence is below medium -- the low-confidence ramp-up window must not produce a
    /// stream of spurious prompts. When both walking and running are reported, running wins:
    /// it is the more specific, higher-intensity classification of the two.
    static func makeCandidate(
        walking: Bool,
        running: Bool,
        confidence: CMMotionActivityConfidence,
        timestamp: Date
    ) -> MotionDetectionCandidate? {
        let signalConfidence = mapConfidence(confidence)
        guard signalConfidence >= .medium else { return nil }

        if running {
            return MotionDetectionCandidate(activityType: .run, confidence: signalConfidence, detectedAt: timestamp)
        }
        if walking {
            return MotionDetectionCandidate(activityType: .walk, confidence: signalConfidence, detectedAt: timestamp)
        }
        return nil
    }

    /// Maps CoreMotion's own three-level confidence enum onto RithamCore's `SignalConfidence` --
    /// a distinct signal from GPS accuracy confidence (`CardioTrackAccumulator`'s), specific to
    /// auto-detect classification quality.
    static func mapConfidence(_ confidence: CMMotionActivityConfidence) -> SignalConfidence {
        switch confidence {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        @unknown default: return .unavailable
        }
    }
}

/// A single motion-classification candidate offered to the user for confirmation. Constructing
/// this value never creates, saves, or starts a session -- see `MotionActivityDetector`'s header
/// comment.
struct MotionDetectionCandidate: Sendable, Equatable {
    let activityType: ActivityType
    let confidence: SignalConfidence
    let detectedAt: Date
}
