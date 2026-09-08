---
phase: 03-momentum-recovery
verified: 2026-09-06T22:10:00Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "MOMENTUM-06's opt-in household/accountability-contact sharing half"
    addressed_in: "Phase 4 (HOUSEHOLD-01); accountability-contact tier stays HOUSEHOLD-02, out of scope to v2"
    evidence: "ROADMAP.md Phase 3 criterion 5's 2026-09-06 dated annotation: 'Phase 3 ships only the private-by-default half of MOMENTUM-06 ... The opt-in household half is not built here because Household does not exist until Phase 4.' 03-CONTEXT.md D-06/D-07 record the same scoped deferral, and Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance structurally enforces the private-only half that did ship."
  - truth: "Momentum screen visual framing never reads as threat/loss; milestone badge/shield iconography legible at AX3/AX5"
    addressed_in: "End-of-project batched physical-device/AX pass (PROJECT.md 2026-09-06 decision)"
    evidence: "03-VALIDATION.md 'Manual-Only Verifications' table explicitly defers both rows to the same batched pass Phase 1 and Phase 2 already deferred to; not a phase-3-specific gap."
human_verification:
  - test: "Re-derive (or re-run with a fresh fixture) the CR-01 addendum's restored-plus-earned-since-miss formula in MomentumReconciliation.swift:260-262 (`restored = max(1, streakBeforeMiss - 1); earnedSinceMiss = max(0, currentStreak - streakBeforeMiss); currentStreak = restored + earnedSinceMiss`) against a scenario of your own choosing that spans a missed week, its claim, and at least one independently-met week in the same reconcile call."
    expected: "The result must equal 'one less than the streak before the miss, plus every week earned after the miss' regardless of whether the claim and the later met week(s) are folded in one reconcile call or across several separate calls at different times (reconciliation-on-read must be timing-independent). It must never equal the raw pre-miss streak value verbatim, and never silently discard a met week's increment."
    why_human: "This is the exact spot 03-REVIEW-FIX.md itself flags: 'Status: fixed: requires human verification (logic fix ... this arithmetic contract is exactly the kind of change worth a second human read before this phase proceeds to verification, especially since it deviates from the addendum's literal suggested code.' I independently re-read the implementation, traced two regression tests (expiredUnclaimedWindowDoesNotRepeatedlyResetStreakOnLaterMetWeeks, claimingWindowInSameCallAsIndependentlyMetWeekDoesNotClobberHigherStreak in MomentumReconciliationTests.swift) and re-ran both full suites myself (RithamCore: 396/30 green; app: 389/49 green) rather than trusting the report's numbers — both pass and both assert the correct restored-plus-earned values. But the fixer's own stated reason for requesting sign-off is that the formula was derived by path-independence reasoning, not proven against an exhaustive scenario set, which a test suite pinning two chosen fixtures cannot fully rule out. A second human read of the reasoning (not just the passing tests) is what was asked for and has not yet happened."
  - test: "Confirm whether an already-resolved (expired-unclaimed) Comeback window can be reopened by a session whose startedAt is later added or edited into the window's original 3-day range."
    expected: "It should never be re-claimable once ComebackWindow.resolvedAt is set — resolution must be terminal."
    why_human: "MomentumReconciliation.swift:242's claim-branch guard is `ledger.comebackWindows[index].claimedAt == nil` only; it is not additionally gated on `resolvedAt == nil` the way the expiry branch (line 263) now is. I traced this by hand: `qualifyingRefs` is built only from `sortedElapsedWeeks` (weeks after `MomentumSummaryReader`'s anchor) plus `currentWeek`, and `MomentumSummary.summary(now:)` always sets `startWeek` to `nextWeekStart(after: lastReconciledWeekStart)`, so an already-fully-processed week's sessions are normally never reconsidered — this closes off the obvious path. The one path I found that could still resurrect a resolved window is a session whose `startedAt` is retroactively backdated into the window's original date range *after* the window already resolved (a STRENGTH-05-style edit), which would reintroduce that week's data into `qualifyingRefs` on a later call and re-fire the ungated claim branch. I confirmed `SessionEditView`/`SessionEditModel` (the only retroactive-date-edit surface in the codebase) is built and unit-tested but has no navigation entry point from `StrengthHistoryView` (see `.planning/todos/pending/` — 'SessionEditView built and tested but not reachable from StrengthHistoryView'), so this path is not reachable in the shipped app today — the same 'not reachable given current constants' shape as the review's own accepted IN-01 finding. It becomes reachable the day that todo is closed, with no change needed in this phase's own files. Flagging for a human decision on whether to add a `resolvedAt == nil` guard to the claim branch now (cheap, defensive) or accept the same deferred-risk posture IN-01 already uses."
---

# Phase 3: Momentum & Recovery Verification Report

**Phase Goal:** Users build one fair, cross-modality weekly consistency habit that forgives real life — rest, injury, and bad sleep — without ever punishing them for it.
**Verified:** 2026-09-06
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A qualifying cardio (10+ min) or lift (3+ working sets / 2+ exercises) session counts equally toward one shared weekly Momentum target (default 3, adjustable 2-5); manual sessions labeled distinct from sensor-verified; week one starts pre-filled at 1/3; milestone badge + bonus shield at 4/12/26/52 weeks. | ✓ VERIFIED | `MomentumReconciliation.qualifyingSessionCount` weighs cardio/lift identically via the already-shipped `CardioQualification`/`LiftQualification` evaluators (`MomentumReconciliation.swift:79-83`). `MomentumTarget.supported == [2,3,4,5]`, `defaultTarget == 3` (`MomentumTarget.swift:26,29`). D-10's endowed credit: `requiredQualifyingSessions(target:endowedCredit:) == max(1, target - endowedCredit)`, `displayedCount` floors the week-one display at 1 (`MomentumTarget.swift:43-60`), independently confirmed by reading the code (not just the docstring). Manual-vs-sensor labeling: `MomentumSummary.swift:328-330` maps `session.source.isSensorVerified` to `MomentumCopy.Verification.sensorVerified`/`manuallyEntered`; a real, passing test (`MomentumViewTests.swift:155-173` `aCardioRowShowsItsVerificationLabelAndALiftRowShowsNone`) asserts both labels render and a lift row carries none. Milestones: `MomentumReconciliation.swift:181-189` awards at `MomentumMilestone.tiers = [4,12,26,52]` plus a bonus shield, contains-checked so never re-awarded (regression-tested in `MomentumReconciliationTests.swift`). |
| 2 | A missed week (no guardrail, no shield) is restored via a single 3-day Comeback Session, restoring the streak minus one (never to zero); a self-reported pain/injury flag can auto-freeze the streak; weekly reset is Monday 3am local, not midnight Sunday. | ✓ VERIFIED — pending human sign-off on restoration arithmetic (see Human Verification) | `MomentumReconciliation.comebackWindowDays == 3` (`MomentumReconciliation.swift:71`). Claim branch computes `restored = max(1, streakBeforeMiss - 1)` — the "minus one, floor one, never to nothing" guarantee (`MomentumReconciliation.swift:260`). `MomentumSummary.flagInjury(now:)` is a user-initiated, separate store call (`MomentumSummary.swift:273-274`), read via `isCurrentlyInjuryFrozen` and honored by `outcome(for:ledger:guardrails:)`'s guardrail-first precedence (`MomentumReconciliation.swift:97-107`). `MomentumWeek.weekStart` computes the Monday-3am-local boundary with dedicated DST fixture tests (`MomentumWeekTests.swift`). Both full test suites (RithamCore 396/30, app 389/49) independently re-run by this verifier are green, including `MomentumReconciliationTests` and the two CR-01 regression tests. **However**, the fix report itself (`03-REVIEW-FIX.md` line 33) explicitly requests a second human read of this exact restoration formula before the phase proceeds — see Human Verification below. |
| 3 | Shields accrue automatically (1/4 consecutive weeks, stacks to 3), never purchasable; a user-initiated Recovery Week flag pauses the target without breaking the streak and is never auto-triggered. | ✓ VERIFIED | `MomentumLedger.weeksPerShield == 4`, `maxShields == 3` (`MomentumLedger.swift:209,212`). No purchase/IAP code exists anywhere under `Momentum/` (grepped, zero hits). `MomentumSummary` exposes `flagRecoveryWeek`/similar as an explicit user-initiated write with no automatic call site anywhere in the read path (`MomentumSummary.swift` — the reconciliation read path only ever *reads* `recoveryWeeks`/`injuryFreezes`, never appends to them). `MomentumView.swift:186-199` renders the Recovery Week control behind its own confirmation alert, structurally separate from the injury row (lines 218-232). |
| 4 | A Poor sleep check-in shifts the suggested session lighter; accepting it, declining it, or skipping the check-in all fully qualify identically; no session is ever flagged harder/easier. | ✓ VERIFIED | `RecoveryAdjustmentTests.swift` has one named test per D-05 invariant (`theQualificationBarIsUnchangedByAnySleepState`, `aLighterSuggestedSessionThatMeetsTheBarFullyQualifies`, `decliningTheLighterSuggestionIsAlwaysAvailableAndFullyQualifies`, `skippingTheCheckInHasZeroEffect`, `theAdjustmentNeverConsumesAShield`, `theAdjustmentNeverTriggersARecoveryWeek`, `noMessagingDifferentiatesTrainingHarderThanSuggested`, `theWorkoutPlanRequestStillCarriesExactlyThreeFields`) — all pass in the independently re-run full suite. `SleepAdjustment.swift`'s domain type structurally has no shield/streak/target/Recovery-Week member (D-03), confirmed by reading the file: only `id`, `day`, `quality`, `note`. |
| 5 | No streak-loss animation or threat-framed message ever appears; streak/shield visibility is private-by-default with only opt-in household sharing (never a public leaderboard); a separate optional Daily Movement Snapshot carries no streak/shield/target. | ✓ VERIFIED (household-sharing half correctly recorded as a scoped deferral, not a gap — see Deferred Items) | `MomentumCopyTests.swift` enforces a banned-lexicon gate against threat-framed copy (confirmed present, passing). `MomentumVisibility` enum's only case is `.privateToDevice` (`MomentumLedger.swift:17-223`). `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance` (`Phase3CoverageTests.swift:96-143`) walks the `Momentum/` and `MovementSnapshot/` directories on disk and asserts zero occurrences of `ShareLink`/`UIActivityViewController`/`UIPasteboard` outside comments, with a non-vacuous-pass guard (`scannedFiles.count > 0`) — this test passed in the independently re-run full suite. Movement Snapshot's own feature directory imports no Momentum type (confirmed by reading `MovementSnapshotView.swift`/`MovementSnapshotToggleView.swift`/`MovementSnapshotRegistration.swift` — no streak/shield/target/milestone symbol anywhere). |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified). Status is `human_needed` because of two flagged items below, not because any truth failed or lacks test coverage. (Requirements Coverage below separately tracks all 9 requirement IDs — MOMENTUM-01 through 08, RECOVERY-01 — as a different axis.)

### Deferred Items

Items not yet met in this phase but explicitly, dated-ly addressed as scoped deferrals elsewhere — not actionable gaps.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | MOMENTUM-06's opt-in household/accountability-contact sharing half | Phase 4 (HOUSEHOLD-01); accountability-contact tier stays HOUSEHOLD-02, permanently out of v2 scope | ROADMAP.md Phase 3 criterion 5's 2026-09-06 dated annotation; 03-CONTEXT.md D-06/D-07 |
| 2 | Momentum screen visual/threat-framing judgment and AX3/AX5 iconography legibility | End-of-project batched physical-device/AX pass | 03-VALIDATION.md "Manual-Only Verifications" table; PROJECT.md 2026-09-06 decision; same posture Phase 1/2 already used |

### Required Artifacts (spot-checked across all 10 plans)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `RithamCore/Sources/RithamCore/Momentum/MomentumWeek.swift` | DST-safe Monday-3am boundary | ✓ VERIFIED | Exists, substantive, covered by `MomentumWeekTests.swift`, used by `MomentumReconciliation`/`MomentumSummary`. |
| `RithamCore/Sources/RithamCore/Momentum/MomentumTarget.swift` | Weekly target rules + D-10 endowed credit | ✓ VERIFIED | Read in full; matches D-10 exactly (see truth #1 evidence). |
| `RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift` | Ledger value types incl. visibility scope | ✓ VERIFIED | `MomentumVisibility` enum present, `.privateToDevice` only case; `resolvedAt` field present on `ComebackWindow` (CR-01 fix). |
| `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift` | Lazy, idempotent, append-only fold | ✓ VERIFIED | Read in full; guardrail-before-shield ordering, anchor-gated idempotence, CR-01 fix (resolvedAt gate + delta-form restoration) all present as described in 03-REVIEW-FIX.md. |
| `RithamCore/Sources/RithamCore/Momentum/SleepAdjustment.swift` | Pure sleep decision rule, D-03 isolation | ✓ VERIFIED | No shield/streak/target/Recovery-Week member; confirmed by reading. |
| `RithamCore/Sources/RithamCore/Copy/MomentumCopy.swift` | Single copy catalog incl. bonus-shield note (WR-01 fix) | ✓ VERIFIED | `Milestones.bonusShieldNote` present and rendered in `MomentumView.swift:159`. |
| `RithamApp/Ritham/Persistence/MomentumStateRecord.swift`, `MomentumLedgerRecords.swift` | SwiftData persistence, append-only, no network refs | ✓ VERIFIED | `resolvedAt` column added and threaded through `saveMomentumLedger`'s update branch (CR-01 fix, all 3 layers). |
| `RithamApp/Ritham/Persistence/HealthDataStore.swift` | Load/save facade, target validation | ✓ VERIFIED | `resolvedAt`-guarded upsert; WR-03 error-surfacing fix present (`momentumLoadFailed`/`loadFailed` states in `HomeHubView`/`MovementSnapshotView`). |
| `RithamApp/Ritham/Momentum/MomentumSummary.swift` | Standalone reconciliation-on-read driver | ✓ VERIFIED | Anchor-based `elapsedWeeks` construction confirmed by reading; user-initiated guardrail actions confirmed separate from the read path. |
| `RithamApp/Ritham/Momentum/Views/MomentumView.swift` + components | Momentum detail screen, no ring/lime/red, two separate guardrail rows | ✓ VERIFIED | Separate Recovery-Week/injury rows with separate alerts (`MomentumView.swift:186-232`). |
| `RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift` | Settings target picker, fixed-choice only | ✓ VERIFIED | Adapted from `WorkoutFrequencyView` per plan; tested in `MomentumTargetPickerTests.swift`. |
| `RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift` | Sleep check-in screen, no streak/shield mention | ✓ VERIFIED | Covered by `RecoveryAdjustmentTests.theSleepScreenMentionsNoMomentumState`. |
| `RithamApp/Ritham/MovementSnapshot/*` | Opt-in toggle + calendar, structurally Momentum-free | ✓ VERIFIED | CR-02 month-range off-by-one fixed (`interval.end.addingTimeInterval(-0.001)`, `MovementSnapshotView.swift:180`); regression test `sessionOnLastDayOfMonthMarksThatDay` present. |
| `RithamApp/RithamTests/Phase3CoverageTests.swift` | Step-resolution + no-sharing structural gate | ✓ VERIFIED | Read in full; non-vacuous-pass guarded, all four tests pass in the independently re-run suite. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `MomentumReconciliation.reconcile` | `MomentumSummary.summary(now:)` | Single call, output persisted verbatim | ✓ WIRED | `MomentumSummary.swift:198-209`. |
| `MomentumSummaryReader` | `HomeHubView` / `MomentumView` | Both call the same standalone reader (D-08) | ✓ WIRED | Confirmed both views read `MomentumSummaryReader`, no second data path. |
| `SleepAdjustment.shift(for:)` | `RecommendationsView`'s `RecommendationsModel` | Client-side post-processing over the existing plan | ✓ WIRED | Confirmed via `RecoveryAdjustmentTests`'s passing invariant suite exercising the wrapped model. |
| `HealthDataStore.saveMomentumLedger` | `MomentumLedgerRecords`/`MomentumStateRecord` | Append-only upsert, never delete | ✓ WIRED | `resolvedAt` persistence round-trip additionally covered by `resolvedAtSurvivesSaveAndReload` (`MomentumStoreTests.swift:182`), confirmed present and passing. |
| `MomentumTarget.supported` | `HealthDataStore.supportedMomentumTargets` / `MomentumTargetView` | Single source of truth, pinned by test | ✓ WIRED | Per plan 03-01/03-07's stated key link; consistent `{2,3,4,5}` used throughout. |

### Behavioral Spot-Checks / Test Runs (independently executed by this verifier, not taken from SUMMARY/REVIEW-FIX claims)

| Suite | Command | Result | Status |
|-------|---------|--------|--------|
| RithamCore full suite | `bash RithamCore/Scripts/test-core.sh` | "Test run with 396 tests in 30 suites passed" (exit 0), incl. `MomentumReconciliationTests`, `MomentumWeekTests`, `MomentumLedgerTests`, `MomentumCopyTests`, `SleepAdjustmentTests` | ✓ PASS |
| RithamApp full suite | `bash Scripts/build-app.sh test` | "Test run with 389 tests in 49 suites passed" / `** TEST SUCCEEDED **` (exit 0), incl. `Phase3CoverageTests`, `MomentumStoreTests`, `MomentumSummaryTests`, `MomentumTargetPickerTests`, `MomentumViewTests`, `MovementSnapshotTests`, `MovementSnapshotViewTests`, `RecoveryAdjustmentTests` | ✓ PASS |

Both counts match 03-REVIEW-FIX.md's claimed numbers exactly, but these were re-run fresh by this verifier in its own process rather than trusted from the report.

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|-------------|----------------|--------|----------|
| MOMENTUM-01 | 03-01, 03-03, 03-05, 03-06, 03-07 | ✓ SATISFIED | Truth #1 |
| MOMENTUM-02 | 03-03, 03-04, 03-06 | ✓ SATISFIED | Truth #3 |
| MOMENTUM-03 | 03-01, 03-04, 03-05, 03-06, 03-07 | ✓ SATISFIED | Truths #2, #3 |
| MOMENTUM-04 | 03-03, 03-04, 03-06 | ✓ SATISFIED (formula flagged for human sign-off, see above) | Truth #2 |
| MOMENTUM-05 | 03-02, 03-03, 03-04, 03-06, 03-10 | ✓ SATISFIED | Truth #1, WR-01 fix |
| MOMENTUM-06 | 03-01, 03-04, 03-06, 03-07, 03-10 | ✓ SATISFIED (private half); household half correctly deferred | Truth #5, Deferred #1 |
| MOMENTUM-07 | 03-05, 03-09 | ✓ SATISFIED | 03-09 artifacts |
| MOMENTUM-08 | 03-03, 03-04, 03-05, 03-06 | ✓ SATISFIED | Truth #2 |
| RECOVERY-01 | 03-02, 03-05, 03-08 | ✓ SATISFIED | Truth #4 |

No orphaned requirements — every ID in ROADMAP.md's Phase 3 requirement list (MOMENTUM-01 through 08, RECOVERY-01) is declared in at least one plan's `requirements:` frontmatter, and REQUIREMENTS.md's traceability table marks all nine `Complete`/Phase 3.

### Anti-Patterns Found

None. Grepped all 24 source files touched by this phase's plans plus the code review for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|not yet implemented|coming soon` — zero hits. No stub returns, no hardcoded-empty props flowing to render, no debt markers.

### Code Review / Fix Verification (independent re-check, not trusting 03-REVIEW-FIX.md's narrative)

- **CR-01** (expired-unclaimed Comeback window permanently re-zeroing the streak): Fix independently confirmed correctly applied across all three required layers — `ComebackWindow.resolvedAt` (domain, `MomentumLedger.swift:67`), `ComebackWindowRecord.resolvedAt` (persisted column, `MomentumLedgerRecords.swift:65`), and `HealthDataStore.saveMomentumLedger`'s guarded update (`HealthDataStore.swift:682-683`). The expiry branch is correctly gated on `window.resolvedAt == nil` (`MomentumReconciliation.swift:263`). The addendum's claim-branch clobber is fixed with the documented delta-form (`restored + earnedSinceMiss`, `MomentumReconciliation.swift:260-262`), which I traced by hand and confirms path-independence for the one scenario the regression test exercises — see Human Verification for the residual sign-off request.
- **CR-02** (Movement Snapshot last-day-of-month never marked): Fix independently confirmed applied (`MovementSnapshotView.swift:180`, `interval.end.addingTimeInterval(-0.001)`), matching the `MomentumWeek.weekRange` convention exactly as the review suggested.
- **WR-01** (double shield grant at milestone weeks): Confirmed intentional per REQUIREMENTS.md (MOMENTUM-02 + MOMENTUM-05 are independent always-on requirements); copy fix (`bonusShieldNote`) confirmed present and rendered.
- **WR-02** (shield-accrual counter asymmetry): Confirmed documented via code comment only, no behavior change, as the fix report states.
- **WR-03** (silent `try?` swallowing): Confirmed fixed at both cited call sites (`HomeHubView.onAppear`, `MovementSnapshotView.loadCurrentMonth`); `HomeHubView`'s snapshot-opt-in read left as a documented, narrower-scope silent fallback per the fix report's own stated rationale.
- **IN-01** (comeback-window double-claim, no action required): Confirmed still not reachable given `comebackWindowDays == 3` and week length unchanged; no comment was added, matching the fix report's "no action required" disposition. During this verification I found a related, currently-unreachable gap in the same neighborhood — the claim branch is not gated on `resolvedAt` the way the expiry branch now is — flagged in Human Verification above as a new finding, not part of the original review's scope.

### Human Verification Required

See frontmatter `human_verification` above for the two items in full (CR-01 restoration-formula second read; claim-branch `resolvedAt` gating gap). Both are traced with specific file/line evidence and a concrete test/expected/why-human breakdown per the required format.

### Gaps Summary

No blocking gaps. Every roadmap Success Criterion and every plan-declared must-have has direct code and test evidence, independently re-verified rather than taken from SUMMARY.md/03-REVIEW-FIX.md claims (including re-running both full test suites myself: 396/30 and 389/49, both green). The phase's status is `human_needed`, not `passed`, solely because (1) the fix report itself explicitly asks for a second human read of CR-01's core streak-restoration arithmetic before the phase is considered fully closed, and (2) this verification surfaced one additional, currently-unreachable latent gap in the same fix's claim-branch gating that a human should decide whether to close now or accept as a documented, deferred risk (mirroring the review's own accepted IN-01 disposition).

---

*Verified: 2026-09-06*
*Verifier: Claude (gsd-verifier)*
