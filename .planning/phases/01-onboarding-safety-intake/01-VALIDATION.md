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
| **Full suite command — service** | `cd consent-service && go test ./... -count=1` |
| **Estimated runtime** | core suite ~2-5s (no simulator boot); app suite ~30-60s (simulator boot dominates); service suite ~2s |

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
- **After every plan wave:** Run the full core suite (`cd RithamCore && ./Scripts/test-core.sh`) — the safety-critical gate resolution, consent, calibration, and routing logic all live there
- **Before `/gsd-verify-work`:** All three suites green — core, service, and app
- **Max feedback latency:** 60 seconds (core suite is ~2-5s, so most feedback is far faster)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-09-T2 | 01-09 | 4 | — | T-01-50 | Xcode project + test target scaffold exists and builds | build | `./Scripts/build-app.sh build` | ❌ W4 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-06 | T-01-26 | "Not sure" always resolves to the more cautious branch (docs/health-screening.md §5) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testNotSureResolvesCautious`) | ❌ W1 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-06 | T-01-25 | 2+ red-flag tags → single most restrictive gate wins, never averaged | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testMultiTagMostRestrictiveWins`) | ❌ W1 | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | HEALTH-01 | T-01-28 | SCOFF fires only when the Eating Disorder History checkbox is checked; score ≥2 → positive screen, never shown as a label/score | unit | `cd RithamCore && ./Scripts/test-core.sh --filter GateResolutionTests` (test `testSCOFFTrigger`) | ❌ W1 | ⬜ pending |
| 01-04-T1 | 01-04 | 2 | MINOR-01 | T-01-16 | Age routes correctly to under-13 / 13-17 / 18+ consent tiers | unit | `cd RithamCore && ./Scripts/test-core.sh --filter ConsentTierTests` | ❌ W1 | ⬜ pending |
| 01-04-T2 | 01-04 | 2 | MINOR-01/02 | T-01-04 | Consent state machine only reaches `confirmed` after both the link click AND the delayed second-email confirmation — a single click alone stays at `link_clicked`, never `confirmed` | unit | `cd RithamCore && ./Scripts/test-core.sh --filter ConsentStateMachineTests` | ❌ W1 | ⬜ pending |
| 01-02-T2 | 01-02 | 1 | MINOR-01/02 | T-01-04 | Server-side mirror of the same rule: no event sequence reaches `confirmed` without the second confirmation | unit | `cd consent-service && go test ./internal/consent/... -count=1` | ❌ W1 | ⬜ pending |
| 01-03-T3 | 01-03 | 2 | HEALTH-02 | T-01-12 | Condition tag validity computes correctly at the 12-month boundary; expired-but-unconfirmed tags still apply their restriction (D-08) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter ConditionTagExpiryTests` | ❌ W1 | ⬜ pending |
| 01-05-T1 | 01-05 | 2 | ONBOARD-01 | T-01-20 | Calibration completes at 10+ continuous minutes (walk) or 3+ working sets across 2+ exercises (lift) — matches MOMENTUM-01's bar exactly (D-01, corrected) | unit | `cd RithamCore && ./Scripts/test-core.sh --filter CalibrationThresholdTests` | ❌ W1 | ⬜ pending |
| 01-07-T3 | 01-07 | 3 | CROSSGEN-05 | T-01-34 | No age value ever routes to a structurally distinct view hierarchy — only content/step differs within one shared NavigationStack | unit | `cd RithamCore && ./Scripts/test-core.sh --filter OnboardingFlowStateTests` | ❌ W1 | ⬜ pending |
| 01-11-T3 | 01-11 | 5 | MINOR-01 | T-01-58 | The consent gate is enforced at the data layer, so a navigation defect alone cannot read or write a minor's screening data | unit | `./Scripts/build-app.sh test -only-testing:RithamTests/HealthDataStoreGateTests` | ❌ W4 | ⬜ pending |
| 01-18-T2 | 01-18 | 9 | HEALTH-01 | T-01-114 | Every onboarding step resolves to a real screen — no step ships on the unimplemented fallback | unit | `./Scripts/build-app.sh test -only-testing:RithamTests/PhaseCoverageTests` | ❌ W4 | ⬜ pending |

*"File Exists" records the wave that creates the test file: W1 = the `RithamCore` package (buildable
today, no Xcode), W4 = the app target (needs the Xcode install checkpoint in plan 01-09).*

*The bottom two rows were added by the planner: the data-layer gate and the step-coverage assertion are
both load-bearing safety properties that the original draft did not have a row for.*

---

## Wave 0 Requirements

Wave 0 is realised as **wave 1 plan 01-01**, which scaffolds the `RithamCore` package and the
toolchain-adaptive test runner before any feature work. The pure-Swift module structure this section
originally asked for is now enforced at compile time rather than by convention: `RithamCore` is
Foundation-only, so a SwiftUI or SwiftData import in the gate-resolution logic would not build.

- [ ] `RithamCore/Package.swift` + `RithamCore/Scripts/test-core.sh` + a green harness probe — plan 01-01, wave 1
- [ ] `RithamCoreTests/GateResolutionTests.swift` — covers HEALTH-01, HEALTH-06 — plan 01-06, wave 3
- [ ] `RithamCoreTests/ConsentTierTests.swift` — covers MINOR-01 — plan 01-04, wave 2
- [ ] `RithamCoreTests/ConsentStateMachineTests.swift` — covers MINOR-01/02's corrected D-05 (`pending → email_sent → link_clicked → confirmed`) — plan 01-04, wave 2
- [ ] `consent-service/internal/consent/state_test.go` — the server-side mirror of the same rule — plan 01-02, wave 1
- [ ] `RithamCoreTests/ConditionTagExpiryTests.swift` — covers HEALTH-02 — plan 01-03, wave 2
- [ ] `RithamCoreTests/CalibrationThresholdTests.swift` — covers ONBOARD-01 (threshold settled per corrected D-01: 10+ min walk / 3+ sets across 2+ exercises) — plan 01-05, wave 2
- [ ] `RithamCoreTests/OnboardingFlowStateTests.swift` — covers CROSSGEN-05's no-fork guarantee at the routing-logic level — plan 01-07, wave 3
- [ ] Xcode project + `RithamTests` app test target — plan 01-09, wave 4, gated on the Xcode install checkpoint

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Band-motif header renders correctly and reflows at AX1–AX5 without compositing text over the band/halftone texture | Visual (01-UI-SPEC.md Typography Reflow rule) | Visual/accessibility-size rendering correctness isn't meaningfully assertable via unit test | Plan 01-18 Task 3, group A. Run the app in Simulator at each Dynamic Type accessibility size (Settings → Accessibility → Display & Text Size), confirm header compresses/drops and no text overlaps the band motif |
| Parental consent email delivery and Universal Link deep-link-back-into-app | MINOR-01/02 | Requires a real email send/receive round-trip and a real device/simulator Universal Link handoff — not mockable in a pure unit test without losing the thing being verified | Plan 01-18 Task 3, group B. Trigger consent flow with a real test email address, click the link on a physical device, confirm the app opens with the account still locked, then repeat for the delayed second confirmation email and confirm it unlocks |
| CMPedometer step/distance accuracy during a real walk | ONBOARD-01 (D-02) | CoreMotion sensor output can't be meaningfully simulated in the iOS Simulator | Plan 01-18 Task 3, group C. Walk with a physical device for 10+ minutes, confirm the session completes with location declined, and that the resulting pace-zone baseline looks reasonable |

*The computational half of the band-motif check is automated separately: `BandGeometryTests` (plan 01-10)
asserts non-zero flat margins at three real portrait header sizes, so only the rendering itself is manual.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
