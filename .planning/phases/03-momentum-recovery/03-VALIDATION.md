---
phase: 3
slug: momentum-recovery
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-06
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`/`@Suite`), bundled with the Swift 6 toolchain |
| **Config file** | None — `RithamCore/Package.swift`'s `.testTarget` and `RithamApp/project.yml`'s `RithamTests` target are the only configuration |
| **Quick run command** | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` |
| **Full suite command** | `Scripts/build-app.sh test` (resolves an available iPhone simulator UDID dynamically, never a hardcoded model name) |
| **Estimated runtime** | ~5-15s (RithamCore swift test), ~2-5min (full xcodebuild suite) |

---

## Sampling Rate

- **After every task commit:** `RithamCore/Scripts/test-core.sh` (pure-domain suite; fast, no simulator boot required for most of this phase's logic)
- **After every plan wave:** `Scripts/build-app.sh test -only-testing:RithamTests/<NewSuite>` for each new suite individually — avoid a full-target run mid-phase per the `StepRegistry` race precedent (Pitfall 5)
- **Before `/gsd-verify-work`:** Full-target `Scripts/build-app.sh test` (no `-only-testing:` filter) green before declaring the phase done, matching 02-16's precedent
- **Max feedback latency:** ~15s per task (RithamCore suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-T2 / 03-03-T1 | 03-01, 03-03 | 1 | MOMENTUM-01 | T-3-01, T-3-02 | Qualifying cardio/lift session counted equally; manual-vs-sensor labeled; endowed head start (D-10) | unit | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` (equal-weight fold) plus `RithamCore/Scripts/test-core.sh --filter MomentumTargetTests` (D-10 endowed credit) | ✅ | ✅ green |
| 03-03-T2 | 03-03 | 1 | MOMENTUM-02 | T-3-02 | Shield accrual (1/4 weeks, stacks to 3), never purchasable, auto-applies on miss via reconciliation-on-read | unit | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` | ✅ | ✅ green |
| 03-01-T1 / 03-05-T3 | 03-01, 03-05 | 1 | MOMENTUM-03 | T-3-02, T-3-08 | Monday 3am local reset boundary incl. DST fixtures; Recovery Week user-initiated only, retroactive whole-week pause (D-12) | unit | `RithamCore/Scripts/test-core.sh --filter MomentumWeekTests` | ✅ | ✅ green |
| 03-03-T3 | 03-03 | 1 | MOMENTUM-04 | T-3-02, T-3-04 | Comeback Session within 3 days restores streak minus one, never to zero | unit | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` | ✅ | ✅ green |
| 03-03-T2 / 03-02-T3 | 03-02, 03-03 | 1 | MOMENTUM-05 | T-3-02, T-3-05 | Milestones at 4/12/26/52 weeks, never re-derived away after retroactive session edit; competence-framed copy, never threat-framed | unit | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` (milestone-award domain logic) plus `RithamCore/Scripts/test-core.sh --filter MomentumCopyTests` (banned-lexicon/framing gate) | ✅ | ✅ green |
| 03-04-T2 / 03-10-T1 | 03-04, 03-10 | 2 | MOMENTUM-06 | T-3-01, T-3-03, T-3-18, T-3-19 | Private-by-default visibility; no leaderboard surface; input-validated weekly-target picker; structural no-sharing gate over both feature directories | unit + source-grep | `Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/MomentumStoreTests` (target validation) plus `Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/Phase3CoverageTests` (no-sharing structural gate) | ✅ | ✅ green |
| 03-05-T1 / 03-09-T2 | 03-05, 03-09 | 2 | MOMENTUM-07 | T-3-15, T-3-16, T-3-17 | Daily Movement Snapshot carries no streak/shield/target reference (structurally, no FK) | unit | `Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/MovementSnapshotTests` | ✅ | ✅ green |
| 03-03-T1 / 03-05-T3 | 03-03, 03-05 | 1 | MOMENTUM-08 | T-3-04, T-3-08 | Self-reported injury flag auto-freezes streak; independent of sleep/Recovery Week (D-03) | unit | `RithamCore/Scripts/test-core.sh --filter MomentumReconciliationTests` | ✅ | ✅ green |
| 03-08-T3 | 03-08 | 2 | RECOVERY-01 | T-3-08, T-3-13, T-3-14 | Seven D-05 invariants (bar unchanged, lighter/declined sessions fully qualify, skip has zero effect, never auto-consumes shield/triggers Recovery Week, no differentiating messaging), applied uniformly per D-11 | unit + source-grep | `Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/RecoveryAdjustmentTests` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Automated commands use the repository's own stable entry points — `RithamCore/Scripts/test-core.sh` (the toolchain-adaptive core-package runner) and `Scripts/build-app.sh test` (which resolves an available iPhone simulator UDID dynamically) — rather than a hardcoded simulator model name, per this plan's (03-10) own correction of the prior placeholder commands above, which named a specific `iPhone 17` destination not guaranteed to exist on every machine, exactly the mistake `Scripts/build-app.sh`'s own header comment records the original 01-VALIDATION.md making.*

*Threat ref T-3-01: weekly-target/Settings input tampering (out-of-range value bypassing UI) — mitigated by `HealthDataStore.saveMomentumTarget` validating against a fixed `{2,3,4,5}` set and throwing, matching the existing `saveWeeklyFrequency` precedent.*

*Threat ref T-3-18: Spoofing via step registration (a placeholder presenter resolving the coverage gate while shipping a non-functional surface) — mitigated by `Phase3CoverageTests` asserting each of the three new steps' concrete presenter type and rejecting placeholder-looking type names.*

*Threat ref T-3-19: Repudiation via a silently unchecked roadmap criterion — mitigated by the dated `Household half deferred 2026-09-06` annotation on ROADMAP.md's Phase 3 criterion 5, recording MOMENTUM-06's partial delivery explicitly rather than leaving it unstated.*

---

## Wave 0 Requirements

- [x] `RithamCore/Tests/RithamCoreTests/MomentumWeekTests.swift` — covers MOMENTUM-03 boundary arithmetic, DST fixtures (explicit `TimeZone(identifier:)` values, never `.current`)
- [x] `RithamCore/Tests/RithamCoreTests/MomentumReconciliationTests.swift` — covers MOMENTUM-01/02/04/05/08, including idempotence (reconcile twice, assert identical output) and append-only/never-retract assertions
- [x] `RithamApp/RithamTests/MomentumStoreTests.swift` — covers `HealthDataStore` Momentum facade methods, MOMENTUM-06
- [x] `RithamApp/RithamTests/MovementSnapshotTests.swift` — covers MOMENTUM-07
- [x] `RithamApp/RithamTests/RecoveryAdjustmentTests.swift` — covers RECOVERY-01's seven invariants, one test per invariant
- [x] No new test framework install needed — Swift Testing is already the project standard

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Momentum screen visual framing never reads as threat/loss (no reset-to-zero animation, "Week 1 of your rebuilt streak" copy lands correctly) | MOMENTUM-05 (roadmap §4 framing) | Visual/tone judgment call, not assertable by a unit test | Deferred to the end-of-project batched physical-device/AX3-AX5 pass per PROJECT.md's 2026-09-06 decision — not a phase-3 close-out blocker |
| Milestone badge / shield iconography legibility at accessibility text sizes (AX3/AX5) | MOMENTUM-05 | Requires on-device/visual rendering judgment | Same batched end-of-project pass as above |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s (RithamCore suite)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** signed off 2026-09-06 (plan 03-10 close-out) — every Per-Task Verification Map row
carries a real plan/task identifier, a runnable repository-stable command, and a confirmed green
result (see commit history for this plan). Manual-only verifications remain correctly deferred to
the end-of-project batched pass per PROJECT.md's 2026-09-06 decision, not blocking this sign-off.
