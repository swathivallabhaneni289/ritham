---
phase: 03-momentum-recovery
plan: 07
subsystem: ui
tags: [swiftui, swiftdata, momentum, settings, home-hub, design-system]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-05's MomentumSummary/MomentumSummaryReader (D-08's standalone reconciliation-on-read) and 03-04's HealthDataStore.supportedMomentumTargets/saveMomentumTarget/loadMomentumTarget"
  - phase: 03-momentum-recovery
    provides: "03-06's MomentumView (registered OnboardingStep.momentum, streakLine derivation, MomentumProgressBlocks/ShieldRow components) -- this plan wires flow.open(.momentum), the entry point 03-06 explicitly left undone"
provides:
  - "MomentumTargetView (RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift) -- MOMENTUM-01's Settings-sheet weekly-target picker, a near-verbatim adaptation of WorkoutFrequencyView, with its option list pinned to HealthDataStore.supportedMomentumTargets by a test"
  - "SettingsView's new 'Momentum target' row, presenting MomentumTargetView as a sheet with a freshly-loaded current value (currentMomentumTarget()), placed adjacent to Workout frequency"
  - "HomeHubView's Momentum summary section -- D-08's hub surface showing this week's progress, streak, shields, and a no-sessions empty state, reading the same MomentumSummaryReader MomentumView reads, plus the flow.open(.momentum) CTA that finally makes MomentumView reachable in the running app"
affects: [03-08, 03-09, 03-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Settings-sheet preference screen, not a registered OnboardingStep: MomentumTargetView follows WorkoutFrequencyView's exact shape (sheet, not step) since routing from inside a Settings sheet through flow.open(_:) would push behind the sheet still on screen -- documented as an explicit planning decision in the file's own header comment."
    - "Fresh-load-at-presentation-time, no view-local caching: SettingsView.currentMomentumTarget() mirrors currentWeeklyFrequency() exactly -- loads the store's current value at each sheet-presentation call rather than caching it in SettingsView's own state."
    - "Hub summary section reads MomentumSummaryReader directly in onAppear, independently of MomentumView's own reader construction -- no shared hub-owned view model, per D-08's own requirement that both surfaces read the same underlying data through independently-constructed readers, not a shared cache."

key-files:
  created:
    - RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift
    - RithamApp/RithamTests/MomentumTargetPickerTests.swift
  modified:
    - RithamApp/Ritham/Settings/SettingsView.swift
    - RithamApp/Ritham/Home/HomeHubView.swift
    - RithamApp/RithamTests/HomeHubTests.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "MomentumTargetView is a Settings-presented sheet, not a registered OnboardingStep case, despite MomentumView (03-06) being one -- recorded as an explicit planning decision in the file's own header comment with four reasons: routing from inside a sheet would push behind that sheet; every shipped Settings sub-screen is a sheet for this reason; 03-UI-SPEC.md Component 10 says this screen follows WorkoutFrequencyView exactly, which is itself a sheet; 03-RESEARCH.md's Pattern 4 names three full-screen surfaces requiring a step case, and this is not one of them."
  - "MomentumTargetOption.all is a literal-derived, sorted list built from MomentumTarget.supported at declaration time (not read from HealthDataStore.supportedMomentumTargets directly), matching WeeklyFrequencyOption's own isolation-driven rationale -- pinned to the store's constant by pickerOptionsMatchTheStoreSupportedTargets so the two lists can never silently drift."
  - "SettingsView.momentumTargetRowTitle is exposed as a static let (not an inline literal) specifically so MomentumTargetPickerTests can pin the row's label without rendering the view -- SettingsView has no existing precedent for testing a row label directly, so this is a new, minimal single-source-of-truth extraction."
  - "HomeHubView's Momentum summary section holds a plain @State private var momentumSummary: MomentumSummary?, loaded in onAppear via its own MomentumSummaryReader construction -- deliberately not a hub-owned view model wrapping the reader, so D-08's 'not baked into a hub-specific view model' requirement holds structurally, not just by convention."
  - "The hub's Momentum CTA routes to flow.open(.momentum) with a plain PrimaryCTAButton titled 'Momentum', matching the hub's existing CTA shape exactly (no new navigation container, no second navigation path) -- 03-UI-SPEC.md's Copywriting Contract has no dedicated row for this CTA's label, so 'Momentum' (matching MomentumView's own screen headline) was chosen over inventing new marketing copy."

requirements-completed: [MOMENTUM-01, MOMENTUM-03, MOMENTUM-06]

coverage:
  - id: D1
    description: "The weekly Momentum target is adjustable across all four supported values (2/3/4/5) from Settings via a fixed-choice chip picker with no free-text or arbitrary-number entry, and the picker's option list is pinned to the store's supported set by a test"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumTargetPickerTests.swift (pickerOptionsMatchTheStoreSupportedTargets, selectingEachSupportedValuePersistsAndReloadsIdentically)"
        status: pass
      - kind: other
        ref: "source grep: zero TextField/Stepper/Slider occurrences in MomentumTargetView.swift"
        status: pass
    human_judgment: false
  - id: D2
    description: "An out-of-range target can never be persisted: the store rejects anything outside the four supported values and persists nothing, leaving the previously stored value in place"
    requirement: "MOMENTUM-01, T-3-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumTargetPickerTests.swift (persistingUnsupportedValueThrowsAndLeavesStoredValueInPlace, arguments [0, 1, 6, 10, -1])"
        status: pass
    human_judgment: false
  - id: D3
    description: "The weekly Momentum target is reachable in one tap from Settings, presented as a sheet with a freshly loaded current value (never a cached one), and Settings shows no Momentum state (streak/shield count) of its own"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumTargetPickerTests.swift (settingsRowLabelForMomentumTarget, sheetPresentationLoadsFreshValueNotCached)"
        status: pass
      - kind: other
        ref: "source greps on SettingsView.swift: MomentumTargetView referenced at least once; zero currentStreak/shieldCount/MomentumSummary occurrences"
        status: pass
    human_judgment: false
  - id: D4
    description: "The interim hub shows this week's progress, the current streak, and the shield count, reading the same MomentumSummaryReader the detail screen (MomentumView) reads, satisfying D-08's single-underlying-data requirement"
    requirement: "MOMENTUM-01, MOMENTUM-03"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/HomeHubTests.swift (hubAndDetailScreenReadTheSameUnderlyingData)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The hub's Momentum section renders in the scrollable content area, never inside the hub's existing decorative header region -- the hub's own surface (DecorativeSurface.boundedHeaderOnly) is unchanged"
    verification:
      - kind: other
        ref: "source grep: grep -c \"DecorativeSurface.boundedHeaderOnly\" HomeHubView.swift returns 1"
        status: pass
    human_judgment: false
  - id: D6
    description: "No sleep-check-in state indicator, badge, dot, or 'you haven't checked in' prompt of any kind appears on the hub (RECOVERY-01 invariant 3)"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/HomeHubTests.swift (theHubShowsNoSleepCheckInStateIndicator)"
        status: pass
    human_judgment: false
  - id: D7
    description: "No share, export or invite affordance appears on the hub's Momentum section or anywhere in the Momentum directory"
    requirement: "MOMENTUM-06"
    verification:
      - kind: other
        ref: "source grep: zero ShareLink/UIActivityViewController occurrences in HomeHubView.swift and RithamApp/Ritham/Momentum/"
        status: pass
    human_judgment: false
  - id: D8
    description: "flow.open(.momentum) finally makes MomentumView reachable in the running app through the hub's existing navigation contract (no new navigation container, no second navigation path)"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/HomeHubTests.swift (openingMomentumAppendsExactlyThatStep)"
        status: pass
      - kind: other
        ref: "source grep: grep -c \"NavigationStack\" HomeHubView.swift returns 0"
        status: pass
    human_judgment: false

duration: 40min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 07: Weekly Momentum Target Picker and Interim Hub Summary Section Summary

**A Settings-sheet weekly-target picker (`MomentumTargetView`, a near-verbatim `WorkoutFrequencyView` adaptation) plus a Momentum summary section on `HomeHubView` that finally wires `flow.open(.momentum)`, making the Momentum detail screen reachable in the running app for the first time.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-09-06T16:40:00Z
- **Completed:** 2026-09-06T17:20:00Z
- **Tasks:** 3
- **Files modified:** 6 (2 new, 4 modified)

## Accomplishments
- `MomentumTargetView` makes MOMENTUM-01's weekly target user-adjustable across all four supported values (2/3/4/5) from Settings, via the exact same fixed-choice `ChoiceQuestionView` chip pattern `WorkoutFrequencyView` already ships -- no free-text, no arbitrary number, ever. `MomentumTargetOption.all`'s values are pinned to `HealthDataStore.supportedMomentumTargets` by `pickerOptionsMatchTheStoreSupportedTargets`, the same drift guard the shipped weekly-frequency screen carries for its own two lists.
- Recorded an explicit planning decision in `MomentumTargetView.swift`'s own header comment: this screen is a Settings-presented sheet, not a registered `OnboardingStep` case, with four concrete reasons (routing from inside a sheet would push behind that sheet; every shipped Settings sub-screen is a sheet for this reason; 03-UI-SPEC.md Component 10 names `WorkoutFrequencyView`, itself a sheet, as the exact precedent; 03-RESEARCH.md's Pattern 4 does not name this screen among the three requiring a step case).
- `SettingsView` gained one new row ("Momentum target"), placed adjacent to "Workout frequency" since both are weekly-cadence preferences, presenting `MomentumTargetView` with a freshly-loaded current value (`currentMomentumTarget()`, mirroring `currentWeeklyFrequency()`'s exact fresh-load-at-presentation-time pattern). Settings shows no Momentum state of its own -- pinned by a comment-filtered grep gate.
- `HomeHubView` gained a Momentum summary section in its existing scrollable content area (its own decorative surface, `DecorativeSurface.boundedHeaderOnly`, is unchanged): weekly progress blocks, the streak line with monospaced numerals, the shield row, and the catalog's no-sessions empty state -- read via the hub's own `MomentumSummaryReader` construction in `onAppear`, proven to read the same underlying data `MomentumView` reads by `hubAndDetailScreenReadTheSameUnderlyingData` (D-08).
- One `PrimaryCTAButton` on the hub routes to `flow.open(.momentum)`, closing the gap 03-06-SUMMARY.md's "Next Phase Readiness" section explicitly flagged: `MomentumView` was registered and resolvable but had no reachable entry point in the running app until this plan.
- No sleep-check-in state indicator, badge, dot, or "you haven't checked in" prompt of any kind was added to the hub (RECOVERY-01 invariant 3), and no share/export/invite affordance appears anywhere in the Momentum directory (MOMENTUM-06) -- both pinned by dedicated tests and grep gates.

## Task Commits

Each task was committed atomically:

1. **Task 1: Weekly Momentum target picker** - `1aeeae3` (feat)
2. **Task 2: Settings entry point for the Momentum target** - `c94c458` (feat)
3. **Task 3: Momentum summary section on the interim hub** - `aaca340` (feat)

**Plan metadata:** (this commit, `docs(03-07): complete plan`)

## Files Created/Modified
- `RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift` - the weekly-target picker sheet and `MomentumTargetOption`
- `RithamApp/RithamTests/MomentumTargetPickerTests.swift` - `MomentumContainerTouchingSuites/MomentumTargetPickerTests` (6 tests: option/target round-trip, copy match, unsupported-value rejection, Settings row label, fresh-load-on-reopen)
- `RithamApp/Ritham/Settings/SettingsView.swift` - added the "Momentum target" row, its sheet presentation, and `currentMomentumTarget()`
- `RithamApp/Ritham/Home/HomeHubView.swift` - added the Momentum summary section, its `onAppear` reader load, and the `flow.open(.momentum)` CTA
- `RithamApp/RithamTests/HomeHubTests.swift` - added 4 tests: `openingMomentumAppendsExactlyThatStep`, `hubAndDetailScreenReadTheSameUnderlyingData`, `theHubShowsNoSleepCheckInStateIndicator`, `hubEmptyStateMatchesCatalogNoSessionsPair`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` for the new `MomentumTargetView.swift`/`MomentumTargetPickerTests.swift` files

## Decisions Made
- `MomentumTargetView` is a Settings sheet, not a registered `OnboardingStep`, per the four-reason decision recorded in the file's own header comment (see Task Commits above).
- `MomentumTargetOption.all` is declared as its own literal-derived, sorted list (mirroring `WeeklyFrequencyOption`'s isolation rationale), pinned to `HealthDataStore.supportedMomentumTargets` by a dedicated test rather than derived at declaration time.
- `SettingsView.momentumTargetRowTitle` is a `static let`, not an inline literal, specifically so its label is testable without rendering the view -- a new, minimal precedent this codebase didn't previously need for a Settings row.
- `HomeHubView`'s Momentum section holds a plain `MomentumSummary?` loaded via its own reader construction, not a hub-owned view model wrapping the reader -- keeps D-08's "not baked into a hub-specific view model" requirement structural.
- The hub's Momentum CTA label is the literal "Momentum" (matching `MomentumView`'s own screen headline) since 03-UI-SPEC.md's Copywriting Contract has no dedicated row for this specific CTA.

## Deviations from Plan

None - plan executed exactly as written. All three tasks' acceptance criteria (source greps, named tests, and the full verification suite) passed on first implementation; the only correction was a self-caught doc-comment wording fix in `MomentumTargetView.swift` (referencing "the same flat decorative surface" in prose instead of the literal token `DecorativeSurface.flat`, to keep the acceptance criterion's `grep -c "DecorativeSurface.flat"` at exactly 1) -- caught before commit, not a deviation from any behavior or test.

## Issues Encountered
None. `Scripts/build-app.sh test -only-testing:RithamTests/SettingsPhase2Tests` (the plan's own stated verify command) matches zero tests because `SettingsPhase2Tests.swift` declares two separately-named suites (`AlwaysFreeListTests`, `WorkoutFrequencyTests`), not a suite literally named `SettingsPhase2Tests` -- a pre-existing filter-string/file-name mismatch in the plan's own `<verify>` block, not something this plan introduced. Verified the intended suites directly (`-only-testing:RithamTests/AlwaysFreeListTests -only-testing:RithamTests/WorkoutFrequencyTests`, both pass, no regression) and via the full `RithamTests` target run below.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `MomentumView` is now reachable end-to-end: `HomeHubView`'s Momentum summary section routes to it via `flow.open(.momentum)`, closing the gap 03-06-SUMMARY.md flagged as this plan's own scope.
- The weekly Momentum target is fully user-adjustable from Settings, with its option list structurally pinned to the store's supported set -- ready for 03-08/03-09's own Momentum surfaces to assume the target can only ever be one of the four supported values.
- `Scripts/build-app.sh build` succeeds; the full `RithamTests` target (352 tests, 45 suites) passes; `RithamCore/Scripts/test-core.sh` (394 tests, 30 suites) passes; `-only-testing:RithamTests/StepRegistryTouchingSuites/PhaseCoverageTests` remains green.
- No share/export/invite affordance exists anywhere in `RithamApp/Ritham/Momentum/` or on `HomeHubView` (MOMENTUM-06's private-by-default scope for this phase, confirmed by source grep) -- stays true for plan 03-10's own directory-wide close-out gate to re-verify against later plans' additions.
- Physical-device/AX3-AX5 accessibility verification for this plan's own UI is deferred to the single end-of-project batched pass, per PROJECT.md's 2026-09-06 decision (same posture as every other Phase 2/3 screen) -- not a blocker for this plan or this phase's continuation.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 2 created files verified present on disk; all 3 task commits (1aeeae3, c94c458,
aaca340) verified present in `git log --oneline --all`.
