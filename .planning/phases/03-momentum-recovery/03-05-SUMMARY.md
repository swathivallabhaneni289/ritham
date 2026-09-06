---
phase: 03-momentum-recovery
plan: 05
subsystem: database
tags: [swift, swiftdata, persistence, momentum, recovery, ritham-core]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-04's HealthDataStore Momentum facade (loadMomentumLedger/saveMomentumLedger, earliestSessionStart, Recovery Week/injury freeze load/append/close) that this plan's reader calls directly, plus 03-03's MomentumReconciliation.reconcile and 03-01/03-02's MomentumWeek/MomentumTarget/SleepAdjustment domain types"
provides:
  - "SleepCheckInRecord and HealthDataStore.loadSleepCheckIn/saveSleepCheckIn -- RECOVERY-01's daily self-report, one row per calendar day, never read by any Momentum ledger method"
  - "WorkoutPreferenceRecord.movementSnapshotOptIn plus HealthDataStore.loadMovementSnapshotOptIn/saveMovementSnapshotOptIn/movementSnapshotDays(in:) and the MovementSnapshotDay value type -- MOMENTUM-07's opt-in calendar, derived from existing sessions rather than a new append-only record"
  - "MomentumSummary/MomentumSummaryReader (RithamApp/Ritham/Momentum/MomentumSummary.swift) -- D-08's standalone queryable Momentum read, performing reconciliation-on-read and exposing the user-initiated flagRecoveryWeek/flagInjury/clearInjury actions plus isInjuryFrozen/isRecoveryWeekFlagged read helpers"
affects: [03-06, 03-07, 03-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Reconciliation-on-read: MomentumSummaryReader.summary(now:) assembles elapsed-week inputs from the store's existing date-range queries, folds them through MomentumReconciliation.reconcile, and persists the result only when it differs from the loaded ledger"
    - "Bounded elapsed-week assembly (104 weeks per read) so a long-idle store cannot produce an unbounded main-actor fetch loop, with the anchor advancing past skipped overflow weeks as a documented tradeoff"
    - "Derive-from-existing-data instead of a new append-only record: MovementSnapshotDay is computed from already-stored CardioSessionRecord/LiftSessionRecord rows rather than a new MovementSnapshotEntryRecord, per a locked deviation from 03-RESEARCH.md's Data Model Shape"

key-files:
  created:
    - RithamApp/Ritham/Persistence/SleepCheckInRecord.swift
    - RithamApp/Ritham/Momentum/MomentumSummary.swift
    - RithamApp/RithamTests/MovementSnapshotTests.swift
    - RithamApp/RithamTests/MomentumSummaryTests.swift
  modified:
    - RithamApp/Ritham/Persistence/WorkoutPreferenceRecord.swift
    - RithamApp/Ritham/Persistence/RithamModelContainer.swift
    - RithamApp/Ritham/Persistence/HealthDataStore.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Locked deviation from 03-RESEARCH.md's Data Model Shape: MovementSnapshotDay is derived at read time from existing CardioSessionRecord/LiftSessionRecord rows via a new movementSnapshotDays(in:) HealthDataStore method, not a new append-only MovementSnapshotEntryRecord -- removes a whole record type and makes MOMENTUM-07's 'no streak, shield or target attached' structurally true (no foreign key can exist to a record that doesn't exist) rather than merely asserted."
  - "movementSnapshotOptIn lives on WorkoutPreferenceRecord, not MomentumStateRecord, per D-09 -- putting the opt-in on the Momentum row would itself be the association D-09 forbids."
  - "MomentumSummaryReader.summary(now:) tolerates a profile-less store: store.activeConditionTags(now:) throws HealthDataStoreError.profileMissing when no UserProfile exists yet, which is unreachable in the shipped app (Momentum screens are post-onboarding-only) but would otherwise make an empty-store read throw, violating this plan's own 'does not throw' requirement -- caught and treated as an empty active-tag set (Rule 1 deviation, caught by the test suite, not a silent design gap)."
  - "The elapsed-week assembly caps at 104 weeks (~2 years) per read; when the gap exceeds this, only the most recent bounded window is folded and the ledger's anchor advances past the skipped overflow weeks, which are never scored as either a miss or a success -- a documented, deliberate tradeoff (T-3-10's mitigation) rather than an unbounded main-actor fetch."
  - "MomentumSessionEntry.title for a lift session is the fixed string \"Strength session\" (StrengthSessionView's own screen-title precedent, transcribed rather than drafted anew) since LiftSession carries no single per-session title of its own; cardio uses the existing ActivityType.displayName."

requirements-completed: [MOMENTUM-01, MOMENTUM-03, MOMENTUM-07, MOMENTUM-08, RECOVERY-01]

coverage:
  - id: D1
    description: "A sleep check-in persists one row per calendar day with upsert-on-repeat semantics and is never read by any Momentum ledger method"
    requirement: "RECOVERY-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotTests.swift (sleepCheckInRoundTripsWithNote, sleepCheckInRoundTripsWithNilNote, savingSecondCheckInForSameDayReplacesFirst, savingCheckInsForTwoDifferentDaysStoresTwoRows)"
        status: pass
    human_judgment: false
  - id: D2
    description: "MovementSnapshotDay carries exactly a date and whether activity was logged -- no streak, shield, target or milestone member -- derived from existing cardio/lift sessions, not a new append-only record"
    requirement: "MOMENTUM-07"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotTests.swift (movementSnapshotDaysMarksCardioDay, movementSnapshotDaysMarksLiftDay, movementSnapshotDaysLeavesEmptyDayUnmarked, movementSnapshotDaysMarksNonQualifyingSessionDay, movementSnapshotDayCarriesNoMomentumState)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The Movement Snapshot opt-in defaults to false and round-trips through the general preference row"
    requirement: "MOMENTUM-07"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotTests.swift (snapshotOptInDefaultsFalse, snapshotOptInRoundTripsBothWays)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MomentumSummary is a standalone queryable read that reconciles lazily on every read, persisting deltas only when they exist, and is idempotent across the persistence boundary"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumSummaryTests.swift (readingTheSummaryTwiceLeavesTheStoredLedgerUnchanged, missedElapsedWeekOpensComebackWindow, metElapsedWeekIncrementsCurrentStreak, fourConsecutiveMetWeeksAccrueAShield, milestoneAwardedAtFourWeeksAppearsInSummary)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The endowed week-one credit is anchored correctly and distinguishes the head-start reading (required-this-week) from the display-only reading (displayed count) at both the default target and a target of 5"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumSummaryTests.swift (firstSessionInCurrentWeekAppliesEndowedCredit, targetFiveRequiresFourRealSessions, endowedCreditIsZeroForANonFirstSessionWeek)"
        status: pass
    human_judgment: false
  - id: D6
    description: "MomentumSummary carries no sleep member of any kind, and a stored sleep check-in changes nothing about the resulting summary"
    requirement: "RECOVERY-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumSummaryTests.swift (momentumSummaryCarriesNoSleepState)"
        status: pass
    human_judgment: false
  - id: D7
    description: "A lift-derived session entry carries no verification label; a manually-captured cardio entry carries the shipped manually-entered label"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumSummaryTests.swift (aLiftSessionEntryCarriesNoVerificationLabel)"
        status: pass
    human_judgment: false
  - id: D8
    description: "Flagging a Recovery Week or an injury freeze is a user-initiated write with no automatic trigger anywhere in the read path, proven with a stored Poor sleep check-in present across repeated reads"
    requirement: "MOMENTUM-03"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumSummaryTests.swift (flaggingRecoveryWeekPausesTheWeek, flaggingSameRecoveryWeekTwiceStoresOnePeriod, flaggingInjuryFreezesOverlappingWeek, clearingInjuryAllowsSubsequentWeekToResolveNormally, readingTheSummaryNeverFlagsARecoveryWeekOrAnInjury, aPoorSleepCheckInNeverConsumesAShield)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 05: Sleep Check-In, Movement Snapshot, and MomentumSummary Summary

**A daily sleep-check-in record, a derived (not append-only) Daily Movement Snapshot calendar, and `MomentumSummary`/`MomentumSummaryReader` -- the standalone reconciliation-on-read driver that folds the pure `MomentumReconciliation` fold from plan 03-03 over `HealthDataStore`'s existing session queries and persists the resulting ledger deltas only when they change.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-06T09:40:00Z
- **Completed:** 2026-09-06T10:03:26Z
- **Tasks:** 3
- **Files modified:** 8 (4 new, 4 modified)

## Accomplishments
- `SleepCheckInRecord` persists RECOVERY-01's daily self-report with upsert-on-repeat-day semantics, and is structurally never read by any Momentum ledger, milestone, comeback, Recovery Week or injury freeze method -- no method anywhere in `HealthDataStore` reads this record type and writes a Momentum field (D-04's mitigation).
- `WorkoutPreferenceRecord.movementSnapshotOptIn` (default `false`) and `HealthDataStore.movementSnapshotDays(in:)` deliver MOMENTUM-07's Daily Movement Snapshot by deriving day cells from already-stored cardio/lift sessions rather than a new append-only record type -- a locked deviation from 03-RESEARCH.md's proposed `MovementSnapshotEntryRecord` that removes a whole record type and makes "no streak, shield or target attached" structurally true.
- `MomentumSummary` (D-08's standalone queryable read) and `MomentumSummaryReader.summary(now:)` assemble elapsed-week inputs from `HealthDataStore`'s existing date-range queries, fold them through plan 03-03's `MomentumReconciliation.reconcile`, and persist the resulting ledger only when it differs from the one just loaded -- proven idempotent across the persistence boundary by `readingTheSummaryTwiceLeavesTheStoredLedgerUnchanged`.
- The elapsed-week assembly is capped at 104 weeks per read (T-3-10's mitigation): a long-idle store folds only the most recent bounded window, with the ledger's anchor advancing past the skipped overflow weeks as a documented tradeoff, never an unbounded main-actor fetch.
- `MomentumSummary` carries no sleep member of any kind -- pinned by a Mirror-based test (`momentumSummaryCarriesNoSleepState`) that also confirms a stored sleep check-in changes nothing about the resulting summary, making RECOVERY-01 invariants 3 and 7 structural.
- Three user-initiated guardrail actions (`flagRecoveryWeek`, `flagInjury`, `clearInjury`) plus two read helpers (`isInjuryFrozen`, `isRecoveryWeekFlagged`) were added, each a separate method with its own store call; `summary(now:)` calls no store write method other than `saveMomentumLedger(_:)`, proven with a stored Poor sleep check-in present across repeated reads (`readingTheSummaryNeverFlagsARecoveryWeekOrAnInjury`, `aPoorSleepCheckInNeverConsumesAShield`).

## Task Commits

Each task was committed atomically:

1. **Task 1: Sleep check-in record, Movement Snapshot opt-in, and derived snapshot days** - `b138b61` (feat)
2. **Task 2: MomentumSummary and the reconciliation-on-read driver** - `7353b39` (feat)
3. **Task 3: User-initiated Recovery Week and injury flag actions** - `ce24fe6` (feat)

**Plan metadata:** (this commit, `docs(03-05): complete plan`)

## Files Created/Modified
- `RithamApp/Ritham/Persistence/SleepCheckInRecord.swift` - one-row-per-calendar-day sleep self-report, never referenced by any Momentum type
- `RithamApp/Ritham/Persistence/WorkoutPreferenceRecord.swift` - added `movementSnapshotOptIn` (default `false`)
- `RithamApp/Ritham/Persistence/RithamModelContainer.swift` - registered `SleepCheckInRecord` in the schema
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` - new Sleep check-in and Movement Snapshot sections: `loadSleepCheckIn`/`saveSleepCheckIn`, `loadMovementSnapshotOptIn`/`saveMovementSnapshotOptIn`, `movementSnapshotDays(in:)`, and the `MovementSnapshotDay` value type
- `RithamApp/Ritham/Momentum/MomentumSummary.swift` - `MomentumSummary`, `MomentumSessionEntry`, `MomentumSummaryReader` (`summary(now:)`, `flagRecoveryWeek`/`flagInjury`/`clearInjury`, `isInjuryFrozen`/`isRecoveryWeekFlagged`)
- `RithamApp/RithamTests/MovementSnapshotTests.swift` - 11 tests covering sleep check-in round-trip/upsert, snapshot opt-in, and derived snapshot days
- `RithamApp/RithamTests/MomentumSummaryTests.swift` - 18 tests covering endowed-credit/target math, elapsed-week reconciliation, read idempotence, the no-sleep-member/no-verification-label invariants, and the three user-initiated guardrail actions
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` so the new source/test files build

## Decisions Made
- Derived `MovementSnapshotDay` from existing session records instead of building a new append-only record type (locked deviation from 03-RESEARCH.md, documented in `HealthDataStore.swift`'s Movement Snapshot section).
- Kept `movementSnapshotOptIn` on `WorkoutPreferenceRecord` rather than `MomentumStateRecord`, per D-09.
- `summary(now:)` tolerates a profile-less store by catching `HealthDataStoreError.profileMissing` from `activeConditionTags(now:)` and treating it as an empty active-tag set, rather than letting it propagate -- see Deviations below.
- Capped elapsed-week assembly at 104 weeks per read, advancing the anchor past any skipped overflow weeks on a long-idle store.
- A lift session's display title is the fixed string "Strength session" (no per-session title exists on `LiftSession`); its `verificationLabel` is always `nil`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `summary(now:)` tolerated a profile-less store**
- **Found during:** Task 2, first test run of `MomentumSummaryTests`
- **Issue:** `HealthDataStore.activeConditionTags(now:)` throws `HealthDataStoreError.profileMissing` when no `UserProfile` exists yet. `MomentumSummaryReader.summary(now:)` called it unconditionally to compute `isStreakLossProtected`, so every test against a fresh, profile-less in-memory store failed with `.profileMissing` -- including the plan's own explicitly required "an empty store yields a summary... and does not throw" behavior.
- **Fix:** Added a private `loadActiveConditionTags(now:)` helper that catches `HealthDataStoreError.profileMissing` and returns an empty tag set, matching the codebase's existing fail-safe-never-crash discipline (`ConditionTagValidity`'s precedent). Unreachable in the shipped app (Momentum screens are only reachable post-onboarding, once a profile always exists), but required for the reader to be correct and testable against an empty store.
- **Files modified:** `RithamApp/Ritham/Momentum/MomentumSummary.swift`
- **Verification:** All 12 Task 2 tests pass, including `emptyStoreYieldsZeroedSummaryAndDoesNotThrow`.
- **Committed in:** `7353b39` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug).
**Impact on plan:** Necessary correctness fix caught by the plan's own test suite before commit. No scope creep -- the fix is a four-line private helper, not a design change.

## Issues Encountered
None blocking beyond the deviation above, which was caught and fixed during Task 2's own test run before any commit landed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `MomentumSummaryReader` is ready for plan 03-06 (`MomentumView`) and plan 03-07 (`HomeHubView`) to construct with a `HealthDataStore` and call `summary(now: Date())` directly, satisfying D-08's "same underlying data" requirement for both surfaces.
- `flagRecoveryWeek(now:)`/`flagInjury(now:)`/`clearInjury(now:)` and `isInjuryFrozen(now:)`/`isRecoveryWeekFlagged(now:)` are ready for plan 03-06's two guardrail-flag rows (03-UI-SPEC.md Component 5) to call directly.
- `HealthDataStore.loadSleepCheckIn(on:)`/`saveSleepCheckIn(_:)` are ready for plan 03-06's sleep check-in screen and for RECOVERY-01's client-side lighter-suggestion wrapper (a separate plan touching `RecommendationsModel`) to read/write.
- `HealthDataStore.loadMovementSnapshotOptIn()`/`saveMovementSnapshotOptIn(_:)`/`movementSnapshotDays(in:)` are ready for a Settings toggle and a plain calendar view (a separate plan) to consume.
- Flag carried forward from 03-04-SUMMARY.md, still unresolved (out of this plan's file scope): a stale, already-expired-but-unclaimed `ComebackWindow` can still re-fire its rebuild transition against a newly-met week inside a single large multi-week catch-up `reconcile()` call. This plan's `summary(now:)` inherits that same known, accepted, rare edge case from `MomentumReconciliation.reconcile` unchanged -- still flagged for whichever plan next touches reconciliation logic or the ledger's window shape.
- `Scripts/build-app.sh build`, `-only-testing:RithamTests/MomentumContainerTouchingSuites/MomentumStoreTests`, `-only-testing:RithamTests/HealthDataStoreTests` and `-only-testing:RithamTests/WorkoutPreferenceTests` all still pass unchanged -- this plan's additions broke no existing accessor or test.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 4 created files verified present on disk; all 3 task commits (b138b61, 7353b39,
ce24fe6) verified present in `git log --oneline --all`.
