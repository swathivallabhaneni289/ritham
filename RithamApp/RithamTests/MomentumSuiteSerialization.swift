import Testing

// Fixes the same class of problem `StepRegistrySerialization.swift` solves, but for a different
// shared resource: `.planning/STATE.md`'s open Blockers/Concerns entry records a low-frequency
// crash when several Swift Testing suites instantiate in-memory SwiftData model containers
// concurrently during a full-target run. Every new container-creating suite this phase adds
// nests under this parent (via an `extension` in its own file, the same nesting mechanism
// `StepRegistryTouchingSuites` uses) so they are ordered relative to each other, never
// interleaved, regardless of how many other, unrelated suites run concurrently alongside them.
//
// The three pre-existing, un-serialized container-creating suites (`HealthDataStoreTests`,
// `WorkoutPreferenceTests`, and any other suite already in the target before this phase) are
// deliberately left untouched -- that flake is a separate, pre-existing STATE.md item, not this
// phase's scope to fix retroactively.
@Suite("MomentumContainerTouchingSuites", .serialized)
enum MomentumContainerTouchingSuites {}
