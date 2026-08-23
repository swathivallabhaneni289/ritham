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
| **Framework** | Swift Testing (Xcode 16+) for unit/business-logic tests; `XCUITest` (via XCTest) reserved for any UI-flow smoke tests the wizard warrants |
| **Config file** | none — greenfield project, Wave 0 must scaffold the test target alongside the app target |
| **Quick run command** | `xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RithamTests/GateResolutionTests` (adjust scheme/target names once Wave 0 names them) |
| **Full suite command** | `xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 15'` |
| **Estimated runtime** | ~30-60 seconds (simulator boot dominates; unit-only subset is fast since gate-resolution logic is a pure Swift module with no SwiftUI/SwiftData host) |

---

## Sampling Rate

- **After every task commit:** Run the targeted `-only-testing:` subset for the module just touched
- **After every plan wave:** Run the full `GateResolutionTests` + `ConsentTierTests` suite (the safety-critical core)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-TBD | TBD | 0 | — | — | Xcode project + test target scaffold exists | build | `xcodebuild -scheme Ritham build` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | HEALTH-06 | — | "Not sure" always resolves to the more cautious branch (docs/health-screening.md §5) | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testNotSureResolvesCautious` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | HEALTH-06 | — | 2+ red-flag tags → single most restrictive gate wins, never averaged | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testMultiTagMostRestrictiveWins` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | HEALTH-01 | — | SCOFF fires only when the Eating Disorder History checkbox is checked; score ≥2 → positive screen, never shown as a label/score | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testSCOFFTrigger` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | MINOR-01 | — | Age routes correctly to under-13 / 13-17 / 18+ consent tiers | unit | `xcodebuild test ... -only-testing:RithamTests/ConsentTierTests` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | MINOR-01/02 | — | Consent state machine only reaches `confirmed` after both the link click AND the delayed second-email confirmation — a single click alone stays at `link_clicked`, never `confirmed` | unit | `xcodebuild test ... -only-testing:RithamTests/ConsentStateMachineTests` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | HEALTH-02 | — | Condition tag `isExpired` computes correctly at the 12-month boundary; expired-but-unconfirmed tags still apply their restriction (D-08) | unit | `xcodebuild test ... -only-testing:RithamTests/ConditionTagExpiryTests` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | ONBOARD-01 | — | Calibration completes at 10+ continuous minutes (walk) or 3+ working sets across 2+ exercises (lift) — matches MOMENTUM-01's bar exactly (D-01, corrected) | unit | `xcodebuild test ... -only-testing:RithamTests/CalibrationThresholdTests` | ❌ W0 | ⬜ pending |
| 01-TBD | TBD | TBD | CROSSGEN-05 | — | No age value ever routes to a structurally distinct view hierarchy — only content/step differs within one shared NavigationStack | unit | `xcodebuild test ... -only-testing:RithamTests/OnboardingFlowStateTests` | ❌ W0 | ⬜ pending |

*Task IDs, plan IDs, and waves are TBD — the planner assigns these; this table's rows are the required coverage the plan-checker will verify against.*

---

## Wave 0 Requirements

- [ ] Xcode project + `RithamTests` test target scaffold — none exists yet, this is Wave 0's first task
- [ ] `RithamTests/GateResolutionTests.swift` — covers HEALTH-01, HEALTH-06 (build the gate-resolution logic as a pure Swift module with no SwiftUI/SwiftData dependency, per 01-RESEARCH.md's Architectural Responsibility Map, so these tests run fast and in isolation)
- [ ] `RithamTests/ConsentTierTests.swift` — covers MINOR-01
- [ ] `RithamTests/ConsentStateMachineTests.swift` — covers MINOR-01/02's corrected D-05 (`pending → email_sent → link_clicked → confirmed`)
- [ ] `RithamTests/ConditionTagExpiryTests.swift` — covers HEALTH-02
- [ ] `RithamTests/CalibrationThresholdTests.swift` — covers ONBOARD-01 (threshold now settled per corrected D-01: 10+ min walk / 3+ sets across 2+ exercises)
- [ ] `RithamTests/OnboardingFlowStateTests.swift` — covers CROSSGEN-05's no-fork guarantee at the routing-logic level

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Band-motif header renders correctly and reflows at AX1–AX5 without compositing text over the band/halftone texture | Visual (01-UI-SPEC.md Typography Reflow rule) | Visual/accessibility-size rendering correctness isn't meaningfully assertable via unit test | Run the app in Simulator at each Dynamic Type accessibility size (Settings → Accessibility → Display & Text Size), confirm header compresses/drops and no text overlaps the band motif |
| Parental consent email delivery and Universal Link deep-link-back-into-app | MINOR-01/02 | Requires a real email send/receive round-trip and a real device/simulator Universal Link handoff — not mockable in a pure unit test without losing the thing being verified | Trigger consent flow with a real test email address, click the link on a physical device, confirm the app opens to the correct in-app state; repeat for the delayed second confirmation email |
| CMPedometer step/distance accuracy during a real walk | ONBOARD-01 (D-02) | CoreMotion sensor output can't be meaningfully simulated in the iOS Simulator | Walk with a physical device for 10+ minutes, confirm the session completes and the resulting pace-zone baseline looks reasonable |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
