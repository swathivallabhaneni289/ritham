---
phase: 02-core-tracking-adjusted-guidance
plan: 02
subsystem: domain-logic
tags: [swift, swift-testing, strength-training, plate-calculator, one-rep-max, movement-pattern]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake
    provides: "RithamCore's Foundation-only-core discipline and named-constant-enum pattern (CalibrationThreshold), which this plan's Equipment/PlateInventory constants and OneRepMaxCalculator's D-04 no-score-or-grade rule both follow"
provides:
  - "Equipment enum (5 STRENGTH-02 kinds) with per-case bar weight/increment and LoadingStyle routing"
  - "PlateCalculator.nearestLoadable — bounded, greedy nearest-loadable-weight algorithm"
  - "OneRepMaxCalculator.estimate — bounded Epley 1RM estimator, backing MONETIZE-01's always-free claim"
  - "MovementPattern + ExerciseCatalog — 31-exercise seeded lookup returning Set<MovementPattern>, backing STRENGTH-04's filterable auto-tagging"
affects: [02-03-lift-session-superset-editing, 02-11-strength-logging-ui, 02-14-always-free-settings-list, 02-15-strength-history]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Named-constant enum for numeric tables (PlateInventory.metricDefaultKg), mirroring CalibrationThreshold"
    - "Exhaustive per-case switch with displayName, mirroring ConditionTag/GateEscalation"
    - "Bounded-input pure functions returning nil on invalid input (ASVS V5), mirrored across PlateCalculator and OneRepMaxCalculator"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Strength/Equipment.swift
    - RithamCore/Sources/RithamCore/Strength/PlateCalculator.swift
    - RithamCore/Sources/RithamCore/Strength/OneRepMaxCalculator.swift
    - RithamCore/Sources/RithamCore/Strength/MovementPattern.swift
    - RithamCore/Tests/RithamCoreTests/PlateCalculatorTests.swift
    - RithamCore/Tests/RithamCoreTests/MovementPatternTests.swift
  modified: []

key-decisions:
  - "Equipment.defaultBarWeightKg for .stackMachine is 0 (not optional) with a doc comment explaining PlateCalculator never reads it for a pinStack equipment kind — matches the plan's explicit either/or instruction"
  - "PlateCalculator caps target at 1000 kg as the ASVS V5 'absurdly large' bound (T-02-06); no plan-specified number existed, so this is a reasonable ceiling for a human-loadable barbell weight"
  - "ExerciseCatalog seeds 31 exercises (7 push, 7 pull, 6 squat, 6 hinge, 3 carry, 2 compound), exceeding the plan's 25-minimum floor and its 2-compound-entry minimum (thruster: squat+push, clean: hinge+pull)"

requirements-completed: [STRENGTH-02, STRENGTH-04, MONETIZE-01]

coverage:
  - id: D1
    description: "Nearest-loadable-weight calculator across barbell/EZ/trap/Smith/stack equipment, bounded against non-finite/negative/absurd input"
    requirement: "STRENGTH-02"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/PlateCalculatorTests.swift#PlateCalculatorTests (8 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Bounded Epley one-rep-max estimator (1-12 rep range), presented as an estimate never a score/grade/level/percentile/rating"
    requirement: "MONETIZE-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/PlateCalculatorTests.swift#OneRepMaxCalculatorTests (5 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Movement-pattern vocabulary and 31-exercise seeded catalog returning a filterable Set<MovementPattern>, with compound lifts spanning multiple patterns"
    requirement: "STRENGTH-04"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/MovementPatternTests.swift#MovementPatternTests (8 tests)"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 2: Strength Domain — Equipment, Plate Calculator, 1RM, Movement Patterns Summary

**Pure-Swift `RithamCore/Strength` module: a 5-equipment-kind plate calculator, a bounded Epley 1RM estimator, and a 31-exercise movement-pattern lookup returning filterable pattern sets.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-05T08:09:14Z
- **Completed:** 2026-09-05T08:13:23Z
- **Tasks:** 3 completed
- **Files modified:** 6 (4 created source files, 2 created test files)

## Accomplishments
- `Equipment`/`LoadingStyle`/`PlateInventory` model the five STRENGTH-02 equipment kinds, routing `.stackMachine` to pin-increment rounding instead of plate arithmetic
- `PlateCalculator.nearestLoadable` is a bounded, pure greedy algorithm: rejects non-finite/negative/absurdly-large targets (ASVS V5, T-02-06), never returns an unloadable achieved weight
- `OneRepMaxCalculator.estimate` implements a bounded Epley formula (1-12 rep range), making MONETIZE-01's "1RM calculator" always-free claim truthful rather than aspirational
- `MovementPattern`/`ExerciseCatalog` seed 31 exercises across all five patterns (push/pull/squat/hinge/carry), including two genuinely compound entries (thruster, clean), with `patterns(for:)` returning `Set<MovementPattern>` so compound lifts are filterable under every pattern they train

## Task Commits

Each task was committed atomically:

1. **Task 1: Equipment definitions and the plate calculator** - `5f7c0c1` (feat)
2. **Task 2: One-rep-max estimator** - `9a3f46b` (feat)
3. **Task 3: Movement-pattern vocabulary and exercise lookup** - `02e8f41` (feat)

_No TDD RED/GREEN split commits were made — tests and implementation were written and verified together per task, matching this plan's existing-codebase convention (see e.g. `ClearanceGateTests`/`ConditionTag` committed together in Phase 1)._

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Strength/Equipment.swift` - `LoadingStyle`, `PlateInventory`, `Equipment` (5 cases, displayName, loadingStyle, defaultBarWeightKg, defaultIncrementKg)
- `RithamCore/Sources/RithamCore/Strength/PlateCalculator.swift` - `PlateLoad`, `PlateCalculator.nearestLoadable(target:equipment:availablePlatesKg:barWeightKg:)`
- `RithamCore/Sources/RithamCore/Strength/OneRepMaxCalculator.swift` - `OneRepMaxCalculator.estimate(weightKg:reps:)`
- `RithamCore/Sources/RithamCore/Strength/MovementPattern.swift` - `MovementPattern` (5 cases), `ExerciseDefinition`, `ExerciseCatalog` (31 seeded exercises, `patterns(for:)`, `definition(for:)`)
- `RithamCore/Tests/RithamCoreTests/PlateCalculatorTests.swift` - `PlateCalculatorTests` (8 tests) + `OneRepMaxCalculatorTests` (5 tests)
- `RithamCore/Tests/RithamCoreTests/MovementPatternTests.swift` - `MovementPatternTests` (8 tests)

## Decisions Made
- `.stackMachine`'s `defaultBarWeightKg` is `0` (not `nil`) with a doc comment explaining `PlateCalculator` never reads it for a pin-stack equipment kind — the plan explicitly allowed either shape.
- `PlateCalculator`'s "absurdly large" bound is `1000 kg` — no specific number was in the plan; this is a generous ceiling above any real human-loadable barbell total, chosen so the ASVS V5 control has a concrete value rather than being unbounded.
- `ExerciseCatalog` seeds 31 exercises (exceeding the 25-minimum) so every pattern has real depth, not just the two required compound entries.

## Deviations from Plan

None - plan executed exactly as written. All behaviors, acceptance criteria, and threat-model mitigations (T-02-06, T-02-07, T-02-08) were satisfied without needing a Rule 1-4 deviation.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `RithamCore/Strength/` is complete and independently tested; plan 02-03 (`LiftSession`, `Superset`, `SessionRevision`) can build on `Equipment`, `PlateCalculator`, and `ExerciseCatalog` without further changes here.
- Full `RithamCore` package suite is green: 214 tests across 17 suites, confirmed via `cd RithamCore && ./Scripts/test-core.sh`.
- No blockers. `PlateLoad`, `OneRepMaxCalculator.estimate`, and `ExerciseCatalog.patterns(for:)` are the three public entry points later plans (02-11 strength logging UI, 02-14 always-free Settings list) should call — no re-derivation needed.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 6 created files verified present on disk; all 3 task commit hashes (`5f7c0c1`, `9a3f46b`, `02e8f41`) verified present in git log.
