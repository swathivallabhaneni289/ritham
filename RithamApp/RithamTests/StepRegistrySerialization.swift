import Testing

// Fixes the pre-existing cross-suite race `.planning/STATE.md`'s Blockers/Concerns section
// documents: `StepRegistry`'s shared static factory dictionary is touched by several suites
// (`AppShellTests`, `AboutYouStepTests`, `CalibrationSourceTests`, `PhaseCoverageTests`,
// `ScreeningFlowTests`), and each of those suites already carries its own `.serialized` trait.
// That per-suite trait only orders tests *within* that suite -- Swift Testing runs unrelated
// suites concurrently by default, so one suite's `StepRegistry.reset()` can still interleave
// with another suite's in-flight assertions during a full-target run. Individually, every suite
// passes every time (`-only-testing:RithamTests/<Suite>`); only the full concurrent run flakes.
//
// The fix is Swift Testing's real cross-suite serialization mechanism: nesting. A `.serialized`
// trait applied to a suite serializes not just that suite's own tests but its entire subtree of
// child suites, recursively. `StepRegistryTouchingSuites` below is that parent: an empty
// `.serialized` suite with no tests of its own. Each of the five affected suites is re-declared
// as a nested type of `StepRegistryTouchingSuites` via an `extension` in its own file (Swift
// permits a nested type to be introduced by an extension in a different file from the type it
// extends), so Swift Testing's reflection-based discovery places all five under one serialized
// parent and runs them one after another -- never interleaved -- regardless of how many other,
// unrelated suites run concurrently alongside them.
//
// Each nested suite keeps its own `.serialized` trait too: harmless redundancy for tests within
// that one suite, and it means the suite still behaves correctly if it were ever run in
// isolation outside this parent.
@Suite("StepRegistryTouchingSuites", .serialized)
enum StepRegistryTouchingSuites {}
