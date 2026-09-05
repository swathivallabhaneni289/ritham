import Foundation

// RithamCore cannot import CoreLocation or CoreMotion — an activity type's identity, and any
// cardio session qualification derived from it, therefore never depends on sensor availability.
// Per CARDIO-01 the activity-type vocabulary must be extensible without editing an exhaustive
// switch, so `ActivityType` is deliberately a `RawRepresentable` struct — not a closed enum like
// Phase 1's `CalibrationMode` — wrapping a `String` raw value.

/// A cardio activity type, identified by its raw string value.
///
/// Unlike `CalibrationMode` (a closed two-case enum), `ActivityType` is a `RawRepresentable`
/// struct so a caller can construct a value outside `known` — e.g. `ActivityType(rawValue:
/// "rowing")` — with no edit to this file. `known` is a curated display list of the six
/// activities Ritham's own UI currently surfaces, not an exhaustive domain boundary: adding a
/// seventh activity to Ritham's UI later only means adding it to `known`, never touching an
/// exhaustive switch elsewhere in the domain.
public struct ActivityType: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let run = ActivityType(rawValue: "run")
    public static let walk = ActivityType(rawValue: "walk")
    public static let cycle = ActivityType(rawValue: "cycle")
    public static let hike = ActivityType(rawValue: "hike")
    public static let swim = ActivityType(rawValue: "swim")
    public static let elliptical = ActivityType(rawValue: "elliptical")

    /// The activities Ritham currently surfaces in its own UI, in display order.
    public static let known: [ActivityType] = [.run, .walk, .cycle, .hike, .swim, .elliptical]

    /// A human-readable label. Known activities get a hand-written label; any other raw value
    /// (e.g. one added outside `known`, such as "rowing") falls back to its capitalized raw
    /// value rather than trapping or returning an empty string.
    public var displayName: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .cycle: return "Cycle"
        case .hike: return "Hike"
        case .swim: return "Swim"
        case .elliptical: return "Elliptical"
        default: return rawValue.capitalized
        }
    }
}
