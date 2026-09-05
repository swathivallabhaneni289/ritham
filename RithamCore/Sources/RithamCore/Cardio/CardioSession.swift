import Foundation

// RithamCore cannot import CoreLocation or CoreMotion — a cardio session's structure and its
// qualification decision therefore never depend on sensor availability or location
// authorization. The app layer's CoreLocation/CoreMotion adapters (plan 02-09) and the
// SwiftData persistence layer (plan 02-08) both target this Foundation-only domain.
//
// Per D-02 this `WorkoutSession`-family domain is a deliberate peer of, not a modification to,
// Phase 1's `CalibrationSession.swift` — Phase 1's calibration flow and this cardio-tracking
// flow answer different questions (a one-time "is this a real session?" gate vs. an ongoing,
// multi-metric tracked activity) and are kept structurally separate. The one thing they share
// is the qualifying-session bar, referenced below from `CalibrationThreshold` rather than
// restated as a literal number.

/// How a cardio session's activity was captured.
///
/// `isSensorVerified` is `false` only for `manualStopwatch` — this is the manually-entered-vs-
/// sensor-verified distinction ROADMAP Phase 3's Momentum feature later depends on, recorded now
/// so Phase 3 does not have to backfill it onto already-recorded sessions.
public enum CardioCaptureSource: String, CaseIterable, Sendable, Equatable, Codable {
    case gps
    case manualStopwatch
    case autoDetected

    public var isSensorVerified: Bool {
        self != .manualStopwatch
    }
}

/// One completed kilometre (or other `CardioTrackAccumulator.splitDistanceMeters` unit) of a
/// tracked cardio session.
public struct CardioSplit: Sendable, Equatable {
    public let index: Int
    public let distanceMeters: Double
    public let duration: TimeInterval
    public let averageSecondsPerKm: Double
    public let elevationGainMeters: Double

    public init(
        index: Int,
        distanceMeters: Double,
        duration: TimeInterval,
        averageSecondsPerKm: Double,
        elevationGainMeters: Double
    ) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.duration = duration
        self.averageSecondsPerKm = averageSecondsPerKm
        self.elevationGainMeters = elevationGainMeters
    }
}

/// How much a signal (horizontal position or elevation) can be trusted.
///
/// CARDIO-02 requires horizontal-position confidence and elevation confidence be tracked as two
/// separate values, never blended into one — iPhone vertical/altitude accuracy is materially
/// noisier than horizontal GPS accuracy, so a session can have high confidence in its distance
/// while having low confidence in its elevation gain (and therefore its grade-adjusted pace; see
/// `GradeAdjustedPace`).
public enum SignalConfidence: Int, CaseIterable, Comparable, Sendable, Equatable, Codable {
    case unavailable
    case low
    case medium
    case high

    public static func < (lhs: SignalConfidence, rhs: SignalConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A cardio session's live, in-progress measurement.
///
/// Copies `CalibrationSession.swift`'s `WalkProgress` discipline: every stored property is
/// `private(set)`, and every mutation goes through an explicit named method rather than a public
/// setter, so a caller can never construct an inconsistent progress value (e.g. splits that
/// don't sum to `distanceMeters`) by poking at individual fields.
public struct CardioProgress: Sendable, Equatable {
    public private(set) var continuousDuration: TimeInterval
    public private(set) var distanceMeters: Double
    public private(set) var elevationGainMeters: Double
    public private(set) var splits: [CardioSplit]
    public private(set) var horizontalConfidence: SignalConfidence
    public private(set) var elevationConfidence: SignalConfidence
    public private(set) var wasInterrupted: Bool

    public init(
        continuousDuration: TimeInterval = 0,
        distanceMeters: Double = 0,
        elevationGainMeters: Double = 0,
        splits: [CardioSplit] = [],
        horizontalConfidence: SignalConfidence = .unavailable,
        elevationConfidence: SignalConfidence = .unavailable,
        wasInterrupted: Bool = false
    ) {
        self.continuousDuration = continuousDuration
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.splits = splits
        self.horizontalConfidence = horizontalConfidence
        self.elevationConfidence = elevationConfidence
        self.wasInterrupted = wasInterrupted
    }

    /// Accumulates a delta of distance, elevation gain, and continuous duration onto this
    /// progress. Called once per accepted sample by `CardioTrackAccumulator`, or directly by a
    /// manual-stopwatch source with no distance sensor (passing `0` for distance/elevation).
    public mutating func record(distanceMeters: Double, elevationGainMeters: Double, duration: TimeInterval) {
        self.distanceMeters += distanceMeters
        self.elevationGainMeters += elevationGainMeters
        self.continuousDuration += duration
    }

    /// Appends a completed split. Splits are append-only from this progress's point of view —
    /// `CardioTrackAccumulator` decides when a split boundary has been crossed.
    public mutating func appendSplit(_ split: CardioSplit) {
        splits.append(split)
    }

    /// Updates the two independent signal-confidence readings. Horizontal and elevation
    /// confidence are set together here because a single location sample yields both readings
    /// at once, but they remain two independent stored values.
    public mutating func updateConfidence(horizontal: SignalConfidence, elevation: SignalConfidence) {
        horizontalConfidence = horizontal
        elevationConfidence = elevation
    }

    /// Zeroes the continuous-duration clock that `CardioQualification.evaluate` reads, and
    /// records that an interruption occurred. Distance, elevation gain, and splits already
    /// recorded are real ground covered and are deliberately NOT zeroed — only the *continuous*
    /// clock used for the qualifying-session bar resets, matching `WalkProgress.recordInterruption`'s
    /// reasoning that the sensor/stopwatch source (not this type) is the one that knows when
    /// movement stopped.
    public mutating func recordInterruption() {
        continuousDuration = 0
        wasInterrupted = true
    }
}

/// A single recorded cardio session.
public struct CardioSession: Sendable, Equatable {
    public let id: UUID
    public let activityType: ActivityType
    public let source: CardioCaptureSource
    public let startedAt: Date
    public let endedAt: Date
    public let progress: CardioProgress
    public let notes: String?

    public init(
        id: UUID = UUID(),
        activityType: ActivityType,
        source: CardioCaptureSource,
        startedAt: Date,
        endedAt: Date,
        progress: CardioProgress,
        notes: String? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.source = source
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.progress = progress
        self.notes = notes
    }
}

/// Whether a cardio session has met the qualifying-session bar.
///
/// Per D-02, this domain is a deliberate peer of Phase 1's `CalibrationSession`/
/// `CalibrationCompletion` — not a modification to it — while sharing that domain's
/// qualifying-duration constant so the bar itself never drifts between the two features.
public enum CardioQualification: Sendable, Equatable {
    case incomplete
    case complete

    /// Evaluates a cardio session's progress against `CalibrationThreshold.qualifyingWalkDuration`
    /// — the same continuous-duration bar Phase 1's calibration walk uses (D-02).
    public static func evaluate(_ progress: CardioProgress) -> CardioQualification {
        progress.continuousDuration >= CalibrationThreshold.qualifyingWalkDuration ? .complete : .incomplete
    }
}
