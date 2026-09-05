---
phase: 02-core-tracking-adjusted-guidance
plan: 03
subsystem: domain
tags: [swift, foundation-only, value-types, swift-testing, strength-training]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "02-02's MovementPattern/ExerciseCatalog.patterns(for:) (LiftSession.movementPatterns unions this) and Equipment (LiftSet.equipment field)"
  - phase: 01-onboarding-safety-intake
    provides: "CalibrationThreshold.qualifyingWorkingSets/.qualifyingExercises (D-02's shared qualifying bar, referenced not restated)"
provides:
  - "LiftSet: Identifiable value type with stable UUID identity, carrying weight/reps/warm-up/equipment/superset-group/order/completedAt"
  - "LiftSession: working-set aggregates, movementPatterns union, and mostRecentSet(forExercise:in:) — STRENGTH-01's auto-fill lookup"
  - "LiftQualification.evaluate — the lift-session qualifying bar, shared with CalibrationThreshold"
  - "SupersetGroupID/SupersetGroup/SupersetGrouping.join/.ungroup/.groups(in:) — STRENGTH-03's grouping-key-only superset model"
  - "SessionRevision.merge/.split — STRENGTH-05's identity-preserving retroactive session editing"
affects: ["02-04 through 02-16 (any plan building LiftSession-consuming UI, persistence, or superset/merge-split UI)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-value-type domain layer with a stable per-item UUID identity (LiftSet.id) enabling reparenting operations (superset grouping, session merge/split) without ever recreating the item"
    - "Enum-namespace pure functions (SupersetGrouping, SessionRevision) returning new values, never mutating a shared reference"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Strength/LiftSession.swift
    - RithamCore/Sources/RithamCore/Strength/Superset.swift
    - RithamCore/Sources/RithamCore/Strength/SessionRevision.swift
    - RithamCore/Tests/RithamCoreTests/LiftSessionTests.swift
    - RithamCore/Tests/RithamCoreTests/SupersetTests.swift
    - RithamCore/Tests/RithamCoreTests/SessionRevisionTests.swift
  modified: []

key-decisions:
  - "Superset.swift's SupersetGroupID was created a task early (Task 1, not Task 2) because LiftSet.supersetGroupID needs the type to compile — a genuine forward-dependency between the two files' declared task boundaries, resolved by stub-then-extend rather than reordering (SupersetGrouping's own functions take/return LiftSession, so reordering the other direction doesn't work either)."
  - "Pattern 5's open design point (set-level vs. exercise-level superset grouping) resolved in Superset.swift's doc comment: exercise-within-session granularity, matching STRENGTH-03's 'tap on two consecutive exercises' interaction."
  - "SessionRevision.split's endedAt (unspecified by the plan): the first half's endedAt is its own last set's completedAt; the second half's endedAt carries forward the original session's endedAt, since it is the timeline's tail end."
  - "SessionRevision.merge's notes: first.notes ?? second.notes (not specified by the plan; not behavior-tested)."

patterns-established:
  - "Pattern: value-type domain model with per-item stable UUID identity as the sole mechanism enabling later reparenting/merge/split operations, rather than modeling identity via array position or a session-owned relationship."

requirements-completed: [STRENGTH-01, STRENGTH-03, STRENGTH-05]

coverage:
  - id: D1
    description: "LiftSet/LiftSession value types with stable per-set identity and previous-session auto-fill (mostRecentSet)"
    requirement: "STRENGTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/LiftSessionTests.swift (12 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Superset grouping as a key on existing LiftSet identity, no separate owning entity, no separate creation step"
    requirement: "STRENGTH-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/SupersetTests.swift (9 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Retroactive session merge/split preserving set identity, ordering, and superset membership"
    requirement: "STRENGTH-05"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/SessionRevisionTests.swift (10 tests)"
        status: pass
    human_judgment: false

duration: 47min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 3: Lift Session Domain (Sets, Supersets, Merge/Split) Summary

**Pure-Swift `RithamCore/Strength` lift-session domain: `LiftSet`/`LiftSession` with stable UUID identity and previous-session auto-fill, `SupersetGrouping` as a grouping key over that identity, and `SessionRevision.merge`/`.split` that provably partition set identity across a retroactive edit.**

## Performance

- **Duration:** 47 min
- **Started:** 2026-09-05T13:51:24+05:30
- **Completed:** 2026-09-05T14:38:53+05:30
- **Tasks:** 3
- **Files modified:** 6 (3 source, 3 test)

## Accomplishments
- `LiftSet` carries a stable UUID identity independent of the session holding it, and `LiftSession.mostRecentSet(forExercise:in:)` implements STRENGTH-01's auto-fill (latest session containing the exercise, highest `orderIndex`, warm-ups excluded, never falls back to a different exercise).
- `SupersetGrouping.join`/`.ungroup`/`.groups(in:)` express STRENGTH-03's superset as a pure grouping key on existing `LiftSet.supersetGroupID` — no separate owning entity, no separate creation step, and never regenerates a set's `id`.
- `SessionRevision.merge`/`.split` implement STRENGTH-05's retroactive editing: merge unions two sessions' sets (contiguous `orderIndex`, ordered by `completedAt`, `supersetGroupID` untouched) and rejects a self-merge; split partitions a session's sets exactly at a chosen index and rejects degenerate splits (index 0, at/beyond the set count, empty session).
- Full `RithamCore` package suite green: 245 tests across 20 suites, including the three new suites (31 new tests total).

## Task Commits

Each task was committed with a RED test commit followed by a GREEN implementation commit:

1. **Task 1: Lift set and session value types with previous-session auto-fill**
   - `432cb81` test(02-03): add failing test for lift session domain
   - `7554d48` feat(02-03): lift session value types with previous-session auto-fill
2. **Task 2: Superset grouping over existing set identity**
   - `2c066b0` test(02-03): add failing test for superset grouping
   - `9eb022e` feat(02-03): superset grouping over existing set identity
3. **Task 3: Retroactive session merge and split**
   - `529ab9c` test(02-03): add failing test for session merge and split
   - `9b90eb3` feat(02-03): retroactive session merge and split

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Strength/LiftSession.swift` - `LiftSet`, `LiftSession`, `LiftSession.mostRecentSet`, `LiftQualification`
- `RithamCore/Sources/RithamCore/Strength/Superset.swift` - `SupersetGroupID` (added Task 1), `SupersetGroup`, `SupersetGrouping` (added Task 2)
- `RithamCore/Sources/RithamCore/Strength/SessionRevision.swift` - `SessionRevision.merge`, `SessionRevision.split`
- `RithamCore/Tests/RithamCoreTests/LiftSessionTests.swift` - 12 tests
- `RithamCore/Tests/RithamCoreTests/SupersetTests.swift` - 9 tests
- `RithamCore/Tests/RithamCoreTests/SessionRevisionTests.swift` - 10 tests

## Decisions Made
- `SupersetGroupID` created in Task 1 (inside `Superset.swift`), one task ahead of the rest of that file's contents, to break a genuine forward-dependency cycle: `LiftSet.supersetGroupID` needs the type to compile, and `SupersetGrouping`'s functions take/return `LiftSession`, so the dependency can't be broken by reordering the other direction either. Task 2 edits the same file to add `SupersetGroup`/`SupersetGrouping` rather than recreating it — both of Task 2's acceptance greps (`struct SupersetGroupID` count 1, no `class Superset`/`@Model`) still hold.
- Pattern 5's open design point (grouping at the set level vs. the exercise level) resolved in `Superset.swift`'s doc comment: exercise-within-session granularity, per STRENGTH-03's "tap on two consecutive exercises" interaction.
- `SessionRevision.split`'s per-half `endedAt` (unspecified by the plan): first half keeps its own last set's `completedAt`; second half carries forward the original session's `endedAt`.
- `SessionRevision.merge`'s `notes` field takes whichever input has a non-nil value, preferring the first — not plan-specified, not behavior-tested.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created `Superset.swift` one task early, containing only `SupersetGroupID`**
- **Found during:** Task 1 (Lift set and session value types)
- **Issue:** Task 1's `LiftSet` struct has a `supersetGroupID: SupersetGroupID?` field per the plan's own action text, but `SupersetGroupID` is defined by Task 2's `Superset.swift`, which does not exist yet when Task 1 runs. Without it, `LiftSession.swift` — and therefore `LiftSessionTests.swift` — cannot compile.
- **Fix:** Created `RithamCore/Sources/RithamCore/Strength/Superset.swift` in Task 1 containing only `SupersetGroupID` (the minimal type Task 1 needs), with a header comment explaining the split. Task 2 then edited this same file (not created a new one) to add `SupersetGroup` and `SupersetGrouping`, so Task 2's own acceptance criteria (declaration-count and anti-pattern greps against `Superset.swift`) still hold unchanged.
- **Files modified:** `RithamCore/Sources/RithamCore/Strength/Superset.swift` (created in Task 1, extended in Task 2)
- **Verification:** `grep -c 'struct SupersetGroupID' Superset.swift` == 1 and `grep -c 'class Superset\|@Model' Superset.swift` == 0, both confirmed after Task 2; full package suite green after Task 3.
- **Committed in:** `7554d48` (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make Task 1 compile at all, given a genuine forward-dependency between two files' declared task boundaries. No scope creep — the stub contains exactly the one type Task 1 needed, and Task 2 built the rest of the file exactly as planned.

## Issues Encountered
None beyond the forward-dependency deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `LiftSession`/`LiftSet`/`SupersetGrouping`/`SessionRevision` are ready for plan 02-15's retroactive-editing UI and any lift-logging UI/persistence plan to consume directly — no further domain-layer work needed for STRENGTH-01/03/05's logic.
- No blockers. The `RithamCore` package suite (245 tests, 20 suites) is fully green, including this plan's three new suites.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 6 created source/test files confirmed present on disk; all 6 task commit hashes
(`432cb81`, `7554d48`, `2c066b0`, `9eb022e`, `529ab9c`, `9b90eb3`) confirmed present in
`git log --all`. Full `RithamCore` package suite (245 tests, 20 suites) verified green.
