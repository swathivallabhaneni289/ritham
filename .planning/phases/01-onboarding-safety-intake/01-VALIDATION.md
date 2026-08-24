---
phase: 1
slug: onboarding-safety-intake
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-23
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing for all unit/business-logic tests; `XCUITest` (via XCTest) reserved for any UI-flow smoke tests the wizard warrants |
| **Config file** | `RithamCore/Package.swift` (core suite) and `RithamApp/project.yml` (app suite); both created in this phase — see Toolchain Note below |
| **Quick run command — core** | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` |
| **Full suite command — core** | `cd RithamCore && ./Scripts/test-core.sh` |
| **Quick run command — app** | `./Scripts/build-app.sh test -only-testing:RithamTests/<Suite>` |
| **Full suite command — app** | `./Scripts/build-app.sh test` |
| **Estimated runtime** | core suite ~2-5s (no simulator boot); app suite ~30-60s (simulator boot dominates) |

> **2026-08-23 update:** The "Full suite command — service" row (`cd consent-service && go test
> ./... -count=1`) is removed — the Go consent-service backend no longer exists. Ritham has a
> permanent 13+ age floor with no parental-consent flow of any kind; see `01-CONTEXT.md` D-14/D-15.

### Toolchain Note (planner, 2026-08-23)

Xcode is **not installed** on the development machine — verified during planning: `xcode-select -p`
resolves to `/Library/Developer/CommandLineTools`, `xcodebuild` reports "requires Xcode", and
`xcodebuild -showsdks` lists no iOS SDK. Every command originally drafted in this document as
`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 15'` therefore could not run, and
`iPhone 15` is not guaranteed to exist on any given machine.

Two consequences, both already reflected in the plans:

1. The safety-critical logic was extracted into `RithamCore`, a Foundation-only Swift package. Swift
   Testing **is** present in Command Line Tools (at `<dev-dir>/Library/Developer/Frameworks`), so
   `swift test` runs green there once given the framework search path and the two rpaths.
   `RithamCore/Scripts/test-core.sh` (plan 01-01) branches on `xcode-select -p` and supplies them only
   on the Command Line Tools path, so the same command keeps working after plan 01-09 installs Xcode.
2. `Scripts/build-app.sh` (plan 01-09) resolves an available simulator from
   `xcrun simctl list devices available` rather than naming a device.

The **behaviours** asserted below are unchanged from the original draft; only the invocation changed.

---

## Sampling Rate

- **After every task commit:** Run the targeted subset for the module just touched — `./Scripts/test-core.sh --filter <Suite>`, `go test ./internal/<pkg>/...`, or `./Scripts/build-app.sh test -only-testing:RithamTests/<Suite>`
- **After every plan wave:** Run the full core suite (`cd RithamCore && ./Scripts/test-core.sh`) — the safety-critical gate resolution, age-floor, calibration, and routing logic all live there
- **Before `/gsd-verify-work`:** Both suites green — core and app
- **Max feedback latency:** 60 seconds (core suite is ~2-5s, so most feedback is far faster)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-09-T2 | 01-09 | 4 | — | T-01-50 | Xcode project + test target scaffold exists and builds | build | `./Scripts/build-app.sh build` | ❌ W4 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-06 | T-01-26 | "Not sure" always resolves to the more cautious branch (docs/health-screening.md §5) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testNotSureResolvesCautious`) | ❌ W1 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-06 | T-01-25 | 2+ red-flag tags → single most restrictive gate wins, never averaged | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testMultiTagMostRestrictiveWins`) | ❌ W1 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-01 | T-01-28 | SCOFF fires only when the Eating Disorder History checkbox is checked; score ≥2 → positive screen, never shown as a label/score | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testSCOFFTrigger`) | ❌ W1 | ⬜ pending |
| 01-07-T3a | 01-07 | 3 | MINOR-01 | T-01-32 | Age under 13 (at onboarding Q0, self-attested) routes to the age-ineligible block step and never advances past it while the age stays under 13; correcting the age to 13+ routes forward exactly like any other user | unit | `cd RithamCore && ./Scripts/test-core.sh --filter OnboardingFlowStateTests` | ❌ W1 | ⬜ pending |
| 01-13-T2 | 01-13 | 7 | MINOR-01 | T-01-73B | An under-13 age is never written to `HealthDataStore` on initial entry — the persist call is gated on the value being 13 or greater, so a rejected attempt has nothing saved for it client-side, before the profile even exists | unit | `./Scripts/build-app.sh test -only-testing:RithamTests/AgeValidationTests` | ❌ W4 | ⬜ pending |
| 01-03-T3 | 01-03 | 2 | HEALTH-02 | T-01-12 | Condition tag validity computes correctly at the 12-month boundary; expired-but-unconfirmed tags still apply their restriction (D-08) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter ConditionTagExpiryTests` | ❌ W1 | ⬜ pending |
| 01-05-T1 | 01-05 | 2 | ONBOARD-01 | T-01-20 | Calibration completes at 10+ continuous minutes (walk) or 3+ working sets across 2+ exercises (lift) — matches MOMENTUM-01's bar exactly (D-01, corrected) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter CalibrationThresholdTests` | ❌ W1 | ⬜ pending |
| 01-07-T3 | 01-07 | 3 | CROSSGEN-05 | T-01-34 | No age value ever routes to a structurally distinct view hierarchy — only content/step differs within one shared NavigationStack; ages 15, 40, and 70 traverse an identical sequence | unit | `cd RithamCore && ./Scripts/test-core.sh --filter OnboardingFlowStateTests` | ❌ W1 | ⬜ pending |
| 01-11-T3 | 01-11 | 5 | MINOR-01 | T-01-66 | The 13+ age floor is enforced at the data layer, not just the edit-screen UI — a Settings edit that lowers a confirmed user's age below 13 throws `ageBelowFloor`, is rejected wholesale, and leaves the previous age (and every other stored field) unchanged, so a navigation/UI bypass alone cannot silently save it | unit | `./Scripts/build-app.sh test -only-testing:RithamTests/HealthDataStoreTests` | ❌ W4 | ⬜ pending |
| 01-18-T2 | 01-18 | 9 | HEALTH-01 | T-01-114 | Every onboarding step resolves to a real screen — no step ships on the unimplemented fallback | unit | `./Scripts/build-app.sh test -only-testing:RithamTests/PhaseCoverageTests` | ❌ W4 | ⬜ pending |

*"File Exists" records the wave that creates the test file: W1 = the `RithamCore` package (buildable
today, no Xcode), W4 = the app target (needs the Xcode install checkpoint in plan 01-09).*

*The bottom two rows were added by the planner: the data-layer gate and the step-coverage assertion are
both load-bearing safety properties that the original draft did not have a row for.*

> **2026-08-23 update:** Ritham now has a permanent 13+ age floor with no consent flow of any kind
> (see `01-CONTEXT.md` D-14/D-15). Plan 01-04 (age-to-tier resolution, consent state machine,
> capability matrix) and plan 01-14 (consent screens/client) no longer exist — deleted, not just
> trimmed — so every row that pointed at them is either removed or reassigned to the plan that
> actually now owns the behavior. Two rows previously here — `01-04-T2` (`ConsentStateMachineTests`,
> asserting a consent state machine only reaches `confirmed` after a link click plus a delayed
> second-email confirmation) and `01-02-T2` (the server-side `go test` mirror of the same rule) — are
> removed outright; the Go consent-service backend they tested no longer exists. The old `01-04-T1`
> row ("age routes to under-13/13-17/18+ consent tiers", `ConsentTierTests`) is split across two real
> test suites rather than one invented "AgeFloorTests" file: `01-07-T3a` (routing-level: under-13
> blocked at `OnboardingFlowStateTests`, plan 01-07) and `01-13-T2` (client persist-gating on initial
> entry, `AgeValidationTests`, plan 01-13). The `01-11-T3` row is rewritten from "the consent gate is
> enforced at the data layer" to the surviving analogous property — data-layer enforcement of the
> reject-edit-below-13 rule via the new `ageBelowFloor` error (T-01-66) — since there is no longer a
> consent gate for a navigation bug to bypass, but a Settings edit to below 13 still needs to be
> rejected below the UI layer, not just in it; its command is updated from the old
> `HealthDataStoreGateTests` name to the actual `HealthDataStoreTests` (renamed when the consent gate
> was removed from that file).

---

## Wave 0 Requirements

Wave 0 is realised as **wave 1 plan 01-01**, which scaffolds the `RithamCore` package and the
toolchain-adaptive test runner before any feature work. The pure-Swift module structure this section
originally asked for is now enforced at compile time rather than by convention: `RithamCore` is
Foundation-only, so a SwiftUI or SwiftData import in the gate-resolution logic would not build.

- [ ] `RithamCore/Package.swift` + `RithamCore/Scripts/test-core.sh` + a green harness probe — plan 01-01, wave 1
- [ ] `RithamCoreTests/GateResolutionTests.swift` — covers HEALTH-01, HEALTH-06 — plan 01-06, wave 3
- [ ] `RithamCoreTests/ConditionTagExpiryTests.swift` — covers HEALTH-02 — plan 01-03, wave 2
- [ ] `RithamCoreTests/CalibrationThresholdTests.swift` — covers ONBOARD-01 (threshold settled per corrected D-01: 10+ min walk / 3+ sets across 2+ exercises) — plan 01-05, wave 2
- [ ] `RithamCoreTests/OnboardingFlowStateTests.swift` — covers CROSSGEN-05's no-fork guarantee and MINOR-01's 13+ floor at the routing-logic level (under-13 blocked at `.ageIneligible`; every eligible age traverses identically) — plan 01-07, wave 3
- [ ] Xcode project + `RithamTests` app test target — plan 01-09, wave 4, gated on the Xcode install checkpoint
- [ ] `RithamTests/AgeValidationTests.swift` — covers MINOR-01's client-side persist-gating (an under-13 value is never written to `HealthDataStore` on initial entry) alongside the 1-120 numeric bound — plan 01-13, wave 7
- [ ] `RithamTests/HealthDataStoreTests.swift` — covers MINOR-01's data-layer floor enforcement (`ageBelowFloor` rejects a Settings edit below 13, previous age kept) — plan 01-11, wave 5

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Band-motif header renders correctly and reflows at AX1–AX5 without compositing text over the band/halftone texture | Visual (01-UI-SPEC.md Typography Reflow rule) | Visual/accessibility-size rendering correctness isn't meaningfully assertable via unit test | Plan 01-18 Task 3, group A. Run the app in Simulator at each Dynamic Type accessibility size (Settings → Accessibility → Display & Text Size), confirm header compresses/drops and no text overlaps the band motif |
| CMPedometer step/distance accuracy during a real walk | ONBOARD-01 (D-02) | CoreMotion sensor output can't be meaningfully simulated in the iOS Simulator | Plan 01-18 Task 3, group C. Walk with a physical device for 10+ minutes, confirm the session completes with location declined, and that the resulting pace-zone baseline looks reasonable |

*The computational half of the band-motif check is automated separately: `BandGeometryTests` (plan 01-10)
asserts non-zero flat margins at three real portrait header sizes, so only the rendering itself is manual.*

*2026-08-23 update: the "Parental consent email delivery and Universal Link deep-link-back-into-app"
row (group B) previously here is removed — no consent flow exists to verify. Self-attested age entry
needs no email/device round-trip, so it stays fully covered by `AgeFloorTests` above with no manual
verification required. See `01-CONTEXT.md` D-14/D-15.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
