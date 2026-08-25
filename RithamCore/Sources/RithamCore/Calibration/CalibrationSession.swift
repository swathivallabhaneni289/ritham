import Foundation

// ONBOARD-01's "real session" is defined once, here, and nowhere else. This file is
// Foundation-only by construction: RithamCore cannot import CoreMotion or CoreLocation, so
// calibration completion can never be gated on sensor availability or location authorization.
// The CoreMotion pedometer adapter and the manual stopwatch (plan 01-15) both produce a
// `CalibrationProgress` value and hand it to `CalibrationCompletion.evaluate` — this is the one
// decision rule both paths share, per D-02 and 01-RESEARCH.md Assumption A1.

/// The two calibration session modes a user can choose between at onboarding.
public enum CalibrationMode: String, CaseIterable, Sendable {
    case walk
    case lift
}

/// Named calibration completion thresholds.
///
/// These numbers appear exactly once in the codebase. D-01 was corrected on 2026-08-23 after
/// 01-RESEARCH.md's Conflict 1 found the originally inferred lift threshold (2 sets across 1
/// exercise) did not match MOMENTUM-01. The locked value below now matches MOMENTUM-01's wording
/// verbatim: "a qualifying lift session (at least 3 working sets across 2+ exercises)". Phase 3's
/// Momentum qualifying-session bar should reference these same constants rather than restating
/// the numbers — changing either value here silently desynchronises calibration from that bar.
public enum CalibrationThreshold {
    /// Ten minutes, in seconds. A qualifying walk session must sustain this continuously.
    public static let qualifyingWalkDuration: TimeInterval = 600

    /// A qualifying lift session must record at least this many total working sets.
    public static let qualifyingWorkingSets: Int = 3

    /// A qualifying lift session must spread its working sets across at least this many
    /// distinct exercises.
    public static let qualifyingExercises: Int = 2
}

/// In-progress measurement of a walk-mode calibration session.
///
/// D-01 requires *continuous* minutes, so a paused or broken session must not silently keep
/// accumulating toward the bar. Callers reset `continuousDuration` on interruption via
/// `recordInterruption()` rather than this type inferring interruption from elapsed wall-clock
/// time — the sensor or stopwatch adapter is the one that knows when movement stopped.
public struct WalkProgress: Sendable, Equatable {
    public private(set) var continuousDuration: TimeInterval
    public private(set) var wasInterrupted: Bool

    public init(continuousDuration: TimeInterval = 0, wasInterrupted: Bool = false) {
        self.continuousDuration = continuousDuration
        self.wasInterrupted = wasInterrupted
    }

    /// Zeroes the accumulated continuous duration and records that an interruption occurred.
    ///
    /// The `wasInterrupted` flag is retained (not cleared on subsequent progress) so the
    /// completion screen can explain a restart rather than appearing to silently lose progress.
    public mutating func recordInterruption() {
        continuousDuration = 0
        wasInterrupted = true
    }
}

/// In-progress measurement of a lift-mode calibration session.
///
/// Only working sets count toward the bar — warm-up sets are not recorded through this path,
/// so a caller should filter warm-ups before calling `recordWorkingSet`.
public struct LiftProgress: Sendable, Equatable {
    public private(set) var workingSetsPerExercise: [String: Int]

    public init(workingSetsPerExercise: [String: Int] = [:]) {
        self.workingSetsPerExercise = workingSetsPerExercise
    }

    /// Records one working set for the given exercise identifier. Warm-up sets must not be
    /// passed to this method — they do not count toward `CalibrationThreshold.qualifyingWorkingSets`.
    public mutating func recordWorkingSet(exercise: String) {
        workingSetsPerExercise[exercise, default: 0] += 1
    }

    /// Total working sets recorded across every exercise.
    public var totalWorkingSets: Int {
        workingSetsPerExercise.values.reduce(0, +)
    }

    /// Number of distinct exercises with at least one recorded working set.
    public var distinctExercises: Int {
        workingSetsPerExercise.filter { $0.value > 0 }.count
    }
}

/// A calibration session's progress, tagged by mode.
public enum CalibrationProgress: Sendable, Equatable {
    case walk(WalkProgress)
    case lift(LiftProgress)
}

/// Whether a calibration session has met its mode's completion bar.
public enum CalibrationCompletion: Sendable, Equatable {
    case incomplete
    case complete

    /// Evaluates a session's progress against `CalibrationThreshold`.
    ///
    /// - Walk mode is `.complete` when `continuousDuration` has reached
    ///   `CalibrationThreshold.qualifyingWalkDuration`.
    /// - Lift mode is `.complete` only when **both** `totalWorkingSets` has reached
    ///   `CalibrationThreshold.qualifyingWorkingSets` **and** `distinctExercises` has reached
    ///   `CalibrationThreshold.qualifyingExercises` — either condition alone is not sufficient.
    public static func evaluate(_ progress: CalibrationProgress) -> CalibrationCompletion {
        switch progress {
        case .walk(let walk):
            return walk.continuousDuration >= CalibrationThreshold.qualifyingWalkDuration
                ? .complete
                : .incomplete
        case .lift(let lift):
            let hasEnoughSets = lift.totalWorkingSets >= CalibrationThreshold.qualifyingWorkingSets
            let hasEnoughExercises = lift.distinctExercises >= CalibrationThreshold.qualifyingExercises
            return (hasEnoughSets && hasEnoughExercises) ? .complete : .incomplete
        }
    }
}

/// A source of calibration progress, conformed to by both the CoreMotion pedometer adapter and
/// the manual stopwatch (plan 01-15).
///
/// Per D-02 and 01-RESEARCH.md Assumption A1: completion is decided from `progress` alone, so it
/// never depends on location authorization. GPS, when the user has granted it, enriches displayed
/// pace and distance but is never the completion gate — a user who declines location access can
/// still complete calibration.
public protocol CalibrationSessionSource: Sendable {
    var mode: CalibrationMode { get }
    var progress: CalibrationProgress { get }
}
