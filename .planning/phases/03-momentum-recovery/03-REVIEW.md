---
phase: 03-momentum-recovery
reviewed: 2026-09-06T00:00:00Z
depth: standard
files_reviewed: 37
files_reviewed_list:
  - RithamApp/Ritham.xcodeproj/project.pbxproj
  - RithamApp/Ritham/App/StepBootstrap.swift
  - RithamApp/Ritham/Home/HomeHubView.swift
  - RithamApp/Ritham/Momentum/Components/MilestoneBadgeList.swift
  - RithamApp/Ritham/Momentum/Components/MomentumProgressBlocks.swift
  - RithamApp/Ritham/Momentum/Components/ShieldRow.swift
  - RithamApp/Ritham/Momentum/MomentumRegistration.swift
  - RithamApp/Ritham/Momentum/MomentumSummary.swift
  - RithamApp/Ritham/Momentum/Phase3StepRegistration.swift
  - RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift
  - RithamApp/Ritham/Momentum/Views/MomentumView.swift
  - RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift
  - RithamApp/Ritham/MovementSnapshot/MovementSnapshotRegistration.swift
  - RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotToggleView.swift
  - RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift
  - RithamApp/Ritham/Persistence/HealthDataStore.swift
  - RithamApp/Ritham/Persistence/MomentumLedgerRecords.swift
  - RithamApp/Ritham/Persistence/MomentumStateRecord.swift
  - RithamApp/Ritham/Persistence/RithamModelContainer.swift
  - RithamApp/Ritham/Persistence/SleepCheckInRecord.swift
  - RithamApp/Ritham/Persistence/WorkoutPreferenceRecord.swift
  - RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift
  - RithamApp/Ritham/Settings/SettingsView.swift
  - RithamApp/RithamTests/HomeHubTests.swift
  - RithamApp/RithamTests/MomentumStoreTests.swift
  - RithamApp/RithamTests/MomentumSuiteSerialization.swift
  - RithamApp/RithamTests/MomentumSummaryTests.swift
  - RithamApp/RithamTests/MomentumTargetPickerTests.swift
  - RithamApp/RithamTests/MomentumViewTests.swift
  - RithamApp/RithamTests/MovementSnapshotTests.swift
  - RithamApp/RithamTests/MovementSnapshotViewTests.swift
  - RithamApp/RithamTests/Phase3CoverageTests.swift
  - RithamApp/RithamTests/RecoveryAdjustmentTests.swift
  - RithamCore/Sources/RithamCore/Copy/MomentumCopy.swift
  - RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift
  - RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift
  - RithamCore/Sources/RithamCore/Momentum/MomentumTarget.swift
  - RithamCore/Sources/RithamCore/Momentum/MomentumWeek.swift
  - RithamCore/Sources/RithamCore/Momentum/SleepAdjustment.swift
  - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
  - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
  - RithamCore/Tests/RithamCoreTests/MomentumCopyTests.swift
  - RithamCore/Tests/RithamCoreTests/MomentumLedgerTests.swift
  - RithamCore/Tests/RithamCoreTests/MomentumReconciliationTests.swift
  - RithamCore/Tests/RithamCoreTests/MomentumTargetTests.swift
  - RithamCore/Tests/RithamCoreTests/MomentumWeekTests.swift
  - RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift
  - RithamCore/Tests/RithamCoreTests/SleepAdjustmentTests.swift
findings:
  critical: 2
  warning: 3
  info: 1
  total: 6
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-09-06T00:00:00Z
**Depth:** standard
**Files Reviewed:** 37
**Status:** issues_found

## Summary

This phase implements Momentum's reconciliation-on-read fold, its SwiftData persistence layer, the
Momentum/Recovery/Movement-Snapshot UI surfaces, and the sleep-check-in-driven plan adjustment. The
domain layer (`RithamCore/Sources/RithamCore/Momentum/`) is unusually well documented and its test
suite is thorough for every scenario it actually exercises — but it has a gap in exactly the
scenario that matters most for a long-lived append-only fold: **calling `reconcile` more than once
across separated points in time, after state has moved on.** That gap hides a real, user-facing data
loss bug (CR-01) that will silently zero out a user's streak forever after the first missed week
whose Comeback window expires unclaimed. A second, unrelated correctness bug (CR-02) causes the
Daily Movement Snapshot calendar to never mark the last day of any displayed month, even when
activity was logged on it.

Neither bug is caught by the existing test suite, and in both cases the reason is the same shape:
the tests re-run the same inputs (same `now`, same elapsed weeks, same date range) a second time and
assert equality/no-op, rather than advancing the clock or the displayed range past the point where
the bug becomes observable.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: An expired, unclaimed Comeback window permanently and repeatedly resets the streak to zero on every future reconciliation

**File:** `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift:229-249`

**Issue:**

The post-fold "resolve every unclaimed comeback window" pass runs over the *entire* persisted
`ledger.comebackWindows` array on every single call to `reconcile`, not just the windows opened
during this call's `weeksToProcess`. Unlike the per-week fold above it, this pass is **not gated by
`lastReconciledWeekStart`**:

```swift
for index in windowIndicesByOpensAt {
    guard ledger.comebackWindows[index].claimedAt == nil else { continue }
    let window = ledger.comebackWindows[index]

    if let claiming = qualifyingRefs
        .filter({ window.covers($0.startedAt) })
        .min(by: { $0.startedAt < $1.startedAt }) {
        ledger.comebackWindows[index].claimedAt = claiming.startedAt
        ledger.comebackWindows[index].claimingSessionID = claiming.id
        ledger.currentStreak = max(1, window.streakBeforeMiss - 1)
    } else if now >= window.closesAt {
        ledger.currentStreak = 0
        ledger.streakLabelKind = .rebuilt
    }
    // Else: the window is still open and unclaimed — leave both it and the streak untouched.
}
```

When a window expires unclaimed, the `else if now >= window.closesAt` branch sets
`currentStreak = 0` — but it never marks the window as resolved. `ComebackWindow`
(`MomentumLedger.swift:54-93`) has no "resolved"/"expired" field, only `claimedAt`/
`claimingSessionID`, and `HealthDataStore.saveMomentumLedger` (`HealthDataStore.swift:643-685`) is
explicitly documented to **never delete** a comeback-window row ("this method never issues a delete
call against a milestone or comeback row"). So the window remains in `ledger.comebackWindows` with
`claimedAt == nil` forever, and `now >= window.closesAt` stays true forever once it first becomes
true.

Concretely: once one Comeback window ever expires unclaimed, every subsequent call to
`summary(now:)` — which happens on essentially every app foreground/screen appearance via
`HomeHubView.onAppear`/`MomentumView.onAppear` — re-executes this branch, because this loop is
unconditional and iterates the whole array. Trace through a realistic sequence:

1. Week N is missed, no shield available → Comeback window W opens (streak was 5).
2. W closes unclaimed. Next `summary(now:)` call: the weekly fold has nothing new to process, but
   the resolution pass finds W still `claimedAt == nil` and `now >= W.closesAt`, so
   `currentStreak = 0`, `streakLabelKind = .rebuilt`. This is correct, once.
3. User logs qualifying sessions over weeks N+1, N+2, N+3. Each `summary(now:)` call processes the
   newly elapsed week(s) in the per-week fold, correctly raising `currentStreak` to 1, 2, 3.
4. But on *every one of those same calls*, the unconditional resolution pass at the bottom of
   `reconcile` re-examines W. `W.claimedAt` is still `nil`, and `now >= W.closesAt` is still (and
   will always be) `true`. So immediately after the per-week fold raises the streak, this pass
   resets it back to `0` and re-stamps `streakLabelKind = .rebuilt` — every single time.

The net effect: `currentStreak` can never again exceed 0 after one Comeback window has ever expired
unclaimed, for the life of the install (barring a shield being consumed to skip the doomed value, or
another workaround). Milestone tiers above 0 become permanently unreachable through this path. This
is silent, persisted data loss for the app's core gamification mechanic, not a display glitch — the
zeroed value is written back via `store.saveMomentumLedger(reconciled)` in
`MomentumSummary.swift:207-209` every time it happens.

**Why the existing tests miss this:** `reconcilingTwiceOverAClosedUnclaimedWindowIsANoOp`
(`MomentumReconciliationTests.swift:981-1012`) and `readingTheSummaryTwiceLeavesTheStoredLedger
Unchanged` (`MomentumSummaryTests.swift:199-218`) both call `reconcile`/`summary` a second time with
**identical** `now` and **identical** (already-processed) elapsed weeks against a ledger that is
already at `currentStreak == 0`. That is a true no-op and passes. No test in either suite exercises
"expire a window, then reconcile again with *new*, later, met elapsed weeks" — the exact sequence
that exposes the bug.

**Fix:**

Give `ComebackWindow` a way to record that the expiry-without-claim transition has already been
applied, and gate the `else if now >= window.closesAt` branch on it, e.g.:

```swift
public struct ComebackWindow: Sendable, Equatable, Identifiable {
    ...
    public var resolvedAt: Date?   // set once, either on claim or on unclaimed expiry
}
```

```swift
} else if now >= window.closesAt, window.resolvedAt == nil {
    ledger.currentStreak = 0
    ledger.streakLabelKind = .rebuilt
    ledger.comebackWindows[index].resolvedAt = now
}
```

This alone is not sufficient — `HealthDataStore.saveMomentumLedger`'s in-place-update branch
(`HealthDataStore.swift:673-682`) only ever writes `claimedAt`/`claimingSessionID` onto an existing,
still-unclaimed stored row:

```swift
if let existing = existingComebackByID[window.id] {
    if existing.claimedAt == nil {
        existing.claimedAt = window.claimedAt
        existing.claimingSessionID = window.claimingSessionID
    }
}
```

A `resolvedAt` field added only to the domain struct, without a matching column on
`ComebackWindowRecord` (`MomentumLedgerRecords.swift:51-104`) and a corresponding write in this
branch, will not persist — the resolved marker will be recomputed as "unresolved" on every fresh
load from `loadMomentumLedger`, and the bug returns immediately after the next app relaunch. The fix
must touch all three: the domain struct, the SwiftData record + its `window` computed property, and
`saveMomentumLedger`'s update branch.

Add a regression test that reconciles across an expired-unclaimed window, then reconciles again with
several *new* met weeks appended, and asserts `currentStreak` reflects those new weeks rather than
being pinned at 0.

**Addendum (orchestrator, verified independently):** the *claim* branch has a related, distinct bug
that the fix above must also cover. It runs after the per-week fold loop and unconditionally
overwrites `ledger.currentStreak`:

```swift
ledger.currentStreak = max(1, window.streakBeforeMiss - 1)
```

If the same qualifying session that claims the window falls in a week the per-week fold *also*
processed as `.met` in this same `reconcile` call (raising `currentStreak` above
`window.streakBeforeMiss - 1`), this line silently downgrades that already-correct, higher value.
Fix by taking the max instead of assigning outright:

```swift
ledger.currentStreak = max(ledger.currentStreak, max(1, window.streakBeforeMiss - 1))
```

Add a regression test with a single `reconcile` call spanning both the claiming week (independently
`.met`) and the comeback restoration, asserting the fold's higher streak value survives.

---

#### CR-02: The Daily Movement Snapshot calendar never marks the last day of a displayed month, even when activity was logged on it

**File:** `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift:152-157`, consumed via `RithamApp/Ritham/Persistence/HealthDataStore.swift:354-365` and `:839-856`

**Issue:**

```swift
nonisolated static func monthRange(containing date: Date, calendar: Calendar) -> ClosedRange<Date>? {
    guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
    let firstDay = calendar.startOfDay(for: interval.start)
    guard let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
    return firstDay...calendar.startOfDay(for: lastDay)
}
```

For January this returns `Jan 1 00:00:00 ... Jan 31 00:00:00` — the upper bound is midnight at the
*start* of the last day, not its end. This range is passed straight into
`HealthDataStore.movementSnapshotDays(in:)`, which loads sessions via `loadCardioSessions(in:)`/
`loadLiftSessions(in:)`. Both use an inclusive-upper-bound predicate:

```swift
let predicate = #Predicate<CardioSessionRecord> { record in
    record.startedAt >= lowerBound && record.startedAt <= upperBound
}
```

A cardio or lift session started on Jan 31 at any time after midnight (e.g. 09:00) has
`startedAt > upperBound` and is silently excluded from the `cardio`/`lift` arrays, and therefore from
`activeDays`. Meanwhile `movementSnapshotDays`'s own day-cursor loop (`HealthDataStore.swift:847-855`)
still emits a `MovementSnapshotDay` cell for Jan 31 (`while cursor <= endDay`) — so the cell renders,
just permanently unmarked, indistinguishable from a day with no activity at all.

This is exactly the class of off-by-one bug the codebase's own `MomentumWeek.weekRange` and
`MomentumSummaryReader.weekInput` already guard against with a documented `-0.001`-second trick on
the upper bound; this call site is the one place that pattern was not applied.

**Impact:** any activity logged on the last calendar day of a month a user is viewing in the Daily
Movement Snapshot will never show as logged, for that month, permanently (the month itself doesn't
change after the fact). This also makes `MovementSnapshotViewTests.monthWithCardioSessionMarksExactlyThatDay`
(`MovementSnapshotViewTests.swift:108-122`) a calendar-dependent flake: it uses "today" as its
fixture day and will fail whenever the suite happens to run on the last day of a month.

**Fix:**

Match the existing `weekRange`/`weekInput` convention — push the upper bound to just before the
start of the day *after* the last day, e.g.:

```swift
guard let dayAfterLastDay = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return nil }
return firstDay...dayAfterLastDay.addingTimeInterval(-0.001)
```

or equivalently derive the upper bound from `interval.end.addingTimeInterval(-0.001)` directly,
mirroring `MomentumWeek.weekRange`'s existing pattern.

### Warnings

#### WR-01: A milestone-tier week grants a shield twice, seemingly independent of the shipped "shields build after 4 consecutive weeks" copy

**File:** `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift:174-189`, `RithamCore/Sources/RithamCore/Copy/MomentumCopy.swift:183`

**Issue:** In the `.met` branch, a shield is granted from ordinary 4-week accrual
(`weeksTowardNextShield >= MomentumLedger.weeksPerShield`) *and*, on the same iteration, a second
shield is granted whenever the new streak also happens to land on a milestone tier
(`MomentumMilestone.tiers` = `[4, 12, 26, 52]`):

```swift
if ledger.weeksTowardNextShield >= MomentumLedger.weeksPerShield {
    ledger.weeksTowardNextShield = 0
    ledger.shieldCount = min(MomentumLedger.maxShields, ledger.shieldCount + 1)
}
if MomentumMilestone.tiers.contains(ledger.currentStreak),
   !ledger.milestones.contains(where: { $0.weekCount == ledger.currentStreak }) {
    ledger.milestones.append(...)
    ledger.shieldCount = min(MomentumLedger.maxShields, ledger.shieldCount + 1)
}
```

`MomentumSummaryTests.fourConsecutiveMetWeeksAccrueAShield` (`MomentumSummaryTests.swift:149-173`)
and `MomentumReconciliationTests.streakReachingATierAwardsMilestoneAndBonusShield`
(`MomentumReconciliationTests.swift:571-595`) both assert this as intentional ("two separate,
documented grants"), but the shipped user-facing copy
(`MomentumCopy.Empty.noShieldsBody`, `MomentumCopy.swift:183`) states only one mechanism: "Shields
build automatically after 4 consecutive successful weeks." A user who reaches week 4 sees
`shieldCount == 2` with no copy anywhere explaining the second grant. This may be an intended design
decision (a milestone bonus), but nothing in the reviewed files states that requirement explicitly —
please confirm against the phase's requirements doc; if the double grant is unintended, it should be
collapsed to one, and if intended, the copy should say so.

**Fix:** Either (a) make the milestone-tier award not also grant a bonus shield when it coincides
with ordinary 4-week accrual, or (b) add copy acknowledging the milestone bonus shield mechanism, so
the two-shields-at-week-4 outcome is explained rather than silently surprising.

#### WR-02: `weeksTowardNextShield` accrual counter is reset on a shielded miss but not on a bare miss

**File:** `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift:190-212`

**Issue:** The `.shielded` branch resets `weeksTowardNextShield = 0` when a shield is consumed, but
the `.missed` branch (no shield available) does not touch `weeksTowardNextShield` at all — partial
accrual toward the next shield survives an unprotected miss but is destroyed by a protected one. No
comment in this file states this asymmetry is intentional, and it is easy to read as an oversight
given every other branch here is carefully documented for its precise behavior.

**Fix:** Either add a one-line comment explaining why a bare miss preserves partial accrual while a
shielded miss does not, or make the two consistent if the asymmetry is unintentional.

#### WR-03: Silent `try?` swallowing in two UI-layer read paths collapses "read failed" into "nothing to show"

**File:** `RithamApp/Ritham/Home/HomeHubView.swift:106-110`, `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift:137-144`

**Issue:**

```swift
// HomeHubView.onAppear
momentumSummary = try? reader.summary(now: Date())
```

```swift
// MovementSnapshotView.loadCurrentMonth
days = (try? store.movementSnapshotDays(in: range)) ?? []
```

A genuine store read failure (e.g. an underlying SwiftData fetch error) renders identically to a
legitimately empty state: no Momentum section on the hub, or the "No entries yet" empty state on the
snapshot calendar. There is no user-visible or logged signal that something actually went wrong,
unlike `MomentumView`/`RecommendationsView`, which surface a `loadError` and render
`OnboardingCopy.Errors.savingFailed`. This is a minor robustness/quality gap rather than a
correctness bug (both call sites are read-only and idempotent), but it makes a real persistence
problem indistinguishable from "you haven't done anything yet," which will misdirect debugging effort
if it ever fires in production.

**Fix:** Where practical, capture the error (e.g. into a `@State` flag) and surface it the same way
`MomentumView`/`RecommendationsView` already do, rather than collapsing failure into the empty state.

### Info

#### IN-01: Comeback-window claiming does not exclude a session already used to claim a different window

**File:** `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift:229-241`

**Issue:** The claiming loop iterates open windows in ascending `opensAt` order and, for each, picks
the earliest qualifying session whose `startedAt` falls within that window — but it never removes a
claimed session from the `qualifyingRefs` pool before considering the next window. Given the current
system (windows are exactly `comebackWindowDays` = 3 days wide, opened only at a missed week's end,
and weeks are ~7 days apart), two open windows cannot currently have overlapping date ranges, so this
is not reachable today. If `comebackWindowDays` is ever widened, or weeks shortened, the same session
could silently double-claim two windows. Worth a one-line comment noting the invariant this relies on,
so a future change to either constant doesn't reintroduce it silently.

**Fix:** No action required now; consider a comment on `comebackWindowDays` or the claiming loop
documenting the "windows never overlap given current week length" invariant this logic implicitly
depends on.

---

_Reviewed: 2026-09-06T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
