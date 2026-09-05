---
phase: 02-core-tracking-adjusted-guidance
plan: 14
subsystem: ui
tags: [swiftui, swiftdata, settings, monetization, preferences]

requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "HealthDataStore.loadWeeklyFrequency/saveWeeklyFrequency/supportedWeeklyFrequencies (plan 02-08); SettingsView's sheet-presented entry-point pattern and DietPlanView.persistDiet isolation discipline (Phase 1 + 02-08)"
provides:
  - "AlwaysFreeListView: the MONETIZE-01 visible always-free capability list, reachable from Settings"
  - "AlwaysFreeCapability: the single declared 7-entry capability collection the list renders and tests read"
  - "WorkoutFrequencyView: the fixed-choice weekly workout-frequency Settings preference"
  - "WeeklyFrequencyOption: the Identifiable wrapper around the three supported frequency values"
  - "Two new sheet-presented entry points on SettingsView"
affects: [settings, monetization, momentum, recommendations]

tech-stack:
  added: []
  patterns:
    - "Sheet-presented Settings sub-screen (DietPlanView's own pattern), reused for both new screens"
    - "Isolated preference write: only the gate-isolated store accessor, never GateResolution/TagDerivation/saveScreeningResult"
    - "Load-at-presentation-time + init-set @State, avoiding an onAppear/onChange double-persist loop"

key-files:
  created:
    - RithamApp/Ritham/Settings/AlwaysFreeListView.swift
    - RithamApp/Ritham/Settings/WorkoutFrequencyView.swift
    - RithamApp/RithamTests/SettingsPhase2Tests.swift
  modified:
    - RithamApp/Ritham/Settings/SettingsView.swift

key-decisions:
  - "The always-free list deliberately omits heart-rate display (MONETIZE-01's original wording names it) because this build has no wearable-pairing capability at all -- naming it would violate the list's own 'matches what's actually gated (or not) elsewhere' property. Documented in-source, citing WEAR-01 (v2) as the requirement that will restore it."
  - "WeeklyFrequencyOption.all is a hardcoded [3, 5, 7] literal, not derived from HealthDataStore.supportedWeeklyFrequencies at declaration time -- that constant lives on @MainActor-isolated HealthDataStore, and the option type must stay nonisolated to satisfy Identifiable generically for ChoiceQuestionView. A dedicated test (weeklyFrequencyOptionsMatchSupportedFrequencies) asserts byte-for-byte equality against the store's constant so the two can never silently drift."
  - "WorkoutFrequencyView's initial selection is loaded by SettingsView at sheet-presentation time and passed into the view's init, rather than loaded via onAppear inside the view itself -- setting @State via init never fires onChange on first render, avoiding a redundant persist of the value the screen was just opened with."

requirements-completed: [MONETIZE-01]

coverage:
  - id: D1
    description: "Settings shows a visible always-free list naming manual-stopwatch tracking, GPS tracking, full training history, the plate calculator, the one-rep-max estimate, superset support, and movement-pattern tagging -- every entry actually present in this build -- with no purchase/subscribe/upgrade affordance anywhere, and an in-source record of the deliberate heart-rate-display omission naming WEAR-01."
    requirement: MONETIZE-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/SettingsPhase2Tests.swift#AlwaysFreeListTests (5 tests)"
        status: pass
      - kind: other
        ref: "grep -c 'AlwaysFreeListView' RithamApp/Ritham/Settings/SettingsView.swift == 1"
        status: pass
      - kind: other
        ref: "grep -viE '^[[:space:]]*//' AlwaysFreeListView.swift | grep -ciE 'heart rate|heartRate' == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Settings offers a fixed-choice weekly workout frequency (3/5/7 days) that persists, reloads as selected on reopen, is changeable at any time with no confirmation step, and provably leaves stored condition tags and the stored dietary pattern untouched."
    requirement: MONETIZE-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/SettingsPhase2Tests.swift#WorkoutFrequencyTests (5 tests, including frequencyWriteLeavesConditionTagsAndDietaryPatternUnchanged)"
        status: pass
      - kind: other
        ref: "git diff --name-only c480a2f 72c0647 excludes RithamApp/Ritham/Persistence/HealthDataStore.swift"
        status: pass
      - kind: other
        ref: "xcodebuild build -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17'"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 14: Settings -- Always-Free List and Workout Frequency Summary

**MONETIZE-01's visible always-free capability list plus a gate-isolated, fixed-choice weekly workout-frequency preference, both reachable from Settings as sheet-presented sub-screens**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-05T16:03:00Z
- **Completed:** 2026-09-05T16:38:07Z
- **Tasks:** 2 completed
- **Files modified:** 4 (2 created, 1 modified [SettingsView.swift touched by both tasks], 1 test file created then extended, plus Ritham.xcodeproj/project.pbxproj regenerated twice)

## Accomplishments

- `AlwaysFreeListView` renders `AlwaysFreeCapability.all` -- a single declared 7-entry collection (manual-stopwatch tracking, GPS-tracked cardio, full training history, plate calculator, one-rep-max estimate, superset support, movement-pattern tagging) -- stating plainly these are free permanently, never a trial, with no subscription and no premium tier anywhere on the screen.
- Heart-rate display is deliberately not named: this build has no wearable-pairing capability, and naming an unbuilt capability would break the list's own "matches what's actually gated (or not) elsewhere" property. The omission is documented in-source, citing WEAR-01 (v2) as the requirement that restores it.
- A separate statement documents that streak-forgiveness mechanics (shields, comeback repair, injury guardrail) are a permanent, never-monetized decision, while being explicit they arrive with the Momentum streak system rather than claiming they exist in this build.
- `WorkoutFrequencyView` offers exactly the three store-supported weekly frequencies via `ChoiceQuestionView`'s fixed-choice chip picker (no free text, no arbitrary number), writes through `HealthDataStore.saveWeeklyFrequency` alone, and never touches `GateResolution`, `TagDerivation`, or `saveScreeningResult` -- the same isolation discipline `DietPlanView.persistDiet` already established for the dietary pattern.
- Both screens are reachable from Settings in one tap via new `SecondaryCTAButton` + `.sheet` entry points, following the exact pairing `SettingsView` already uses for the diet plan.

## Task Commits

Each task was committed atomically:

1. **Task 1: Visible always-free capability list** - `c480a2f` (feat)
2. **Task 2: Weekly workout-frequency preference** - `72c0647` (feat)

**Plan metadata:** committed alongside this SUMMARY (see repository history)

_No TDD RED/GREEN split was applied as separate commits per task -- both tasks were implemented and verified against their full acceptance-criteria test suites before a single commit each, consistent with how this phase's other single-file-addition plans have committed (e.g. 02-08, 02-13)._

## Files Created/Modified

- `RithamApp/Ritham/Settings/AlwaysFreeListView.swift` - `AlwaysFreeListView` + `AlwaysFreeCapability` (the declared capability collection, commitment statement, and forgiveness statement)
- `RithamApp/Ritham/Settings/WorkoutFrequencyView.swift` - `WorkoutFrequencyView` + `WeeklyFrequencyOption`
- `RithamApp/RithamTests/SettingsPhase2Tests.swift` - `AlwaysFreeListTests` (5 tests) and `WorkoutFrequencyTests` (5 tests)
- `RithamApp/Ritham/Settings/SettingsView.swift` - two new `SecondaryCTAButton` + `.sheet` entry points ("Always free", "Workout frequency"), plus `currentWeeklyFrequency()` helper; nothing else in this file changed
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each task's new file, per this phase's established discipline (02-06)

## Decisions Made

- Heart-rate display omitted from the always-free list by design; WEAR-01 (v2) is the requirement that restores it. See `key-decisions` in frontmatter.
- `WeeklyFrequencyOption.all` is a hardcoded `[3, 5, 7]` literal rather than derived from `HealthDataStore.supportedWeeklyFrequencies` at declaration time, to keep the option type nonisolated (required for its generic `Identifiable` use in `ChoiceQuestionView`) while `HealthDataStore` itself stays `@MainActor`. A dedicated test pins the two lists together so they cannot silently drift.
- `WorkoutFrequencyView`'s initial selection is supplied via `init` (loaded by `SettingsView` at sheet-presentation time), not loaded in the view's own `onAppear` -- this avoids a redundant `onChange`-triggered persist of the value the screen was just opened with.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] `WeeklyFrequencyOption` could not derive its option list from `HealthDataStore.supportedWeeklyFrequencies` at declaration time**
- **Found during:** Task 2
- **Issue:** An initial implementation computed `WeeklyFrequencyOption.all` from `HealthDataStore.supportedWeeklyFrequencies` directly. `HealthDataStore` is `@MainActor`, so that static constant is main-actor-isolated; a nonisolated static initializer reading it failed to compile ("main actor-isolated default value in a nonisolated context"). Marking `WeeklyFrequencyOption` itself `@MainActor` to fix the first error then broke its `Identifiable` conformance for `ChoiceQuestionView<Option: Hashable & Identifiable>`, which requires a nonisolated conformance.
- **Fix:** `WeeklyFrequencyOption.all` is now a plain `[3, 5, 7]` literal declared inside `WorkoutFrequencyView.swift`, with a doc comment explaining why it isn't derived from the store constant. `WorkoutFrequencyTests.weeklyFrequencyOptionsMatchSupportedFrequencies` asserts the two lists stay byte-for-byte identical, so a future change to `supportedWeeklyFrequencies` without a matching update here fails a test rather than silently drifting.
- **Files modified:** `RithamApp/Ritham/Settings/WorkoutFrequencyView.swift`
- **Verification:** `xcodebuild test -only-testing:RithamTests/WorkoutFrequencyTests` passes (5/5); `xcodebuild build` succeeds.
- **Committed in:** `72c0647` (part of Task 2's commit)

---

**Total deviations:** 1 auto-fixed (Rule 3)
**Impact on plan:** Compile-time-only fix with no behavioral change to the shipped screen; no scope creep.

## Issues Encountered

None beyond the deviation documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- MONETIZE-01 is now fully shipped: the always-free list is visible in-app, names only capabilities this build actually has, and no monetization infrastructure of any kind exists anywhere in the codebase.
- The weekly workout-frequency preference is available for plan 02-16's Go-service `plan.Generate` caller (and any future Recommendations-surface work) to read via `HealthDataStore.loadWeeklyFrequency()`.
- Both screens are wired into the running app via `SettingsView`, itself reachable from `HomeHubView` (plan 02-06) -- so both are genuinely usable in the running app, not just unit-tested in isolation. Per this plan's own known limitation (documented across this phase, e.g. `02-VALIDATION.md`/`STATE.md`), no touch-injection interactive click-through was run in this environment (no idb/XCUITest available, only simctl); that interactive UAT pass remains open alongside the phase's other pending interactive checks.
- No blockers for the remaining Phase 2 plans (02-15, 02-16).

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

- FOUND: RithamApp/Ritham/Settings/AlwaysFreeListView.swift
- FOUND: RithamApp/Ritham/Settings/WorkoutFrequencyView.swift
- FOUND: RithamApp/RithamTests/SettingsPhase2Tests.swift
- FOUND commit: c480a2f
- FOUND commit: 72c0647
