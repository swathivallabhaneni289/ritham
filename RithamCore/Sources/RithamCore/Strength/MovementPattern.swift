import Foundation

// `Screening/ConditionTag.swift` establishes the exhaustive-enum-plus-lookup shape this file
// mirrors: `MovementPattern.allCases` is closed and every case carries a `displayName`.
// `Screening/GateEscalation.swift`'s exhaustive per-case discipline (an inline citation per
// case) is mirrored below in spirit, except there is no external doc table to cite against here
// — the "citation" for each `ExerciseCatalog` entry is simply which pattern(s) it trains.
//
// Per 02-RESEARCH.md's Anti-Patterns entry ("a single `movementPattern` (singular) property on
// an exercise") and Assumption A5, `patterns(for:)` returns a `Set<MovementPattern>`, never a
// single case: a compound lift like a thruster must appear under every pattern it genuinely
// trains, or STRENGTH-04's history filtering would mis-file it under only one.

/// The five movement patterns STRENGTH-04 auto-tags exercises with.
public enum MovementPattern: String, CaseIterable, Sendable, Codable, Hashable {
    case push
    case pull
    case squat
    case hinge
    case carry

    public var displayName: String {
        switch self {
        case .push:
            return "Push"
        case .pull:
            return "Pull"
        case .squat:
            return "Squat"
        case .hinge:
            return "Hinge"
        case .carry:
            return "Carry"
        }
    }
}

/// A single seeded exercise: its identifier, display name, the movement pattern(s) it trains,
/// and its default equipment kind.
///
/// `defaultEquipment` is `nil` for exercises with no plate-loaded/pin-stack equipment concept
/// (bodyweight movements, cable/machine stations not modeled by `Equipment`'s five barbell-family
/// cases).
public struct ExerciseDefinition: Sendable, Equatable {
    public let identifier: String
    public let displayName: String
    public let patterns: Set<MovementPattern>
    public let defaultEquipment: Equipment?

    public init(
        identifier: String,
        displayName: String,
        patterns: Set<MovementPattern>,
        defaultEquipment: Equipment? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.patterns = patterns
        self.defaultEquipment = defaultEquipment
    }
}

/// The seeded exercise-to-movement-pattern lookup table.
///
/// Spans all five `MovementPattern` cases and includes genuinely compound entries (`thruster`:
/// squat + push; `clean`: hinge + pull) so the multi-pattern shape is exercised by real seed
/// data, not only by a test fixture.
public enum ExerciseCatalog {
    public static let all: [ExerciseDefinition] = [
        // Push
        ExerciseDefinition(identifier: "benchPress", displayName: "Bench Press", patterns: [.push], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "inclineBenchPress", displayName: "Incline Bench Press", patterns: [.push], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "overheadPress", displayName: "Overhead Press", patterns: [.push], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "pushUp", displayName: "Push-Up", patterns: [.push]),
        ExerciseDefinition(identifier: "dip", displayName: "Dip", patterns: [.push]),
        ExerciseDefinition(identifier: "dumbbellShoulderPress", displayName: "Dumbbell Shoulder Press", patterns: [.push]),
        ExerciseDefinition(identifier: "closeGripBenchPress", displayName: "Close-Grip Bench Press", patterns: [.push], defaultEquipment: .standardBarbell),

        // Pull
        ExerciseDefinition(identifier: "pullUp", displayName: "Pull-Up", patterns: [.pull]),
        ExerciseDefinition(identifier: "chinUp", displayName: "Chin-Up", patterns: [.pull]),
        ExerciseDefinition(identifier: "latPulldown", displayName: "Lat Pulldown", patterns: [.pull]),
        ExerciseDefinition(identifier: "barbellRow", displayName: "Barbell Row", patterns: [.pull], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "seatedCableRow", displayName: "Seated Cable Row", patterns: [.pull]),
        ExerciseDefinition(identifier: "dumbbellRow", displayName: "Dumbbell Row", patterns: [.pull]),
        ExerciseDefinition(identifier: "facePull", displayName: "Face Pull", patterns: [.pull]),

        // Squat
        ExerciseDefinition(identifier: "backSquat", displayName: "Back Squat", patterns: [.squat], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "frontSquat", displayName: "Front Squat", patterns: [.squat], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "gobletSquat", displayName: "Goblet Squat", patterns: [.squat]),
        ExerciseDefinition(identifier: "legPress", displayName: "Leg Press", patterns: [.squat]),
        ExerciseDefinition(identifier: "bulgarianSplitSquat", displayName: "Bulgarian Split Squat", patterns: [.squat]),
        ExerciseDefinition(identifier: "hackSquat", displayName: "Hack Squat", patterns: [.squat]),

        // Hinge
        ExerciseDefinition(identifier: "deadlift", displayName: "Deadlift", patterns: [.hinge], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "romanianDeadlift", displayName: "Romanian Deadlift", patterns: [.hinge], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "sumoDeadlift", displayName: "Sumo Deadlift", patterns: [.hinge], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "kettlebellSwing", displayName: "Kettlebell Swing", patterns: [.hinge]),
        ExerciseDefinition(identifier: "goodMorning", displayName: "Good Morning", patterns: [.hinge], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "hipThrust", displayName: "Hip Thrust", patterns: [.hinge], defaultEquipment: .standardBarbell),

        // Carry
        ExerciseDefinition(identifier: "farmersCarry", displayName: "Farmer's Carry", patterns: [.carry]),
        ExerciseDefinition(identifier: "suitcaseCarry", displayName: "Suitcase Carry", patterns: [.carry]),
        ExerciseDefinition(identifier: "sandbagCarry", displayName: "Sandbag Carry", patterns: [.carry]),

        // Compound — genuinely multi-pattern, per 02-RESEARCH.md Assumption A5.
        ExerciseDefinition(identifier: "thruster", displayName: "Thruster", patterns: [.squat, .push], defaultEquipment: .standardBarbell),
        ExerciseDefinition(identifier: "clean", displayName: "Clean", patterns: [.hinge, .pull], defaultEquipment: .standardBarbell),
    ]

    private static let byIdentifier: [String: ExerciseDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.identifier, $0) }
    )

    /// The movement pattern(s) a seeded exercise identifier trains.
    ///
    /// An unknown identifier resolves to an empty set — never a wrong default — so history
    /// filtering never mis-files it under a pattern it doesn't actually train.
    public static func patterns(for identifier: String) -> Set<MovementPattern> {
        byIdentifier[identifier]?.patterns ?? []
    }

    /// The full definition for a seeded exercise identifier, or `nil` if unknown.
    public static func definition(for identifier: String) -> ExerciseDefinition? {
        byIdentifier[identifier]
    }
}
