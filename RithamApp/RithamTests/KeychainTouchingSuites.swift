import Testing

// Fixes a real, observed cross-suite race, the same class `StepRegistrySerialization.swift`
// already documents and fixes for `StepRegistry`'s shared static state: `SessionStore` (plan
// 04.1-05) is backed by the real iOS/macOS Keychain, a single process-wide store, not something
// test-isolated per suite or per test. `SocialIdentityTests`, `FriendsUITests`, and this plan's
// `GroupsUITests` each write to it (`SessionStore.store(...)`) from their own test bodies, and
// `SocialIdentityTests`/`FriendsUITests` additionally call `SessionStore().clear()` in their own
// `init()`. Each suite's own `.serialized` trait only orders tests *within* that suite -- Swift
// Testing runs unrelated suites concurrently by default, so one suite's Keychain write can land
// between another suite's own store-then-assert pair. Observed directly during plan 04.1-11's own
// full-target verification: `SocialIdentityTests.requestCarriesBearerHeaderWhenTokenStored()`
// failed deterministically in the full-target run while passing every scoped
// `-only-testing:` run, including that same test run alone.
//
// The fix mirrors `StepRegistryTouchingSuites`'s own real cross-suite serialization mechanism:
// nesting. A `.serialized` trait applied to a suite serializes not just that suite's own tests but
// its entire subtree of child suites, recursively. `KeychainTouchingSuites` below is that parent:
// an empty `.serialized` suite with no tests of its own. Each of the three Keychain-touching
// suites is re-declared as a nested type via an `extension` in its own file (Swift permits a
// nested type to be introduced by an extension in a different file from the type it extends), so
// Swift Testing's reflection-based discovery places all three under one serialized parent and runs
// them one after another -- never interleaved -- regardless of how many other, unrelated suites
// run concurrently alongside them.
@Suite("KeychainTouchingSuites", .serialized)
enum KeychainTouchingSuites {}
