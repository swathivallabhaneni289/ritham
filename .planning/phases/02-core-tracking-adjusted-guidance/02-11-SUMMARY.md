---
phase: 02-core-tracking-adjusted-guidance
plan: 11
subsystem: ui
tags: [swiftui, strength, plate-calculator, supersets, movement-pattern, swiftdata]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "ExerciseCatalog/MovementPattern (02-02), PlateCalculator/Equipment/OneRepMaxCalculator (02-02), SupersetGrouping/LiftSession/LiftQualification (02-03), HealthDataStore lift-session CRUD/autoFillSet/applyRevision (02-08)"
provides:
  - "ExercisePickerView: sheet-presented, searchable picker over ExerciseCatalog.all with read-only movement-pattern labels"
  - "StrengthSessionView: real strength-session step screen (set entry with auto-fill, superset join/ungroup, qualification display, session save)"
  - "PlateCalculatorView: sheet-presented plate/1RM calculator across all five Equipment kinds, applying the achievable weight back to a set"
  - "StrengthLoggingRegistration.swift rewritten to register the real screen for .strengthSession (placeholder retired)"
affects: [02-12, 02-13, 02-14, 02-15]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Screen-level @Observable model classes (StrengthSessionModel, PlateCalculatorModel) hold all testable behavior; the View is a thin renderer over them, matching CardioSessionView/CardioActivityPickerModel's established Phase 2 pattern"
    - "Domain-first delegation: no numeric qualifying threshold, no plate arithmetic, and no auto-fill filtering logic lives in any view file -- every one of those calls straight into RithamCore or HealthDataStore"
    - "Superset display sections are derived purely from per-set supersetGroupID reads (groupID(forExercise:)), never a separate grouping model the view maintains itself"

key-files:
  created:
    - RithamApp/Ritham/Strength/Views/ExercisePickerView.swift
    - RithamApp/Ritham/Strength/Views/StrengthSessionView.swift
    - RithamApp/Ritham/Strength/Views/PlateCalculatorView.swift
    - RithamApp/RithamTests/StrengthLoggingTests.swift
  modified:
    - RithamApp/Ritham/Strength/StrengthLoggingRegistration.swift

key-decisions:
  - "Pre-fill seeding happens once per exercise section, from HealthDataStore.autoFillSet(forExercise:) alone -- the in-progress (unsaved) session's own just-logged sets are never consulted as a second auto-fill source, matching the plan's explicit 'this screen must not filter or fall back on its own' instruction"
  - "isInvalidInput on PlateCalculatorModel is true whenever result == nil (including an empty target field), matching the plan's literal behavior list ('negative, empty or non-numeric... shows an invalid-input state') rather than suppressing the error state on an untouched field"
  - "Superset join/ungroup wiring and the plate-calculator sheet were both added to StrengthSessionView.swift during Task 3 (not Task 2), since Task 2's own file list didn't include StrengthSessionView.swift but Task 3's did, and 'reachable from set entry' is a plan-level success criterion that needed a legitimate task to land in"

requirements-completed: [STRENGTH-01, STRENGTH-02, STRENGTH-03, STRENGTH-04]

coverage:
  - id: D1
    description: "Exercise picker lists the seeded ExerciseCatalog, searchable by display name, showing each entry's auto-assigned movement pattern(s) as read-only labels"
    requirement: "STRENGTH-04"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#StrengthSetEntryTests (pickerListsSeededCatalog, searchingNarrowsToMatchingExercises, emptySearchReturnsFullCatalog, exercisePatternsComeFromCatalog)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Set entry pre-fills weight/reps from the most recent working set for a previously logged exercise, leaves both empty for a never-logged exercise, and excludes warm-up sets from the auto-fill source"
    requirement: "STRENGTH-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#StrengthSetEntryTests (neverLoggedExercisePrefillsNothing, loggedExercisePrefillsFromMostRecentWorkingSet, warmUpSetExcludedFromAutoFill, editedValueOverridesPrefill)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plate calculator covers all five Equipment kinds, routes pin-stack equipment away from plate arithmetic, renders an invalid-input state (never a force-unwrap or substituted zero) for a negative/empty/non-numeric target, and reports a non-loadable target's achievable weight as nearest rather than exact"
    requirement: "STRENGTH-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#PlateCalculatorScreenTests (choosingEquipmentSetsDefaultBarWeight, choosingPinStackReportsPinStack, pinStackRoundsToNearestIncrementWithNoPlateList, exactlyLoadableTargetReportsExactMatch, nonLoadableTargetReportsNearestAchievable, negativeTargetIsInvalidInput, emptyTargetIsInvalidInput, nonNumericTargetIsInvalidInput)"
        status: pass
    human_judgment: false
  - id: D4
    description: "One-rep-max estimate appears for a supported rep count, is absent for an unsupported one, and applying the calculator's result writes the achievable weight (not the typed target) back to the set being logged"
    requirement: "STRENGTH-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#PlateCalculatorScreenTests (oneRepMaxAppearsForSupportedRepCount, oneRepMaxAbsentForUnsupportedRepCount, applyingWritesAchievableWeightNotTypedTarget)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Two consecutive exercises join into one superset in a single step (no separate creation flow), render as one visually grouped block, ungroup restores standalone exercises, every set's identifier is unchanged across a join followed by an ungroup, and joining against an exercise with no working sets yet neither no-ops silently nor leaves an orphaned, ungroupable group"
    requirement: "STRENGTH-03"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#SupersetBuilderTests (joiningTwoExercisesGroupsThemInOneStep, ungroupingRestoresStandalone, joinThenUngroupLeavesSetIdentifiersUnchanged, hasWorkingSetsReflectsLoggedSets, joiningAgainstAnExerciseWithNoWorkingSetsStaysUngroupable)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Finishing saves one lift session whose stored set count equals the in-progress count, the screen reports qualification by reading LiftQualification.evaluate (not counting sets/exercises itself), and the strength-session step resolves to the real screen"
    requirement: "STRENGTH-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthLoggingTests.swift#SupersetBuilderTests (finishingSavesSessionWithMatchingSetCount, reportsQualificationFromDomainEvaluation, registersAsStrengthSessionStep)"
        status: pass
      - kind: other
        ref: "xcodebuild build -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17' -> BUILD SUCCEEDED"
        status: pass
    human_judgment: false

duration: 3h44m
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 11: Strength Logging UI Summary

**Exercise picker, set entry with previous-session auto-fill, a five-equipment-kind plate/1RM calculator, and one-step superset building -- all as thin SwiftUI screens over Phase 2's already-tested RithamCore domain and HealthDataStore accessors, with no new calculation or persistence logic.**

## Performance

- **Duration:** 3h 44m (wall-clock, first task commit to post-review fix commit; most of this was research/context-reading before code was written, not active coding time)
- **Started:** 2026-09-05T12:01:14Z
- **Completed:** 2026-09-05T15:45:05Z
- **Tasks:** 3 (plus one post-review fix)
- **Files modified:** 5 (3 new views, 1 new test file, 1 rewritten registrar) plus `Ritham.xcodeproj/project.pbxproj` regenerated

## Accomplishments
- `ExercisePickerView` -- sheet-presented, name-searchable picker over `ExerciseCatalog.all`, showing each exercise's auto-assigned movement pattern(s) as read-only labels (STRENGTH-04), with no control that lets a user pick or change one
- `StrengthSessionView`/`StrengthSessionModel` -- per-exercise set entry pre-filled from `HealthDataStore.autoFillSet(forExercise:)` (empty for a never-logged exercise, warm-ups excluded from the auto-fill source per T-02-11), one-step superset join/ungroup rendered as a visually grouped block (gated so the action never silently no-ops and never leaves an orphaned, ungroupable group -- see Deviations), qualification read from `LiftQualification.evaluate`, and finish saving through `HealthDataStore.saveLiftSession`
- `PlateCalculatorView`/`PlateCalculatorModel` -- covers all five `Equipment` kinds, routes pin-stack equipment away from plate arithmetic, renders `PlateCalculator.nearestLoadable`'s `nil` return as an explicit invalid-input state (never a force-unwrap, never a substituted zero -- T-02-06), shows a plainly-labelled one-rep-max estimate with no score/level/percentile/rating/tier framing (T-02-33), and applies the achievable weight -- never the typed target -- back to the set being logged
- `StrengthLoggingRegistration.swift` rewritten in place to register the real `StrengthSessionView` for `.strengthSession`, retiring plan 02-06's placeholder
- `StrengthLoggingTests.swift`: 31 tests across three suites (`StrengthSetEntryTests`, `PlateCalculatorScreenTests`, `SupersetBuilderTests`), all passing individually and together; full `xcodebuild build` succeeds

## Task Commits

Each task was committed atomically:

1. **Task 1: Exercise picker and set entry with previous-session auto-fill** - `4879049` (feat)
2. **Task 2: Plate calculator and one-rep-max surface** - `a23866f` (feat)
3. **Task 3: Superset building, session save, and registrar rewrite** - `8ef1011` (feat)
4. **Post-task fix (advisor review, pre-completion):** `53f26be` (fix) -- see Deviations below

_No TDD RED/GREEN split -- plan tasks are `tdd="true"` at the "write behavior + tests together, verify, commit" level (the same discipline plan 02-08 used), not a strict test-first-fails-then-passes cycle; all behaviors and their tests were authored and verified together per task before each commit._

## Files Created/Modified
- `RithamApp/Ritham/Strength/Views/ExercisePickerView.swift` - Searchable exercise picker sheet; `ExercisePickerFilter.matching(_:in:)` extracted as a standalone testable function
- `RithamApp/Ritham/Strength/Views/StrengthSessionView.swift` - `StrengthSessionModel` (auto-fill, superset join/ungroup, qualification, finish) plus the rendering screen
- `RithamApp/Ritham/Strength/Views/PlateCalculatorView.swift` - `PlateCalculatorModel` (equipment selection, nearest-loadable result, invalid-input state, 1RM estimate) plus the rendering screen
- `RithamApp/Ritham/Strength/StrengthLoggingRegistration.swift` - Rewritten to register `StrengthSessionView` for `.strengthSession`
- `RithamApp/RithamTests/StrengthLoggingTests.swift` - `StrengthSetEntryTests` (11 tests), `PlateCalculatorScreenTests` (11 tests), `SupersetBuilderTests` (9 tests, including 2 added by the post-task fix)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` so the new Strength/Views files and test additions are picked up (established Phase 2 pattern from 02-06/02-08)

## Decisions Made
- Pre-fill seeding reads `HealthDataStore.autoFillSet(forExercise:)` exactly once per exercise section and never re-derives or supplements it from the in-progress session's own newly-logged sets -- the plan's action text is explicit that this screen "must not filter or fall back on its own," so a set logged earlier in the *same unsaved* session is deliberately not itself an auto-fill source until the session is saved.
- `PlateCalculatorModel.isInvalidInput` is `true` whenever `result == nil`, including an empty target field -- matches the plan's literal behavior list ("negative, empty or non-numeric... shows an invalid-input state") rather than special-casing the untouched-field UX.
- The plate-calculator sheet and superset join/ungroup wiring both landed in `StrengthSessionView.swift` during Task 3, not Task 2: Task 2's own `<files>` list only named `PlateCalculatorView.swift`, but the plan's overall success criteria require the calculator to be "reachable from set entry," and Task 3 was the next (and only remaining) task that legitimately touched `StrengthSessionView.swift`.
- Search filtering in `ExercisePickerView` is a plain case-insensitive substring match extracted into a standalone `ExercisePickerFilter.matching(_:in:)` function rather than a `View`-private computed property, specifically so it stays testable without rendering the view (a `@State private var searchText` backing a computed property is not visible to `@testable import` from a different file).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Superset join could silently no-op and could leave an orphaned, ungroupable group**
- **Found during:** Advisor review after Task 3's commit (before this SUMMARY was finalized)
- **Issue:** `SupersetGrouping.join` (RithamCore) only assigns a group ID to a *set*, never to a bare exercise-order entry. The Task 3 "Join with next exercise" button was reachable the instant two exercises were added via the picker, before either had a logged set -- tapping it then called `join` with nothing for it to actually mark, so the action silently did nothing with no feedback. Separately, the section renderer branched on `group.count > 1` rather than group membership: if one side of a join already had a working set and the other didn't (or a join later stole one member out of an existing pair), the surviving lone grouped exercise rendered through the plain `exerciseSection` view, which has no Ungroup control -- leaving a real, orphaned `supersetGroupID` on that exercise's sets with no UI path to clear it. This also incidentally violated Task 3's own "no inline comparison of a set or exercise count against a numeric literal" acceptance criterion (`group.count > 1` is exactly that).
- **Fix:** Added `StrengthSessionModel.hasWorkingSets(forExercise:)` and gated the join action on both exercises already having a working set, so the action never no-ops. Changed the section renderer to branch on `model.groupID(forExercise:) != nil` instead of `group.count > 1`, so a lone-member group still renders with its Ungroup action.
- **Files modified:** `RithamApp/Ritham/Strength/Views/StrengthSessionView.swift`, `RithamApp/RithamTests/StrengthLoggingTests.swift`
- **Verification:** New tests `hasWorkingSetsReflectsLoggedSets` and `joiningAgainstAnExerciseWithNoWorkingSetsStaysUngroupable` (both pass); re-ran `-only-testing:RithamTests/SupersetBuilderTests` (9 tests) and a full `xcodebuild build` -- both succeed. Confirmed `StepBootstrap.swift`/`HealthDataStore.swift`/`RithamModelContainer.swift` remained untouched across the full committed range (`git diff --name-only <pre-plan-commit>..HEAD` for those three paths returns empty).
- **Committed in:** `53f26be` (separate fix commit, not amended into Task 3's commit)

---

**Total deviations:** 1 auto-fixed (1 bug, caught by advisor review before completion)
**Impact on plan:** Necessary correctness fix for STRENGTH-03's stated single-step join behavior; no scope creep, no new files, no architectural change.

## Issues Encountered

An advisor review after Task 3's own commit (but before this SUMMARY was finalized) surfaced the superset join/ungroup bug documented above. All three `-only-testing:` gates pass on the corrected code, both individually and together (31 tests, 3 suites), and the full `xcodebuild build` succeeds without warnings related to this plan's files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `StrengthSessionView` is a real, reachable screen (`HomeHubView`'s "Log strength" button already routed to `.strengthSession` before this plan; the step now resolves to real content instead of a placeholder).
- All three of this plan's `-only-testing:` gates pass individually and together (`StrengthSetEntryTests`: 11, `PlateCalculatorScreenTests`: 11, `SupersetBuilderTests`: 9 -- 31 tests, 3 suites).
- `xcodebuild build` succeeds for the whole app target.
- Neither `StepBootstrap.swift`, `HealthDataStore.swift`, nor `RithamModelContainer.swift` was touched by any task in this plan (confirmed via `git diff --name-only` per task).
- No numeric qualifying threshold and no plate arithmetic appears in any view file this plan created or modified -- both stay in `RithamCore`, read via `LiftQualification.evaluate` and `PlateCalculator.nearestLoadable`.
- Plan 02-15 (retroactive strength-session merge/split) can build on this plan's `StrengthSessionModel` and the `LiftSet.id`-preserving superset join/ungroup with no changes needed here -- set identity was explicitly asserted stable across a join+ungroup cycle.
- Known pre-existing issue (STATE.md Blockers, unrelated to this plan): the `StepRegistry` cross-suite concurrency flake affects only a full, unscoped `xcodebuild test` run across every suite in the target -- this plan's own `-only-testing:` scoped runs (individually and combined) were not affected.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 4 created files found on disk (`ExercisePickerView.swift`, `StrengthSessionView.swift`, `PlateCalculatorView.swift`, `StrengthLoggingTests.swift`); the 1 modified file (`StrengthLoggingRegistration.swift`) confirmed rewritten; all 4 commit hashes (`4879049`, `a23866f`, `8ef1011`, `53f26be`) found in `git log`.
