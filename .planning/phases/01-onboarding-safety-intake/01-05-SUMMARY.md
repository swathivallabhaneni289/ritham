---
phase: 01-onboarding-safety-intake
plan: 05
subsystem: ios-core
tags: [swift, swift-testing, calibration, onboarding]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake (plan 01)
    provides: "RithamCore Swift package, toolchain-adaptive test-core.sh, OnboardingCopy.Calibration copy"
provides:
  - "CalibrationThreshold — the single, named source for the 600s/3-set/2-exercise calibration bar, referenced verbatim from MOMENTUM-01"
  - "CalibrationCompletion.evaluate — the source-agnostic completion rule for walk and lift modes"
  - "CalibrationSessionSource protocol — the shared conformance point for the CoreMotion pedometer and manual stopwatch adapters (plan 01-15)"
  - "CalibrationBaseline.provisional / .derive — a real, conservative starting point on skip, and a measured one on a qualifying session"
affects: [01-15, phase-3-momentum]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-logic domain types (no sensor framework imports) exposing a protocol adapters conform to, so completion/derivation is testable without hardware and Xcode"
    - "Named threshold constants declared exactly once, cited by comment from the requirement they must stay in sync with (MOMENTUM-01)"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift
    - RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift
    - RithamCore/Tests/RithamCoreTests/CalibrationThresholdTests.swift
    - RithamCore/Tests/RithamCoreTests/CalibrationBaselineTests.swift
  modified: []

key-decisions:
  - "Added a defaulted distanceMeters field to WalkProgress and an optional loadKg parameter (+ totalLoadKg/loadedSetCount/averageWorkingSetLoadKg) to LiftProgress, both backward-compatible with Task 1's committed test call sites, because the plan's Task 2 instruction to derive pace/weight from measured values was unimplementable against Task 1's duration/count-only shape"
  - "Corrected the provisional pace zone from a running-pace band (360-420 s/km) to a comfortable walking-pace band (660-840 s/km) so the D-03 conservative-default requirement holds in the actual value, not just its comment"

patterns-established:
  - "Pattern: derived/default baseline values are tested for direction-correctness (a faster measured walk yields a lower derived pace; a heavier measured lift yields a higher derived weight), not just for producing a non-nil result — catches formulas that are invariant to or inverted relative to their input"

requirements-completed: [ONBOARD-01]

coverage:
  - id: D1
    description: "Calibration completion rules for both walk and lift modes, matching the corrected D-01/MOMENTUM-01 threshold (10+ continuous minutes; 3+ working sets across 2+ exercises), decidable with no sensor or location permission"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CalibrationThresholdTests.swift (10 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Baseline derivation: a completed session yields a measured pace zone and safe starting weight; a skipped calibration yields a real conservative provisional baseline, never blank; no member of the baseline types reads as a score, grade, level, or rating"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CalibrationBaselineTests.swift (10 tests)"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-08-25
status: complete
---

# Phase 01 Plan 05: Calibration Completion Rules & Baseline Derivation Summary

**Pure-Swift calibration completion rules (walk: 10+ continuous minutes; lift: 3+ working sets across 2+ exercises, matching MOMENTUM-01 verbatim) and baseline derivation that yields a real conservative starting point on skip and a measured one on completion — no sensor framework, no location permission.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-25T16:53:00Z
- **Completed:** 2026-08-25T17:13:01Z
- **Tasks:** 2
- **Files modified:** 4 (all created)

## Accomplishments
- `CalibrationThreshold` locks the corrected D-01 values (600s walk, 3 working sets, 2 exercises) as named constants matching MOMENTUM-01's wording verbatim, so calibration and Phase 3's Momentum qualifying-session bar are one shared definition
- `CalibrationCompletion.evaluate` decides completion from `CalibrationProgress` alone (no CoreMotion/CoreLocation import possible in this Foundation-only target), with `WalkProgress.recordInterruption()` enforcing that a broken walk cannot silently accumulate toward the bar
- `CalibrationBaseline.provisional`/`.derive` give a skipped calibration a real conservative starting point (never zero/nil) and a qualifying session a measured one, with the type surface guarded against ever exposing a score/grade/level/rating member

## Task Commits

Each task was committed atomically:

1. **Task 1: Calibration completion rules for both session modes** - `9425c6c` (feat)
2. **Task 2: Baseline derivation and the provisional starting point** - `1356e43` (feat)

**Plan metadata:** (see final commit below)

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` - `CalibrationMode`, `CalibrationThreshold` (the three named thresholds), `WalkProgress`, `LiftProgress`, `CalibrationProgress`, `CalibrationCompletion.evaluate`, `CalibrationSessionSource` protocol
- `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift` - `PaceZone`, `BaselineSource`, `CalibrationBaseline`, `.provisional(establishedAt:)`, `.derive(from:establishedAt:)`
- `RithamCore/Tests/RithamCoreTests/CalibrationThresholdTests.swift` - 10 tests covering the walk boundary (599/600/601s), interruption reset, the specific superseded 3-sets-across-1-exercise rejection, and the lift boundary
- `RithamCore/Tests/RithamCoreTests/CalibrationBaselineTests.swift` - 10 tests covering `PaceZone` normalisation, provisional non-blankness, nil-on-incomplete, measured-on-complete, pace-zone strictness, direction-correctness for both walk pace and lift weight, and the reflection-based score/grade/level/rating guard

## Decisions Made
- Extended `WalkProgress` with a defaulted `distanceMeters: Double = 0` and `LiftProgress` with an optional `loadKg: Double? = nil` parameter on `recordWorkingSet` (plus `totalLoadKg`/`loadedSetCount`/`averageWorkingSetLoadKg`), both backward-compatible with the Task 1 test call sites already committed — see Deviations below
- Corrected the provisional pace zone to a genuine comfortable-walk band (660-840 s/km, ~4.3-5.5 km/h) rather than the initially drafted running-pace band (360-420 s/km), so the D-03 "errs toward under-loading" requirement is actually true of the shipped numbers

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] WalkProgress/LiftProgress carried no measurement field, so the plan's measured derivation was unimplementable**
- **Found during:** Task 2 (Baseline derivation)
- **Issue:** Task 2's instructions require deriving the pace zone "from the measured average pace" and the safe starting weight "from the recorded working-set load." Task 1's `WalkProgress` (as specified and already committed) holds only `continuousDuration`/`wasInterrupted` — no distance — and `LiftProgress` holds only a set-count dictionary — no load. A first draft of `derive` computed a walk "pace" as `continuousDuration` reinterpreted as seconds/km (invariant to nothing meaningful — a longer walk produced a slower derived pace, backwards) and a lift "weight" as `averageSetsPerExercise * 5` (set-count numerology, not load). Both would have passed every test the plan's action text describes, since none of those tests vary the underlying measurement.
- **Fix:** Added a defaulted `distanceMeters: Double = 0` to `WalkProgress` (zeroed alongside duration in `recordInterruption()`) and an optional `loadKg: Double? = nil` parameter to `LiftProgress.recordWorkingSet`, tracked via `totalLoadKg`/`loadedSetCount` and exposed as `averageWorkingSetLoadKg`. `derive` now computes a real average pace (`duration / (distance/1000)`, widened ±10%) when distance was recorded, and a real conservative fraction (60%) of the average recorded load when load was recorded — falling back to the provisional's conservative values when no measurement was supplied (e.g. a duration-only stopwatch, or a bodyweight-only lift), consistent with D-03's "never blank" requirement.
- **Files modified:** `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` (WalkProgress, LiftProgress), `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift` (derive)
- **Verification:** Two new direction-correctness tests added — a walk covering more distance in the same duration derives a strictly lower pace; a lift recording higher average load derives a strictly higher starting weight — both pass. All pre-existing `CalibrationThresholdTests` call sites (`WalkProgress(continuousDuration:)`, `recordWorkingSet(exercise:)`) still compile unchanged because the new fields/parameters are defaulted.
- **Committed in:** `1356e43` (Task 2 commit)

**2. [Rule 1 - Bug] provisional's pace zone was a running pace, not a comfortable walking pace**
- **Found during:** Task 2 (Baseline derivation), during advisor review before commit
- **Issue:** The initial draft used `PaceZone(420, 360)` (360-420 seconds/km, ~8.5-10 km/h) commented as "a comfortable 6:00-7:00 /km walking pace band" — that comment described a value roughly 100 s/km slower than what was actually coded, and the coded value is a running pace, not a walk. D-03 requires the provisional default to "err toward under-loading" a user of unknown capacity; handing a running pace to that user is the wrong direction.
- **Fix:** Changed to `PaceZone(840, 660)` (660-840 seconds/km, ~4.3-5.5 km/h), a genuine comfortable-walk band, with the comment corrected to match.
- **Files modified:** `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift`
- **Verification:** `provisionalIsNeverBlank` test still passes (non-zero pace zone); no test asserted the specific numeric band, so this was caught by review rather than a failing test — flagged here for visibility.
- **Committed in:** `1356e43` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes were necessary for `derive` to produce values that actually respond to measurement (Rule 3) and for the provisional default to actually be conservative (Rule 1), per D-03/D-04's correctness requirements. No scope creep — no new public symbols beyond what the plan's `<artifacts_produced>` table specifies; the additions are internal measurement fields on the two progress structs already scoped to this plan.

## Issues Encountered
None beyond the deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `CalibrationThreshold`, `CalibrationCompletion.evaluate`, and `CalibrationSessionSource` are ready for plan 01-15's CoreMotion pedometer and manual stopwatch adapters to conform to — both should populate `distanceMeters`/`loadKg` where available so `CalibrationBaseline.derive` produces a genuinely measured baseline rather than falling back to provisional values
- Phase 3's Momentum qualifying-session bar (MOMENTUM-01) should reference `CalibrationThreshold.qualifyingWorkingSets`/`.qualifyingExercises` directly rather than restating the numbers, per this plan's cross-phase note
- Full `RithamCore` suite is green: 66 tests across 8 suites (`cd RithamCore && ./Scripts/test-core.sh`)
- No blockers for downstream plans

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-25*

## Self-Check: PASSED

All 4 created source/test files verified present on disk; all 3 commit hashes (9425c6c, 1356e43, 1e2a411) verified in git log.
