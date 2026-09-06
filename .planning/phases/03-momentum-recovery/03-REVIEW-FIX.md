---
phase: 03-momentum-recovery
fixed_at: 2026-09-06T16:11:07Z
review_path: .planning/phases/03-momentum-recovery/03-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-09-06T16:11:07Z
**Source review:** .planning/phases/03-momentum-recovery/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (fix_scope: critical_warning — CR-01, CR-02, WR-01, WR-02, WR-03; IN-01 excluded)
- Fixed: 5
- Skipped: 0

Both required test suites are green after all five fixes plus the follow-up CR-01 persistence round-trip test:
- `RithamCore/Scripts/test-core.sh`: 396 tests passed, 30 suites
- `Scripts/build-app.sh test`: 389 tests passed, 49 suites (`** TEST SUCCEEDED **`)

## Fixed Issues

### CR-01: An expired, unclaimed Comeback window permanently and repeatedly resets the streak to zero on every future reconciliation

**Files modified:** `RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift`, `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift`, `RithamApp/Ritham/Persistence/MomentumLedgerRecords.swift`, `RithamApp/Ritham/Persistence/HealthDataStore.swift`, `RithamCore/Tests/RithamCoreTests/MomentumReconciliationTests.swift`, `RithamApp/RithamTests/MomentumStoreTests.swift`
**Commits:** `9c7e7ae` (fix), `3fe745e` (follow-up persistence round-trip regression test)
**Status:** fixed: requires human verification (logic fix — see verification note below)

**Applied fix — primary bug:** Added `ComebackWindow.resolvedAt: Date?` (set exactly once, on claim or on unclaimed expiry), threaded through `ComebackWindowRecord` (new persisted column, default `nil`, no schema migration needed) and `HealthDataStore.saveMomentumLedger`'s in-place-update branch (writes `resolvedAt` only while the stored row's own `resolvedAt` is still `nil`, mirroring the existing `claimedAt` guard). Gated the `now >= window.closesAt` expiry branch in `MomentumReconciliation.reconcile` on `window.resolvedAt == nil`, so the `currentStreak = 0` transition applies exactly once per window instead of re-firing on every future `reconcile` call.

**Applied fix — addendum's claim-branch clobber (deviation from the addendum's literal snippet, documented per instructions):** The addendum suggested `ledger.currentStreak = max(ledger.currentStreak, max(1, window.streakBeforeMiss - 1))`. Empirically, this literal formula breaks the pre-existing base-case test (`claimingAComebackRestoresTheStreakToOneLessNeverToNothing`, expects `4`): after the `.missed` branch, `ledger.currentStreak` still reads exactly `window.streakBeforeMiss` (the branch deliberately leaves it untouched), so `max(streakBeforeMiss, streakBeforeMiss - 1)` always returns `streakBeforeMiss`, never applying the intended "minus one" restoration at all.

Replaced with a delta form that is provably path-independent (checked against two equivalent reconciliation timings for the same underlying history — claiming via a `currentWeek` session before the next week folds as met, vs. one call spanning both the miss and that same week's met fold — both must produce the same streak, since reconciliation-on-read cannot let the *timing* of a read change the outcome):

```swift
let restored = max(1, window.streakBeforeMiss - 1)
let earnedSinceMiss = max(0, ledger.currentStreak - window.streakBeforeMiss)
ledger.currentStreak = restored + earnedSinceMiss
```

`earnedSinceMiss` is `0` in the base case (matches existing tests exactly) and correctly carries forward any met-week increments the same fold pass already applied after the miss (new addendum regression test, corrected to assert `5`, not `6`, per the path-independence check).

**Regression tests added:**
- `expiredUnclaimedWindowDoesNotRepeatedlyResetStreakOnLaterMetWeeks` — reconciles across an expired-unclaimed window, then reconciles again with three new met weeks appended (sessions dated past the window's `closesAt` so the expiry path, not the claim path, is exercised); asserts `currentStreak == 3`, not pinned at `0`.
- `claimingWindowInSameCallAsIndependentlyMetWeekDoesNotClobberHigherStreak` — a single `reconcile` call spanning both a missed week and a subsequent independently-met week whose qualifying session also claims the window; asserts `currentStreak == 5` (restored-plus-earned), not `4` (naive restore) or `6` (naive keep-fold-value).

**Persistence round-trip coverage:** The review's own Fix section warned that a `resolvedAt` field persisted incorrectly (e.g. only on the domain struct, or nested inside the wrong `if`) would silently regress after the next app relaunch, and `MomentumReconciliationTests` alone cannot detect that class of bug — it only proves the gate works in-process against an in-memory ledger. Added `resolvedAtSurvivesSaveAndReload` (`MomentumStoreTests.swift`, commit `3fe745e`): saves a ledger with an already-resolved window, reloads it via a fresh `loadMomentumLedger()` call (not the in-memory value), then reconciles that freshly-reloaded ledger with a new met week and asserts the streak reads `1`, not re-zeroed. This is the full save→reload→reconcile path, not just the fold.

**Verification note:** Marked `requires human verification` per this fixer's verification strategy, since this is a logic fix (not just syntax) touching the core streak-computation formula. The delta-form fix was derived and cross-checked via path-independence reasoning against two equivalent reconciliation timings, and all regression tests plus the full existing suite (396 RithamCore tests, 389 app tests) pass — but the underlying arithmetic contract (restored-plus-earned-since-miss) is exactly the kind of change worth a second human read before this phase proceeds to verification, especially since it deviates from the addendum's literal suggested code.

### CR-02: The Daily Movement Snapshot calendar never marks the last day of a displayed month, even when activity was logged on it

**Files modified:** `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift`, `RithamApp/RithamTests/MovementSnapshotViewTests.swift`
**Commit:** `0b88e96`
**Status:** fixed

**Applied fix:** `monthRange(containing:calendar:)`'s upper bound was midnight at the *start* of the month's last day; changed to `interval.end.addingTimeInterval(-0.001)` (one millisecond before the start of the following month), mirroring `MomentumWeek.weekRange`'s existing `-0.001`-second convention exactly, as the review's Fix section suggested. Verified the day-cursor loop in `HealthDataStore.movementSnapshotDays(in:)` is unaffected (its `endDay = calendar.startOfDay(for: range.upperBound)` derivation still resolves to the same calendar day).

**Regression test added:** `sessionOnLastDayOfMonthMarksThatDay` — uses a fixed month (January 2026, 31 days) rather than "today," with a session logged at 09:00 on the last day; asserts it is marked. Deterministic regardless of which day of the month the suite runs on, unlike the existing `monthWithCardioSessionMarksExactlyThatDay` (which the review flagged as a latent calendar-dependent flake — now passes for the right reason on any day, including the last day of a month).

### WR-01: A milestone-tier week grants a shield twice, seemingly independent of the shipped "shields build after 4 consecutive weeks" copy

**Files modified:** `RithamCore/Sources/RithamCore/Copy/MomentumCopy.swift`, `RithamApp/Ritham/Momentum/Views/MomentumView.swift`, `RithamCore/Tests/RithamCoreTests/MomentumCopyTests.swift`
**Commit:** `5380cda`
**Status:** fixed

**Applied fix:** Per the orchestrator's addendum (confirmed against `REQUIREMENTS.md`: MOMENTUM-02 + MOMENTUM-05 are independent, always-on requirements, and week 4 is the first tier of both), applied **option (b) only** — added `MomentumCopy.Milestones.bonusShieldNote` explaining the milestone bonus shield mechanism, rendered in `MomentumView` alongside the milestones section (shown regardless of whether any milestone is earned yet, since it applies to every future tier). Did **not** collapse the double grant (option a was explicitly excluded by the addendum). Added the new string to `MomentumCopyTests`'s `shippedStrings` catalog and bumped the accounting-count assertion from 47 to 48.

**Deviation from the finding's cited line (documented per instructions):** The finding's **File:** line points at `MomentumCopy.swift:183` (`Empty.noShieldsBody`) and its Issue text says that string "states only one mechanism." That line is left unchanged. `noShieldsBody` only renders when `shieldCount == 0` — i.e. it is structurally unreachable at the exact moment the double grant becomes visible (the week the user reaches 4, `shieldCount` is 2, not 0). Editing that string would not have fixed the actual user-facing gap the finding describes. The new `bonusShieldNote` is instead rendered as a persistently-visible caption next to the milestones section, which *is* visible when a milestone (and its bonus shield) has just landed. Flagging this explicitly since a future review diffing line 183 in isolation would find it unchanged and could re-raise WR-01 without this context.

### WR-02: `weeksTowardNextShield` accrual counter is reset on a shielded miss but not on a bare miss

**Files modified:** `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift`
**Commit:** `c644b3f`
**Status:** fixed (documentation only, no behavior change)

**Applied fix:** No orchestrator addendum confirmed this asymmetry as intentional either way, and the review's Fix section offered a choice ("add a comment... or make the two consistent if unintentional"). Chose the conservative, non-speculative option: added a one-line rationale comment to the `.missed` branch explaining the asymmetry (a shielded miss just spent the shield being accrued toward, so accrual restarts; a bare miss spends nothing and opens a Comeback window instead, so partial accrual survives it) rather than guessing at and changing game-design behavior with no requirements-doc confirmation. No test changes needed — behavior is unchanged.

### WR-03: Silent `try?` swallowing in two UI-layer read paths collapses "read failed" into "nothing to show"

**Files modified:** `RithamApp/Ritham/Home/HomeHubView.swift`, `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift`
**Commit:** `99857c6`
**Status:** fixed

**Applied fix:** Both `HomeHubView.onAppear`'s `momentumSummary = try? reader.summary(now:)` and `MovementSnapshotView.loadCurrentMonth`'s `days = (try? ...) ?? []` now `do`/`catch` explicitly, setting a new `@State` flag (`momentumLoadFailed` / `loadFailed`) on failure. Both views now render `OnboardingCopy.Errors.savingFailed` when that flag is set, matching `MomentumView`'s/`RecommendationsView`'s existing `loadError` pattern exactly, instead of silently falling through to the empty state. Left `HomeHubView`'s `isMovementSnapshotEnabled = (try? store.loadMovementSnapshotOptIn()) ?? false` as a silent fallback (documented with a comment) since a failure there only hides one already-off-by-default CTA rather than collapsing an entire content section — a narrower, defensible scope than the two call sites the review's Issue text specifically walks through.

## Skipped Issues

None — all five in-scope findings were fixed.

---

_Fixed: 2026-09-06T16:11:07Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
