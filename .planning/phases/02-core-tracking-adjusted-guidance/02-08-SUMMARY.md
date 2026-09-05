---
phase: 02-core-tracking-adjusted-guidance
plan: 08
subsystem: database
tags: [swiftdata, persistence, cardio, strength, workout-preferences]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "CardioSession/CardioProgress (02-01), LiftSession/LiftSet/SessionRevision (02-03), CalibrationBaseline (Phase 1)"
provides:
  - "CardioSessionRecord, LiftSessionRecord, LiftSetRecord, WorkoutPreferenceRecord @Model types registered in RithamModelContainer (now 8 models, 1 store)"
  - "HealthDataStore cardio/lift session CRUD, date-range filtering, autoFillSet, and applyRevision (merge/split persistence)"
  - "HealthDataStore gate-isolated workout preferences: weekly frequency, pre-assessment completion, route-comparison opt-in"
  - "HealthDataStore.experienceLevel() / ExperienceLevel enum for workout-plan-generation scaling"
affects: [02-10, 02-11, 02-12, 02-13, 02-14, 02-15]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LiftSetRecord uses a stored sessionID field (not @Relationship) so STRENGTH-05 reparenting is a single field write"
    - "Splits serialized via a private Codable DTO (EncodedSplit) inside CardioSessionRecord.swift, kept out of RithamCore since CardioSplit is not itself Codable"
    - "applyRevision persists an already-computed SessionRevision.merge/split result; the store performs no merge/split arithmetic of its own"

key-files:
  created:
    - RithamApp/Ritham/Persistence/CardioSessionRecord.swift
    - RithamApp/Ritham/Persistence/LiftSessionRecord.swift
    - RithamApp/Ritham/Persistence/LiftSetRecord.swift
    - RithamApp/Ritham/Persistence/WorkoutPreferenceRecord.swift
    - RithamApp/RithamTests/WorkoutStoreTests.swift
    - RithamApp/RithamTests/WorkoutPreferenceTests.swift
  modified:
    - RithamApp/Ritham/Persistence/HealthDataStore.swift
    - RithamApp/Ritham/Persistence/RithamModelContainer.swift

key-decisions:
  - "Splits stored via a file-local Codable DTO rather than adding Codable to RithamCore's CardioSplit, keeping this plan's edits inside its own file list"
  - "Weekly-frequency default is 3 (the least frequent supported option), matching the codebase's established conservative-default discipline"
  - "experienceLevel() maps a provisional baseline to .beginner and a measured baseline to .intermediate; Phase 2 has no specified pace/weight-threshold mapping across all four buckets for a real measurement, so this is a documented placeholder a future phase can refine without changing the method's signature"

patterns-established:
  - "Independently addressable child records (LiftSetRecord) queried/filtered/deleted via FetchDescriptor + a stored foreign-key field, following ConditionTagRecord's precedent"

requirements-completed: [CARDIO-01, CARDIO-03, STRENGTH-01, STRENGTH-05, ONBOARD-01, MONETIZE-01]

coverage:
  - id: D1
    description: "Four new @Model record types (cardio session, lift session, lift set, workout preference) registered in the single file-protected RithamModelContainer store"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutStoreTests.swift#WorkoutStoreTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "LiftSetRecord is independently addressable with a stored owning-session identifier (not a SwiftData relationship), the precondition for STRENGTH-05's merge/split reparenting"
    requirement: "STRENGTH-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutStoreTests.swift#WorkoutStoreTests (liftSetRecordsHaveDistinctIdentifiersInSameSession, liftSetRecordSessionIDReassignmentIsAFieldWrite)"
        status: pass
    human_judgment: false
  - id: D3
    description: "HealthDataStore cardio and lift session save/load/delete accessors, including date-range filtering, with lift sessions assembled from session shell + independently stored sets"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutStoreTests.swift#WorkoutSessionStoreTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "autoFillSet(forExercise:) supplies STRENGTH-01's auto-fill data by delegating to LiftSession.mostRecentSet, never reimplementing the selection rule"
    requirement: "STRENGTH-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutStoreTests.swift#WorkoutSessionStoreTests.autoFillSetReturnsMostRecentWorkingSet"
        status: pass
    human_judgment: false
  - id: D5
    description: "applyRevision persists SessionRevision.merge/split results with no orphaned LiftSetRecord after a delete or a split"
    requirement: "STRENGTH-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutStoreTests.swift#WorkoutSessionStoreTests (applyRevisionPersistsMergeWithNoDuplicateSets, applyRevisionPersistsSplitWithNoOrphans, deletingLiftSessionLeavesNoOrphanedSets)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Gate-isolated workout preferences: weekly frequency (3/5/7, validated), pre-assessment completion flag, and route-comparison opt-in (defaults off), none read by gate resolution or tag derivation"
    requirement: "MONETIZE-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutPreferenceTests.swift#WorkoutPreferenceTests"
        status: pass
    human_judgment: false
  - id: D7
    description: "experienceLevel() derives an on-device-only ExperienceLevel bucket from the stored calibration baseline, wire-compatible with the Go plan-generation service, supporting ONBOARD-01's pre-assessment"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/WorkoutPreferenceTests.swift#WorkoutPreferenceTests (experienceLevelFromMeasuredBaselineReturnsABucket asserts level != .beginner, experienceLevelFromProvisionalBaselineReturnsLeastExperienced asserts == .beginner)"
        status: pass
    human_judgment: false

duration: 50min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 08: Persistence Facade Extension Summary

**Four new SwiftData record types (cardio session, lift session, independently-addressable lift set, workout preference) plus HealthDataStore accessors for session CRUD, auto-fill, merge/split persistence, and gate-isolated workout preferences — all in the one existing file-protected store.**

## Performance

- **Duration:** 50 min
- **Started:** 2026-09-05T10:24:26Z
- **Completed:** 2026-09-05T16:34:58+05:30
- **Tasks:** 3
- **Files modified:** 8 (4 created record files, 2 created test files, HealthDataStore.swift and RithamModelContainer.swift modified) plus Ritham.xcodeproj/project.pbxproj regenerated

## Accomplishments
- `CardioSessionRecord`, `LiftSessionRecord`, `LiftSetRecord`, `WorkoutPreferenceRecord` — four new `@Model` types, all registered in `RithamModelContainer`'s single shared, file-protected store (now 8 models, still exactly 1 `ModelContainer`)
- `HealthDataStore` gained full cardio and lift session CRUD (save/load/load-in-range/load-by-id/delete), with lift sessions assembled from a set-free session shell plus independently addressable `LiftSetRecord`s
- `autoFillSet(forExercise:)` and `applyRevision(_:replacing:)` give STRENGTH-01's auto-fill and STRENGTH-05's retroactive merge/split a working store, with explicit orphan-free guarantees
- Three gate-isolated workout preferences (weekly frequency, pre-assessment completion, route-comparison opt-in) plus an on-device `ExperienceLevel` bucket derivation, none of which any gate resolution or tag derivation logic ever reads

## Task Commits

Each task was committed atomically:

1. **Task 1: SwiftData record models and container registration** - `3e6bf2d` (feat)
2. **Task 2: Session persistence accessors on HealthDataStore** - `cb37d34` (feat)
3. **Task 3: Workout preference accessors, gate-isolated** - `da3af44` (feat)
4. **Post-task hardening (advisor review, pre-completion):** `baeb5ac` (test) — strengthened a tautological `experienceLevel()` assertion and added a re-save test for `saveLiftSession`; see Deviations below

_No TDD RED/GREEN split — plan tasks are `tdd="true"` at the "write behavior + tests together, verify, commit" level rather than a strict test-first-fails-then-passes cycle; all behaviors and their tests were authored and verified together per task before each commit._

## Files Created/Modified
- `RithamApp/Ritham/Persistence/CardioSessionRecord.swift` - Cardio session `@Model`, splits encoded via a private `EncodedSplit` Codable DTO
- `RithamApp/Ritham/Persistence/LiftSessionRecord.swift` - Set-free lift session shell `@Model`
- `RithamApp/Ritham/Persistence/LiftSetRecord.swift` - Independently addressable lift set `@Model` with a stored `sessionID` field
- `RithamApp/Ritham/Persistence/WorkoutPreferenceRecord.swift` - Single-row preference `@Model` (frequency, pre-assessment flag, route-comparison opt-in)
- `RithamApp/Ritham/Persistence/RithamModelContainer.swift` - Registered the four new models (8 total)
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` - Added cardio/lift session accessors, `autoFillSet`, `applyRevision`, three preference accessor pairs, `ExperienceLevel`/`experienceLevel()`, two new `HealthDataStoreError` cases
- `RithamApp/RithamTests/WorkoutStoreTests.swift` - `WorkoutStoreTests` (Task 1) and `WorkoutSessionStoreTests` (Task 2) suites
- `RithamApp/RithamTests/WorkoutPreferenceTests.swift` - `WorkoutPreferenceTests` suite (Task 3)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` so the new files/directory scan picks up the new source files (established Phase 2 pattern from 02-06)

## Decisions Made
- Splits are serialized through a file-local `Codable` DTO (`EncodedSplit`) rather than adding `Codable` conformance to RithamCore's `CardioSplit` — keeps this plan's edits confined to its own file list (Persistence + tests only), never touching `CardioSession.swift` which belongs to plans 02-01/02-03.
- Weekly-frequency default is 3 (the least-frequent supported option) — no default was specified in the plan or context docs; 3 matches the codebase's established "err conservative" pattern (provisional calibration baseline, least-experienced bucket).
- `experienceLevel()` maps a provisional (skipped-calibration) baseline to `.beginner` per the plan's explicit instruction, and a measured baseline to `.intermediate` — Phase 2's context and requirements never specify a pace/weight-threshold mapping across all four buckets for a real measurement, so `.intermediate` is a documented placeholder (one step above the no-assessment default) that a future phase can refine without changing this method's signature or its callers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Filled two specification gaps the plan left to discretion, with no numeric default or bucket-mapping algorithm stated anywhere in 02-CONTEXT.md/REQUIREMENTS.md/ROADMAP.md**
- **Found during:** Task 3 (workout preference accessors, gate-isolated)
- **Issue:** `saveWeeklyFrequency`/`loadWeeklyFrequency` needed a concrete "no record exists yet" default, and `experienceLevel()` needed a concrete mapping from a `.measured` `CalibrationBaseline` to one of the four `ExperienceLevel` buckets — the plan's action text and 02-CONTEXT.md's "Claude's Discretion" section establish the general approach (frequency is a Settings preference like DIET-01; experience derives from calibration with a conservative self-report fallback) but neither specifies the actual default value or a pace/weight-threshold classification algorithm.
- **Fix:** Weekly frequency defaults to 3 (the least-frequent supported option), matching the codebase's established conservative-default discipline (provisional calibration baseline, least-experienced bucket). `experienceLevel()` maps a provisional (skipped-calibration) baseline to `.beginner` (explicitly required by the plan) and a `.measured` baseline to `.intermediate` — a documented placeholder crediting a completed assessment one step above the no-assessment default, without inventing unreviewed clinical/coaching thresholds across all four buckets. Both choices are recorded in doc comments on the methods themselves so a future phase that adds real graduated scaling can find and revise them without a signature change.
- **Files modified:** `RithamApp/Ritham/Persistence/HealthDataStore.swift`
- **Verification:** `WorkoutPreferenceTests.loadWeeklyFrequencyReturnsStatedDefaultWhenNothingStored`, `.experienceLevelFromProvisionalBaselineReturnsLeastExperienced`, and `.experienceLevelFromMeasuredBaselineReturnsABucket` (strengthened post-review to assert `level != .beginner`, not merely that it's some enum case)
- **Committed in:** `da3af44` (Task 3 commit); test strengthened in `baeb5ac`

---

**Total deviations:** 1 auto-fixed (1 missing-critical / underspecified-default)
**Impact on plan:** Both filled gaps are documented, conservative, and reversible without touching call sites. No scope creep — no new files, no architectural change.

## Issues Encountered

Advisor review before completion caught two weaknesses, both closed before this SUMMARY was finalized:
- The `experienceLevel()` measured-baseline test originally asserted `ExperienceLevel.allCases.contains(level)`, which is true for any enum value and therefore not real evidence of the derivation working. Replaced with `level != .beginner`, which does distinguish the measured path from the provisional path.
- The plan's Task 3 acceptance criterion "the full app suite passes when its suites are run individually" had not been explicitly re-verified against the two pre-existing suites this plan's new `HealthDataStoreError` cases could plausibly affect (`HealthDataStoreTests`, `EditAnswerFlowTests`). Ran `-only-testing:RithamTests/HealthDataStoreTests -only-testing:RithamTests/EditAnswerFlowTests`: both pass (23 tests, 2 suites) — no regression from this plan's additive error cases.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three of this plan's `-only-testing:` gates pass individually (`WorkoutStoreTests`: 6 tests, `WorkoutSessionStoreTests`: 8 tests, `WorkoutPreferenceTests`: 8 tests) and together (22 tests, 3 suites) in one run.
- The two pre-existing suites this plan's new `HealthDataStoreError` cases could plausibly affect also pass individually and together, confirming no regression: `HealthDataStoreTests` + `EditAnswerFlowTests` (23 tests, 2 suites).
- `RithamModelContainer` still constructs exactly one `ModelContainer` over one schema, now carrying eight models — verified via `grep -c 'ModelContainer('` (1) and the four new `.self` registrations (4).
- Plans 02-10 through 02-15 can now build their cardio-tracking, strength-tracking, auto-fill, merge/split UI, and preference-editing features against this store without ever touching `HealthDataStore.swift` or `RithamModelContainer.swift` themselves — this plan is their sole Phase 2 editor, confirmed by `git log` showing only this plan's commits against those two files so far.
- No blockers. The pre-existing `StepRegistry` cross-suite concurrency flake (documented in STATE.md Blockers) is orthogonal to this plan's `-only-testing:`-scoped gates and was not triggered.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 7 created files found on disk; all 4 commit hashes (3e6bf2d, cb37d34, da3af44, baeb5ac) found in git log.
