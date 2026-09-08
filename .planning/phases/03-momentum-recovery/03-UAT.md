---
status: testing
phase: 03-momentum-recovery
source: [03-VERIFICATION.md]
started: 2026-09-08T07:29:31.098Z
updated: 2026-09-08T07:29:31.098Z
---

## Current Test

number: 1
name: Re-derive the CR-01 restored-plus-earned-since-miss streak formula against a scenario of your own choosing
expected: |
  The result must equal "one less than the streak before the miss, plus every week earned after
  the miss" regardless of whether the claim and the later met week(s) are folded in one
  `reconcile` call or across several separate calls at different times (reconciliation-on-read
  must be timing-independent). It must never equal the raw pre-miss streak value verbatim, and
  never silently discard a met week's increment.

  Evidence already gathered (not a substitute for your own read — the fix report specifically
  asked for a second human pass on the reasoning, not just passing tests):

  `MomentumReconciliation.swift:260-262`:
  ```swift
  let restored = max(1, window.streakBeforeMiss - 1)
  let earnedSinceMiss = max(0, ledger.currentStreak - window.streakBeforeMiss)
  ledger.currentStreak = restored + earnedSinceMiss
  ```

  Worked proof (orchestrator, cross-checked against the regression test's exact numbers):
  - Base case: `streakBeforeMiss = 5`, no met weeks yet at the moment of claim → `ledger.currentStreak`
    still reads `5` (the `.missed` branch deliberately leaves it untouched) → `earnedSinceMiss =
    max(0, 5-5) = 0` → `restored = max(1, 5-1) = 4` → total `4`. Matches the pre-existing base-case
    test `claimingAComebackRestoresTheStreakToOneLessNeverToNothing` (expects `4`).
  - Clobber case: `streakBeforeMiss = 5`, one independently-`.met` week folds after the miss in the
    *same* `reconcile` call before the resolution pass runs → `ledger.currentStreak = 6` at
    resolution time → `earnedSinceMiss = max(0, 6-5) = 1` → `restored = 4` → total `5`. Matches the
    new regression test `claimingWindowInSameCallAsIndependentlyMetWeekDoesNotClobberHigherStreak`
    (expects `5`, explicitly not `4` naive-restore or `6` naive-keep-fold-value).
  - Path-independence check: splitting the above into two separate `reconcile` calls (call 1 folds
    only the miss; call 2, later, folds the met week and then resolves the claim) yields the same
    arithmetic — `window.streakBeforeMiss` is persisted at `5` from call 1, call 2's fold raises
    `ledger.currentStreak` to `6` before its own resolution pass runs, producing the identical `4 +
    1 = 5`. Confirms the formula is genuinely timing-independent, not just correct for one fixture.

  Both full suites were independently re-run (not trusted from the fix/verification reports) and
  are green: `RithamCore/Scripts/test-core.sh` (396 tests/30 suites), `Scripts/build-app.sh test`
  (389 tests/49 suites).
awaiting: user response

## Tests

### 1. Re-derive the CR-01 restored-plus-earned-since-miss streak formula against a scenario of your own choosing
expected: The result must equal "one less than the streak before the miss, plus every week earned
  after the miss," independent of whether the claim and later met week(s) are folded in one
  `reconcile` call or split across several later calls. Never the raw pre-miss value verbatim;
  never a silently discarded met-week increment. See "Current Test" above for the worked proof
  already on record — this test is a sanity-check of that reasoning, not a from-scratch derivation.
result: [pending]

### 2. Confirm an already-resolved (expired-unclaimed) Comeback window can never be reopened by a later-added or retroactively-edited session
expected: Once `ComebackWindow.resolvedAt` is set, resolution must be terminal — no session dated
  into the window's original 3-day range should ever be able to re-fire the claim branch after the
  fact.
result: [pending]
notes: |
  `MomentumReconciliation.swift:242`'s claim-branch guard is `claimedAt == nil` only — it is not
  additionally gated on `resolvedAt == nil` the way the sibling expiry branch (line 263) now is.
  Traced by hand: this is NOT reachable in the shipped app today. `MomentumSummary.summary(now:)`
  always advances `startWeek` from `lastReconciledWeekStart`'s anchor, so an already-processed
  week's sessions are never normally reconsidered. The one path that could resurrect a resolved
  window is a session whose `startedAt` is retroactively backdated into the window's original date
  range *after* the window resolved — and the only surface that could do that, `SessionEditView`
  (built and unit-tested), has **no navigation entry point** from `StrengthHistoryView` today. That
  gap is tracked separately: `.planning/todos/pending/2026-09-06-session-edit-view-not-wired-into-history.md`.

  This is the same "not reachable given current constants" shape the code review itself accepted
  for finding IN-01 (comeback-window double-claim across overlapping windows) — a documented,
  non-blocking invariant rather than a live bug.

  Decision needed: add a defensive `resolvedAt == nil` guard to the claim branch now (cheap, and
  removes the coupling to the other todo entirely), or accept the same deferred-risk posture IN-01
  already uses and revisit only when the SessionEditView wiring todo is closed. Note that tightening
  the guard now is itself a semantics decision (should a backdated edit into an already-resolved
  window ever be claimable at all?) that hasn't been reviewed — a test written to lock in an answer
  before that review would bake in an unreviewed choice.

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
