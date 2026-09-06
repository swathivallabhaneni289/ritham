---
phase: 03-momentum-recovery
plan: 04
subsystem: database
tags: [swift, swiftdata, persistence, momentum, ritham-core]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-01's MomentumLedger/MomentumTarget value types and 03-03's MomentumReconciliation.reconcile output, both persisted verbatim by this plan"
provides:
  - "MomentumStateRecord/MilestoneAwardRecord/ComebackWindowRecord/RecoveryWeekPeriodRecord/InjuryFreezePeriodRecord -- the five new SwiftData @Model records, registered in RithamModelContainer"
  - "HealthDataStore's Momentum section: loadMomentumTarget/saveMomentumTarget, loadMomentumLedger/saveMomentumLedger, earliestSessionStart, loadRecoveryWeekPeriods/appendRecoveryWeekPeriod, loadInjuryFreezePeriods/appendInjuryFreezePeriod/closeOpenInjuryFreeze"
  - "MomentumContainerTouchingSuites -- the serialized parent every later Momentum test suite in this phase nests under"
affects: [03-05, 03-06, 03-07, 03-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-row upsert for scalar Momentum state (MomentumStateRecord), mirroring WorkoutPreferenceRecord/upsertWorkoutPreference exactly"
    - "Append-only, insert-if-absent persistence for milestone/comeback/Recovery-Week/injury-freeze rows -- saveMomentumLedger and the guardrail append methods never call context.delete"
    - "Zero SwiftData relationships between the three D-03-independent self-report record types, making 'never auto-triggers the other' structural rather than merely untested"

key-files:
  created:
    - RithamApp/Ritham/Persistence/MomentumStateRecord.swift
    - RithamApp/Ritham/Persistence/MomentumLedgerRecords.swift
    - RithamApp/RithamTests/MomentumSuiteSerialization.swift
    - RithamApp/RithamTests/MomentumStoreTests.swift
  modified:
    - RithamApp/Ritham/Persistence/RithamModelContainer.swift
    - RithamApp/Ritham/Persistence/HealthDataStore.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "supportedMomentumTargets reads MomentumTarget.supported directly (no second literal), unlike supportedWeeklyFrequencies -- MomentumTarget.supported is a plain, non-isolated RithamCore constant with no main-actor isolation conflict, unlike the UI-layer WeeklyFrequencyOption.all which had to be redeclared separately for exactly that reason."
  - "loadMomentumLedger sorts MilestoneAwardRecord by awardedAt and ComebackWindowRecord by opensAt before assembling the domain ledger, so a save-then-load round trip is byte-for-byte order-stable and directly comparable via Equatable in tests, rather than leaving fetch order to SwiftData's unspecified default."
  - "Did not add a ComebackWindow.resolved field to close out 03-03-SUMMARY's flagged stale-window edge case -- that fix would require touching MomentumReconciliation.swift, which is out of this plan's file scope. Carried forward below for whichever plan next touches reconciliation logic."

patterns-established:
  - "Every new append-only record exposes a convenience init(domainValue:) and a computed domain-value accessor (Optional-typed for interface uniformity with CardioSessionRecord's never-trapping pattern, even where the record has no raw enum column that can actually fail to decode)."
  - "Guardrail-touching HealthDataStore methods are documented and test-pinned (via a manually maintained method inventory, momentumStoreExposesNoCrossMachineTransition) to never read one D-03 guardrail type and write another."

requirements-completed: [MOMENTUM-02, MOMENTUM-03, MOMENTUM-04, MOMENTUM-05, MOMENTUM-06, MOMENTUM-08]

coverage:
  - id: D1
    description: "MomentumStateRecord/HealthDataStore.saveMomentumTarget guard-and-throw validate a weekly target against MomentumTarget.supported, mirroring saveWeeklyFrequency exactly -- an unsupported value is never clamped, and persists nothing (T-3-01)"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (savingSupportedTargetRoundTrips, savingUnsupportedTargetThrowsAndLeavesStoredValueUnchanged, loadMomentumTargetDefaultsWhenEmpty, supportedMomentumTargetsMatchesDomainConstant)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The full Momentum ledger (streak, shields, accrual counter, last-reconciled anchor, milestones, comeback windows) round-trips losslessly through SwiftData, and saving the same ledger twice never duplicates a milestone or comeback row"
    requirement: "MOMENTUM-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (ledgerRoundTrips, savingSameLedgerTwiceDoesNotDuplicateRows)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A stored, unclaimed comeback window's claim fields update in place when a ledger reports it claimed, without inserting a second row"
    requirement: "MOMENTUM-04"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (claimingComebackWindowUpdatesInPlace)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Milestone awards and comeback windows persist as independently addressable append-only rows; saveMomentumLedger never calls context.delete on either kind, so a stored milestone survives a later save whose ledger omits it"
    requirement: "MOMENTUM-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (storedMilestoneSurvivesOmission); grep -c context.delete RithamApp/Ritham/Persistence/HealthDataStore.swift unchanged at 12 before/after this plan's Momentum additions"
        status: pass
    human_judgment: false
  - id: D5
    description: "Recovery Week periods persist as an idempotent (same-week-twice is a no-op), append-only history, sharing no stored state or write path with the injury freeze record type"
    requirement: "MOMENTUM-03"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (recoveryWeekPeriodRoundTrips, appendingSameRecoveryWeekTwiceStoresExactlyOneRow, recoveryWeekAndInjuryFreezeShareNoStoredState)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Injury freeze periods persist as an idempotent (a second open flag is a no-op), append-only, open/close history, sharing no stored state or write path with Recovery Week; no HealthDataStore method reads one guardrail type and writes the other"
    requirement: "MOMENTUM-08"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (appendingSecondInjuryFreezeWhileOpenStoresExactlyOneRow, closingOpenFreezeSetsEndAndLeavesRowPresent, closingWhenNothingOpenIsANoOp, momentumStoreExposesNoCrossMachineTransition)"
        status: pass
    human_judgment: false
  - id: D7
    description: "MomentumVisibility persists and reloads as private-to-device, the only v1 value (D-07); no sharing write path exists anywhere in this plan"
    requirement: "MOMENTUM-06"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (visibilityPersistsAsPrivateToDevice)"
        status: pass
    human_judgment: false
  - id: D8
    description: "earliestSessionStart anchors D-10's endowed week-one credit to the earliest of a stored cardio or lift session, or nil when neither exists"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumStoreTests.swift (earliestSessionStartNilWhenEmpty, earliestSessionStartReturnsEarliestAcrossModalities)"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 04: Momentum Persistence Summary

**Five new SwiftData records (a single-row Momentum state row plus four append-only ledger/guardrail records) registered in `RithamModelContainer`, and a `HealthDataStore` Momentum facade (`loadMomentumTarget`/`saveMomentumTarget`, `loadMomentumLedger`/`saveMomentumLedger`, `earliestSessionStart`, and the Recovery Week/injury freeze append-only accessors) proven to round-trip losslessly, validate the weekly target at the storage boundary, and never delete a previously stored milestone, comeback, Recovery Week or injury freeze row across 18 passing Swift Testing cases.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-06T09:20:35Z
- **Completed:** 2026-09-06T09:34:02Z
- **Tasks:** 3
- **Files modified:** 7 (4 new, 3 modified)

## Accomplishments
- `MomentumStateRecord` (the single upserted scalar row: streak, shield count, weeks-toward-next-shield, last-reconciled anchor, weekly target, visibility scope) and four append-only `@Model` records (`MilestoneAwardRecord`, `ComebackWindowRecord`, `RecoveryWeekPeriodRecord`, `InjuryFreezePeriodRecord`) follow the two proven shapes 03-RESEARCH.md's Data Model Shape prescribes -- `WorkoutPreferenceRecord`'s single-row upsert and `CardioSessionRecord`'s independently-addressable append-only row -- and are registered in `RithamModelContainer`'s single schema.
- None of the five new records declares a SwiftData relationship or foreign key to any other, making D-03's "the sleep check-in, Recovery Week flag and injury freeze never auto-trigger each other" structural rather than merely untested (T-3-08's mitigation).
- `HealthDataStore.saveMomentumLedger` upserts the scalar state row and inserts only milestone/comeback rows not already stored, updating an existing unclaimed comeback window's claim fields in place -- it never calls `context.delete` on either kind, the persistence-layer half of plan 03-03's append-only reconciliation guarantee (T-3-04's mitigation, pinned by a delete-count acceptance gate and a stored-milestone-survives-omission test).
- `saveMomentumTarget` guards against `HealthDataStore.supportedMomentumTargets` (sourced directly from `MomentumTarget.supported`) and throws `unsupportedMomentumTarget` without persisting anything on an out-of-range value, mirroring the shipped `saveWeeklyFrequency` exactly (T-3-01's mitigation).
- `appendRecoveryWeekPeriod`/`appendInjuryFreezePeriod`/`closeOpenInjuryFreeze` are each idempotent (same-week-twice, second-open-freeze, and close-when-nothing-open are all no-ops) and structurally kept from reading one guardrail type while writing the other -- pinned by `recoveryWeekAndInjuryFreezeShareNoStoredState` and a documented method-inventory test, `momentumStoreExposesNoCrossMachineTransition`.
- New `MomentumContainerTouchingSuites` serialized parent (mirroring `StepRegistryTouchingSuites`) prevents this phase's new SwiftData-container-creating test suites from adding to the pre-existing cross-suite concurrency flake STATE.md already tracks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Momentum SwiftData records and schema registration** - `f942f34` (feat)
2. **Task 2: HealthDataStore Momentum ledger facade and target validation** - `a1c5a6a` (feat)
3. **Task 3: Recovery Week and injury freeze period persistence** - `c6db2bf` (feat)

**Plan metadata:** (this commit, `docs(03-04): complete Momentum persistence plan`)

## Files Created/Modified
- `RithamApp/Ritham/Persistence/MomentumStateRecord.swift` - the single upserted scalar Momentum state row, with never-trapping computed `streakLabelKind`/`visibilityScope` accessors
- `RithamApp/Ritham/Persistence/MomentumLedgerRecords.swift` - the four append-only records (milestone awards, comeback windows, Recovery Week periods, injury freeze periods), zero relationships between them
- `RithamApp/Ritham/Persistence/RithamModelContainer.swift` - registered all five new record types in the single schema
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` - new Momentum section: target load/save/validation, ledger load/save, `earliestSessionStart`, Recovery Week/injury freeze load/append/close, plus the new `unsupportedMomentumTarget` error case
- `RithamApp/RithamTests/MomentumSuiteSerialization.swift` - the `MomentumContainerTouchingSuites` serialized parent
- `RithamApp/RithamTests/MomentumStoreTests.swift` - 18 tests covering target validation, ledger round-trip/idempotence/append-only guarantees, visibility, `earliestSessionStart`, and the two guardrail histories' independence
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` so the new source/test files build

## Decisions Made
- `supportedMomentumTargets` reads `MomentumTarget.supported` directly rather than restating it as a second literal, since (unlike `supportedWeeklyFrequencies`'s UI-layer mirror `WeeklyFrequencyOption.all`) there is no main-actor isolation conflict to work around.
- `loadMomentumLedger` sorts milestone and comeback-window fetches (`awardedAt` / `opensAt` ascending) before assembling the domain ledger, so round-trip equality in tests is order-stable rather than dependent on SwiftData's unspecified default fetch order.
- Declined to add a `ComebackWindow.resolved` field to close out 03-03-SUMMARY's flagged stale-comeback-window edge case (see `<context_from_prior_plan>`): doing so would require modifying `MomentumReconciliation.swift`'s resolution logic, which sits outside this plan's file scope (only the persistence layer). Carrying the flag forward unchanged below.

## Deviations from Plan

None requiring a rule. Two small self-corrections were caught and fixed before commit, not left as latent bugs:
- The `MomentumLedgerRecords.swift` header comment and a `saveMomentumLedger` doc comment each originally used the literal tokens `` `@Relationship` `` and `` `context.delete` `` in prose explaining their *absence* -- both tokens are matched by this plan's own literal `grep` acceptance gates, so the comments were reworded to describe the same fact without the literal string, and the gates were re-verified at `0` and `12` (baseline-unchanged) respectively.

**Total deviations:** 0 requiring a deviation rule.
**Impact on plan:** None -- both were pre-commit self-corrections to keep the plan's own automated acceptance gates meaningful, not scope or behavior changes.

## Issues Encountered
None blocking. `MomentumStoreTests`' struct initially failed to compile with "main actor-isolated" errors because `@MainActor` was applied to the enclosing `extension MomentumContainerTouchingSuites { ... }` rather than directly to the nested `struct MomentumStoreTests` -- Swift does not propagate an extension's `@MainActor` attribute to a nested type declared inside it. Fixed by moving `@MainActor` directly onto the `struct` declaration, matching `HealthDataStoreTests`' existing precedent.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `HealthDataStore.loadMomentumLedger`/`saveMomentumLedger` are the exact load/save pair plan 03-05's reconciliation-on-read driver is expected to call around `MomentumReconciliation.reconcile`.
- `earliestSessionStart()` is ready for plan 03-05 (or whichever plan computes D-10's endowed week-one credit) to anchor the first Momentum week.
- `loadRecoveryWeekPeriods`/`appendRecoveryWeekPeriod` and `loadInjuryFreezePeriods`/`appendInjuryFreezePeriod`/`closeOpenInjuryFreeze` are ready for the Momentum detail screen's flag actions (D-08) to call directly.
- Flag carried forward from 03-03-SUMMARY, unresolved by this plan (out of file scope): a stale, already-expired-but-unclaimed `ComebackWindow` can still re-fire its rebuild transition against a newly-met week inside a single large multi-week catch-up `reconcile()` call. No new field (e.g. `ComebackWindow.resolved`) was added to `MomentumLedger`/`ComebackWindowRecord` to address this, since fixing it requires touching `MomentumReconciliation.swift`'s resolution logic, not this plan's persistence layer. Still a known, accepted, rare edge case (only triggers after a long stretch of not opening the app) -- flagged again for whichever plan next touches reconciliation logic or the ledger's window shape.
- `Scripts/build-app.sh test -only-testing:RithamTests/HealthDataStoreTests` and `-only-testing:RithamTests/WorkoutPreferenceTests` both still pass unchanged -- the extended facade broke no existing accessor.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 4 created files verified present on disk; all 3 task commits (f942f34, a1c5a6a,
c6db2bf) verified present in `git log --oneline --all`.
