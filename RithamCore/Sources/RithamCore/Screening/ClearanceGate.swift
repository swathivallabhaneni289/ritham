// The three-level personalization gate used throughout docs/health-screening.md §2 and §3,
// and the domain a gate applies to. HEALTH-06's governing rule (§5): when two or more
// red-flag tags apply, Ritham applies the single most restrictive gate across all of them —
// never averaged, blended, or softened. That rule is enforced structurally here: this file
// defines an ordering and a most-restrictive selector, and deliberately no averaging,
// combining, or downgrading operation of any kind. The absence of such an API is the
// safeguard, not a convention any call site has to remember.

/// The three personalization gate levels, in ascending restrictiveness.
///
/// `none` = personalized suggestions shown normally. `recommended` = suggestions shown,
/// paired with a "check with a professional first" note. `requiredBlocking` = no
/// personalized suggestion at all in the affected domain — only generic information and a
/// referral message. `Comparable` conformance is synthesized from declaration order, so the
/// ordering below is a language-level fact, not a convention each call site re-implements.
public enum ClearanceGate: Sendable, Comparable, CaseIterable {
    case none
    case recommended
    case requiredBlocking

    /// The single most restrictive gate across every input, per HEALTH-06 §5's governing
    /// principle. Returns `.none` for an empty input. There is no counterpart that averages,
    /// blends, or softens a set of gates — that operation must never exist.
    public static func mostRestrictive(_ gates: [ClearanceGate]) -> ClearanceGate {
        gates.max() ?? .none
    }
}

/// The two areas a `ClearanceGate` can independently govern. HEALTH-06 scopes a blocking
/// gate to a domain, never to app access as a whole (§5: "manual logging and generic,
/// non-personalized information stay available throughout"), so a gate is always paired
/// with the domain it applies to.
public enum GuidanceDomain: Sendable, CaseIterable {
    case workout
    case nutrition
}

/// A user's current clearance gate for each `GuidanceDomain`, independently trackable since
/// a condition tag can gate one domain without gating the other (e.g. a severe food allergy
/// gates nutrition but not workout).
public struct DomainGates: Sendable, Equatable {
    public var workout: ClearanceGate
    public var nutrition: ClearanceGate

    public init(workout: ClearanceGate, nutrition: ClearanceGate) {
        self.workout = workout
        self.nutrition = nutrition
    }

    public subscript(domain: GuidanceDomain) -> ClearanceGate {
        switch domain {
        case .workout:
            return workout
        case .nutrition:
            return nutrition
        }
    }
}
