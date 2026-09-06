---
phase: 3
slug: momentum-recovery
status: draft
nyquist_compliant: true
wave_0_complete: false
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
| **Quick run command** | `cd RithamCore && swift test --filter MomentumTests` |
| **Full suite command** | `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17'` |
| **Estimated runtime** | ~5-15s (RithamCore swift test), ~2-5min (full xcodebuild suite) |

---

## Sampling Rate

- **After every task commit:** `cd RithamCore && swift test` (pure-domain suite; fast, no simulator boot required for most of this phase's logic)
- **After every plan wave:** `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RithamTests/<NewSuite>` for each new suite individually — avoid a full-target run mid-phase per the `StepRegistry` race precedent (Pitfall 5)
- **Before `/gsd-verify-work`:** Full-target `xcodebuild test` (no `-only-testing:` filter) green before declaring the phase done, matching 02-16's precedent
- **Max feedback latency:** ~15s per task (RithamCore suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD-01 | TBD | 1 | MOMENTUM-01 | — | Qualifying cardio/lift session counted equally; manual-vs-sensor labeled; endowed head start (D-10) | unit | `cd RithamCore && swift test --filter MomentumTests` | ❌ W0 | ⬜ pending |
| TBD-02 | TBD | 1 | MOMENTUM-02 | — | Shield accrual (1/4 weeks, stacks to 3), never purchasable, auto-applies on miss via reconciliation-on-read | unit | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ W0 | ⬜ pending |
| TBD-03 | TBD | 1 | MOMENTUM-03 | — | Monday 3am local reset boundary incl. DST fixtures; Recovery Week user-initiated only, retroactive whole-week pause (D-12) | unit | `cd RithamCore && swift test --filter MomentumWeekTests` | ❌ W0 | ⬜ pending |
| TBD-04 | TBD | 1 | MOMENTUM-04 | — | Comeback Session within 3 days restores streak minus one, never to zero | unit | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ W0 | ⬜ pending |
| TBD-05 | TBD | 1 | MOMENTUM-05 | — | Milestones at 4/12/26/52 weeks, never re-derived away after retroactive session edit | unit | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ W0 | ⬜ pending |
| TBD-06 | TBD | 2 | MOMENTUM-06 | T-3-01 | Private-by-default visibility; no leaderboard surface; input-validated weekly-target picker | unit + source-grep | `xcodebuild test -only-testing:RithamTests/MomentumStoreTests` | ❌ W0 | ⬜ pending |
| TBD-07 | TBD | 2 | MOMENTUM-07 | — | Daily Movement Snapshot carries no streak/shield/target reference (structurally, no FK) | unit | `xcodebuild test -only-testing:RithamTests/MovementSnapshotTests` | ❌ W0 | ⬜ pending |
| TBD-08 | TBD | 1 | MOMENTUM-08 | — | Self-reported injury flag auto-freezes streak; independent of sleep/Recovery Week (D-03) | unit | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ W0 | ⬜ pending |
| TBD-09 | TBD | 2 | RECOVERY-01 | — | Seven D-05 invariants (bar unchanged, lighter/declined sessions fully qualify, skip has zero effect, never auto-consumes shield/triggers Recovery Week, no differentiating messaging), applied uniformly per D-11 | unit + source-grep | `xcodebuild test -only-testing:RithamTests/RecoveryAdjustmentTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Threat ref T-3-01: weekly-target/Settings input tampering (out-of-range value bypassing UI) — mitigated by `HealthDataStore.saveMomentumTarget` validating against a fixed `{2,3,4,5}` set and throwing, matching the existing `saveWeeklyFrequency` precedent.*

---

## Wave 0 Requirements

- [ ] `RithamCore/Tests/RithamCoreTests/MomentumWeekTests.swift` — covers MOMENTUM-03 boundary arithmetic, DST fixtures (explicit `TimeZone(identifier:)` values, never `.current`)
- [ ] `RithamCore/Tests/RithamCoreTests/MomentumReconciliationTests.swift` — covers MOMENTUM-01/02/04/05/08, including idempotence (reconcile twice, assert identical output) and append-only/never-retract assertions
- [ ] `RithamApp/RithamTests/MomentumStoreTests.swift` — covers `HealthDataStore` Momentum facade methods, MOMENTUM-06
- [ ] `RithamApp/RithamTests/MovementSnapshotTests.swift` — covers MOMENTUM-07
- [ ] `RithamApp/RithamTests/RecoveryAdjustmentTests.swift` — covers RECOVERY-01's seven invariants, one test per invariant
- [ ] No new test framework install needed — Swift Testing is already the project standard

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Momentum screen visual framing never reads as threat/loss (no reset-to-zero animation, "Week 1 of your rebuilt streak" copy lands correctly) | MOMENTUM-05 (roadmap §4 framing) | Visual/tone judgment call, not assertable by a unit test | Deferred to the end-of-project batched physical-device/AX3-AX5 pass per PROJECT.md's 2026-09-06 decision — not a phase-3 close-out blocker |
| Milestone badge / shield iconography legibility at accessibility text sizes (AX3/AX5) | MOMENTUM-05 | Requires on-device/visual rendering judgment | Same batched end-of-project pass as above |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s (RithamCore suite)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
