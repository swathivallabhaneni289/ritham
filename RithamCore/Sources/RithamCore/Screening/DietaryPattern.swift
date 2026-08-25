// DIET-01 (also logged in PROJECT.md's Key Decisions table): dietary_pattern is strictly
// downstream of the Clearance Gate, never part of gate-resolution logic. A dietary
// preference — vegetarian or vegan — must never loosen a safety gate (e.g. a vegan tag
// must never override a kidney-disease required-blocking gate). `DietaryPattern` is
// therefore defined in its own file and must not be referenced by `ClearanceGate`,
// `DomainGates`, or anything the gate engine consumes.

/// The user's dietary pattern, used only to select which food-swap guidance is shown once
/// a gate has already resolved — never as an input to gate resolution itself.
public enum DietaryPattern: String, CaseIterable, Sendable {
    case none
    case vegetarian
    case vegan
}
