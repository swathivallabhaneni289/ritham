import Foundation

// RithamCore cannot import CoreMotion or CoreLocation — this domain's set/session shape and its
// auto-fill/qualification logic must never depend on sensor availability. Per D-02, `LiftSession`
// is a deliberately separate domain from `Calibration/CalibrationSession.swift`'s `LiftProgress`
// (calibration's own one-off completion check), while `LiftQualification` below reads the same
// `CalibrationThreshold` constants that domain defines, so the "qualifying lift session" bar is
// never restated or allowed to drift between the two domains.
//
// `LiftSet.id` is load-bearing, not decorative: STRENGTH-05's merge and split (a later plan task,
// `SessionRevision.swift`) reparent sets between sessions, which is only expressible if a set's
// identity survives the move. See 02-RESEARCH.md's Anti-Patterns entry "Value-typed `LiftSet`
// children with no independent identity" for the failure mode this guards against.

/// A single logged set within a `LiftSession`.
///
/// `id` is a stable identity independent of the session that currently holds it — it survives
/// being reparented by `SessionRevision.merge`/`.split` and is never regenerated when a set is
/// grouped into a superset by `SupersetGrouping.join`.
public struct LiftSet: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var exerciseIdentifier: String
    public var weightKg: Double?
    public var reps: Int
    public var isWarmUp: Bool
    public var equipment: Equipment?
    public var supersetGroupID: SupersetGroupID?
    public var orderIndex: Int
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        exerciseIdentifier: String,
        weightKg: Double? = nil,
        reps: Int,
        isWarmUp: Bool = false,
        equipment: Equipment? = nil,
        supersetGroupID: SupersetGroupID? = nil,
        orderIndex: Int,
        completedAt: Date
    ) {
        self.id = id
        self.exerciseIdentifier = exerciseIdentifier
        self.weightKg = weightKg
        self.reps = reps
        self.isWarmUp = isWarmUp
        self.equipment = equipment
        self.supersetGroupID = supersetGroupID
        self.orderIndex = orderIndex
        self.completedAt = completedAt
    }
}

/// A single strength-training session: an ordered collection of `LiftSet`s.
public struct LiftSession: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var sets: [LiftSet]
    public var notes: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        sets: [LiftSet] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sets = sets
        self.notes = notes
    }

    /// Every logged set excluding warm-ups. This is the set of sets that counts toward
    /// `LiftQualification`, `mostRecentSet`'s auto-fill lookup, and `movementPatterns`.
    public var workingSets: [LiftSet] {
        sets.filter { !$0.isWarmUp }
    }

    public var workingSetCount: Int {
        workingSets.count
    }

    public var distinctWorkingExercises: Int {
        Set(workingSets.map(\.exerciseIdentifier)).count
    }

    /// The union of `ExerciseCatalog.patterns(for:)` across every working set in this session —
    /// this is what makes STRENGTH-04's history filter work at session granularity, and why this
    /// is a union rather than a single pattern: a session containing a thruster genuinely trains
    /// both squat and push.
    public var movementPatterns: Set<MovementPattern> {
        workingSets.reduce(into: Set<MovementPattern>()) { patterns, set in
            patterns.formUnion(ExerciseCatalog.patterns(for: set.exerciseIdentifier))
        }
    }

    /// STRENGTH-01's auto-fill source of truth: the most recent working set logged for
    /// `identifier`, taken from the session with the latest `startedAt` that contains it.
    ///
    /// Skips warm-up sets and sessions that don't contain the exercise at all — including
    /// sessions more recent than the one actually returned — and never falls back to a
    /// different exercise. Returns `nil` when the exercise has never been logged.
    public static func mostRecentSet(forExercise identifier: String, in sessions: [LiftSession]) -> LiftSet? {
        let latestSession = sessions
            .filter { session in session.workingSets.contains { $0.exerciseIdentifier == identifier } }
            .max { $0.startedAt < $1.startedAt }

        return latestSession?.workingSets
            .filter { $0.exerciseIdentifier == identifier }
            .max { $0.orderIndex < $1.orderIndex }
    }
}

/// Whether a lift session has met the qualifying bar shared with calibration's lift mode.
///
/// D-02 keeps `LiftSession` a separate domain from `Calibration/CalibrationSession.swift`, but
/// both read the same `CalibrationThreshold` constants for the qualifying bar rather than each
/// restating the numbers — changing either value there keeps this evaluation in sync by
/// construction.
public enum LiftQualification: Sendable, Equatable {
    case incomplete
    case complete

    /// `.complete` only when both `workingSetCount` and `distinctWorkingExercises` reach their
    /// `CalibrationThreshold` values — either alone is `.incomplete`.
    public static func evaluate(_ session: LiftSession) -> LiftQualification {
        let hasEnoughSets = session.workingSetCount >= CalibrationThreshold.qualifyingWorkingSets
        let hasEnoughExercises = session.distinctWorkingExercises >= CalibrationThreshold.qualifyingExercises
        return (hasEnoughSets && hasEnoughExercises) ? .complete : .incomplete
    }
}
