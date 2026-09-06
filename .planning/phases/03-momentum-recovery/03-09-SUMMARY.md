---
phase: 03-momentum-recovery
plan: 09
subsystem: ui
tags: [swiftui, swift-testing, momentum, movement-snapshot, ritham-core]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-05's WorkoutPreferenceRecord.movementSnapshotOptIn plus HealthDataStore.loadMovementSnapshotOptIn/saveMovementSnapshotOptIn/movementSnapshotDays(in:); 03-07's MomentumTargetView Settings-sheet precedent; 03-08's OnboardingStep/HomeHubView state immediately prior to this plan's own edits to the same two files"
provides:
  - "MovementSnapshotToggleView -- a Settings-presented opt-in preference screen using the app's existing two-option ChoiceQuestionView chip control instead of a first-ever native Toggle"
  - "MovementSnapshotView -- a registered OnboardingStep.movementSnapshot screen rendering a plain month grid of day cells derived from HealthDataStore.movementSnapshotDays(in:), with no streak/shield/target/milestone of any kind, living in its own MovementSnapshot/ directory so that constraint is directory-scoped and mechanically checkable"
  - "MovementSnapshotRegistration -- the feature's own registrar, called once from Phase3StepRegistration.registerAll()"
  - "HomeHubView.showsMovementSnapshotEntry(optIn:)/routingSteps(movementSnapshotOptIn:) -- the opt-in-gated hub entry and its pure, testable derivation"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Directory-scoped structural boundary: an entire feature area lives in its own directory so a 'references no type X' requirement becomes a mechanical, comment-filtered directory scan (theSnapshotScreenReferencesNoMomentumType) rather than a per-file reading"
    - "Two-option ChoiceQuestionView chip control reused for a binary Settings preference instead of introducing a first-ever native SwiftUI.Toggle, per a measured-contrast rationale recorded in the view's own header comment"
    - "Real body logic and its test-facing pure derivation are the same function (HomeHubView.showsMovementSnapshotEntry(optIn:)), not a parallel copy, so a test suite exercises the exact logic the rendered screen uses"

key-files:
  created:
    - RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotToggleView.swift
    - RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift
    - RithamApp/Ritham/MovementSnapshot/MovementSnapshotRegistration.swift
    - RithamApp/RithamTests/MovementSnapshotViewTests.swift
  modified:
    - RithamApp/Ritham/Settings/SettingsView.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift
    - RithamApp/Ritham/Momentum/Phase3StepRegistration.swift
    - RithamApp/Ritham/Home/HomeHubView.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "MovementSnapshotToggleView uses the app's existing two-option ChoiceQuestionView/ChoiceChip pattern rather than a first-ever native SwiftUI.Toggle -- a native Toggle's default on-state track tinted RithamColor.hot would put a white knob on a coral track at roughly 2.8:1 contrast, below the 3:1 WCAG non-text floor, per 03-UI-SPEC.md Component 9's own binding decision."
  - "MovementSnapshotView lives in its own RithamApp/Ritham/MovementSnapshot/ directory rather than under Momentum/ (03-RESEARCH.md's suggested placement) -- a deliberate departure recorded in the file's header, turning 'carries no streak, shield or target' into a directory-scoped, mechanically checkable constraint (a comment-filtered grep gate plus theSnapshotScreenReferencesNoMomentumType) instead of a per-file reading."
  - "The day grid's marked/unmarked distinction never uses RithamColor.hot (coral means 'Momentum progress' in this phase's vocabulary) -- shape (filled vs. outline) plus opacity is the non-color-alone channel instead, matching ShieldRow/MomentumProgressBlocks's own WCAG 1.4.1 discipline with a disjoint palette."
  - "Rule 3 deviation: added OnboardingStep.movementSnapshot to OnboardingRouter.nextStep's exhaustive terminal-steps switch and updated OnboardingFlowStateTests' hardcoded step count (26 -> 27) -- the identical compile/test-gate necessity 03-06/03-08 recorded for .momentum/.sleepCheckIn, not named in this plan's own file list."
  - "HomeHubView.showsMovementSnapshotEntry(optIn:) is called directly by the real view body (not duplicated in a test-only copy), so MovementSnapshotViewTests exercises the exact conditional the rendered screen uses; HomeHubView.routingSteps(movementSnapshotOptIn:) is a separate pure derivation built on top of it for the hub's flow.open(_:)-reachable destination list."

requirements-completed: [MOMENTUM-07]

coverage:
  - id: D1
    description: "The Daily Movement Snapshot is off by default and turned on only by explicit user choice in Settings, via the app's existing two-option chip control rather than a first-ever native switch"
    requirement: "MOMENTUM-07"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotViewTests.swift (optInDefaultsToOffOnEmptyStore, selectingOnOptionPersistsTrueAndReloads, selectingOffOptionPersistsFalseAndReloads, screenLabelHelperAndOptionsMatchMomentumCopy, settingsRowLabelForMovementSnapshot, sheetPresentationLoadsFreshValueNotCached)"
        status: pass
      - kind: other
        ref: "grep -rh 'Toggle(' RithamApp/Ritham/MovementSnapshot/ | grep -v '^\\s*//' | wc -l == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "MovementSnapshotView is a registered step rendering a plain calendar with no streak/shield/target/milestone, structurally enforced as a directory-scoped reference-absence check, deriving marked days from logged (not qualifying) activity"
    requirement: "MOMENTUM-07"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotViewTests.swift (monthWithCardioSessionMarksExactlyThatDay, monthWithLiftSessionMarksExactlyThatDay, monthWithNonQualifyingSessionStillMarksThatDay, monthWithNoSessionRendersEmptyState, theSnapshotScreenReferencesNoMomentumType, movementSnapshotResolvesToMovementSnapshotView, registryReportsNoUnregisteredSteps)"
        status: pass
      - kind: other
        ref: "grep -rhE 'MomentumSummary|MomentumStateRecord|MomentumProgressBlocks|ShieldRow|MilestoneBadgeList|currentStreak|shieldCount|weeklyTarget' RithamApp/Ritham/MovementSnapshot/ | grep -v '^\\s*//' | wc -l == 0; grep -rh 'RithamColor.hot' RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift | grep -v '^\\s*//' | wc -l == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "The snapshot is reachable from the hub only when the user has opted in, renders apart from the Momentum summary section, and leaves no residue (no disabled row, no prompt) when opted out"
    requirement: "MOMENTUM-07"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MovementSnapshotViewTests.swift (hubRoutingListIncludesSnapshotWhenOptInOn, hubRoutingListOmitsSnapshotWhenOptInOff, hubRendersNoSnapshotElementWhenOptInOff, theSnapshotEntryIsNotAdjacentToTheMomentumSummary); RithamApp/RithamTests/HomeHubTests.swift (full suite, no regression)"
        status: pass
    human_judgment: false

duration: 65min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 09: Daily Movement Snapshot (Settings Opt-In, Calendar Screen, Hub Entry) Summary

**MOMENTUM-07's Daily Movement Snapshot -- an off-by-default Settings opt-in using the app's existing two-option chip control (never a first-ever native Toggle), a registered plain-calendar step deriving marked days from logged activity, and an opt-in-gated hub entry -- with the entire feature living in its own directory so "carries no streak, shield or target" is a mechanically checkable, directory-scoped constraint rather than a per-file reading.**

## Performance

- **Duration:** ~65 min
- **Started:** 2026-09-06T17:35:00Z
- **Completed:** 2026-09-06T18:55:00Z
- **Tasks:** 3
- **Files modified:** 11 (4 new, 7 modified)

## Accomplishments
- `MovementSnapshotToggleView` -- a sheet-presented Settings preference near-verbatim adapted from `WorkoutFrequencyView`/`MomentumTargetView`'s own shape, using a two-option `ChoiceQuestionView` chip picker (On/Off) instead of a first-ever native `SwiftUI.Toggle`. The file's header comment records the exact measured-contrast rationale (03-UI-SPEC.md Component 9) for rejecting a native switch. Off by default via `HealthDataStore.loadMovementSnapshotOptIn()`'s own default.
- `SettingsView` gained one entry (dedicated presentation-state property, secondary CTA row, sheet, fresh-load helper) matching the diet-plan/workout-frequency/Momentum-target shape exactly.
- `OnboardingStep.movementSnapshot` added and registered in the same plan that introduces it -- `MovementSnapshotView` (a plain month grid of day cells from `HealthDataStore.movementSnapshotDays(in:)`, marked/unmarked via shape and opacity, never `RithamColor.hot`) is reachable via `MovementSnapshotRegistration`, called once from `Phase3StepRegistration.registerAll()`. `StepBootstrap.swift` is unchanged.
- The whole feature lives in `RithamApp/Ritham/MovementSnapshot/` rather than under `Momentum/` (a deliberate departure from 03-RESEARCH.md's suggested placement, recorded in `MovementSnapshotView.swift`'s header) -- this turns "references no Momentum type" into a directory-scoped, mechanically checkable constraint. `theSnapshotScreenReferencesNoMomentumType` enumerates every `.swift` file under that directory and asserts zero non-comment references to `MomentumSummary`/`MomentumStateRecord`/`MomentumProgressBlocks`/`ShieldRow`/`MilestoneBadgeList`/`currentStreak`/`shieldCount`/`weeklyTarget`.
- `HomeHubView` gained one opt-in-gated `SecondaryCTAButton` routing to `.movementSnapshot`, placed below the tracking/Momentum entries and outside `momentumSection` so the snapshot never reads as part of the Momentum block, including by mere adjacency (D-09). The opt-in is loaded in the hub's one existing appearance handler alongside the Momentum summary load -- no second `onAppear` was added. An off opt-in renders nothing at all: no disabled row, no prompt.
- `MovementSnapshotViewTests` grew to 24 tests across two suites (nested under `MomentumContainerTouchingSuites` and `StepRegistryTouchingSuites` respectively) covering the toggle's default/round-trip/copy, the calendar's derivation from cardio/lift/non-qualifying sessions and its empty state, the directory-wide no-Momentum-type scan, step registration, and the hub's opt-in-gated routing including a bounded source scan (`theSnapshotEntryIsNotAdjacentToTheMomentumSummary`) proving the entry's code never sits inside the Momentum summary section.

## Task Commits

Each task was committed atomically:

1. **Task 1: Settings opt-in for the Daily Movement Snapshot** - `39f5414` (feat)
2. **Task 2: Plain calendar screen, step case, and feature registrar** - `4d6abbe` (feat)
3. **Task 3: Opt-in-gated hub entry** - `3ee912b` (feat)

**Plan metadata:** (this commit, `docs(03-09): complete plan`)

## Files Created/Modified
- `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotToggleView.swift` - the Settings opt-in sheet, `MovementSnapshotOptInOption` wrapper
- `RithamApp/Ritham/Settings/SettingsView.swift` - added the Movement Snapshot entry (state, row, sheet, fresh-load helper, row-title constant)
- `RithamApp/Ritham/MovementSnapshot/Views/MovementSnapshotView.swift` - the registered calendar screen, its pure month-range/title/day-number/accessibility-label derivations
- `RithamApp/Ritham/MovementSnapshot/MovementSnapshotRegistration.swift` - the feature's own registrar
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift` - added the `movementSnapshot` case
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` - added `.movementSnapshot` to the terminal-steps switch (Rule 3)
- `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift` - updated the hardcoded `OnboardingStep.allCases.count` (26 -> 27) (Rule 3)
- `RithamApp/Ritham/Momentum/Phase3StepRegistration.swift` - gained one call to `MovementSnapshotRegistration.registerAll()`
- `RithamApp/Ritham/Home/HomeHubView.swift` - added the opt-in-gated CTA, its loaded state, and the two pure derivations (`showsMovementSnapshotEntry`/`routingSteps`)
- `RithamApp/RithamTests/MovementSnapshotViewTests.swift` - 24 tests across `MovementSnapshotViewTests` (container-backed) and `MovementSnapshotRegistrationTests` (registry-backed)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` for the new MovementSnapshot source/test files (Tasks 1-2; unchanged in Task 3, which added no new files)

## Decisions Made
- Used the app's existing two-option `ChoiceQuestionView`/`ChoiceChip` pattern for the Settings opt-in instead of a first-ever native `Toggle`, per 03-UI-SPEC.md Component 9's measured-contrast rationale.
- Placed `MovementSnapshotView`/`MovementSnapshotToggleView`/`MovementSnapshotRegistration` in their own `MovementSnapshot/` directory (not `Momentum/`) so "references no Momentum type" is a directory-scoped, mechanically checkable constraint.
- The day grid never uses `RithamColor.hot`; marked/unmarked days are distinguished by shape (filled vs. outline) plus opacity, matching `ShieldRow`/`MomentumProgressBlocks`'s WCAG 1.4.1 discipline with a disjoint palette.
- `HomeHubView.showsMovementSnapshotEntry(optIn:)` is the single function both the real view body and the test suite call, avoiding a parallel test-only copy that could drift from actual rendering logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated `OnboardingRouter.nextStep`'s exhaustive switch and `OnboardingFlowStateTests`' hardcoded step count for the new `.movementSnapshot` case**
- **Found during:** Task 2, immediately after adding the case to `OnboardingStep`
- **Issue:** `OnboardingStep` is an exhaustive `CaseIterable` enum; the router's switch over it is exhaustive by compiler enforcement, so adding a case without adding it to the terminal-steps branch is a build error. `OnboardingFlowStateTests.phase2StepsRoundTripThroughRawValue` also asserts `OnboardingStep.allCases.count == 26` by literal value. Neither file is in this plan's stated file list, but 03-06/03-08's own summaries recorded the identical necessity for `.momentum`/`.sleepCheckIn`.
- **Fix:** Added `.movementSnapshot` alongside `.momentum`/`.sleepCheckIn` in the terminal-steps case, and updated the hardcoded count from 26 to 27.
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift`, `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift`
- **Verification:** `RithamCore/Scripts/test-core.sh` passes (394 tests, 30 suites).
- **Committed in:** `4d6abbe` (Task 2 commit)

**2. [Rule 1 - Bug] A test-scoped source-scan marker collision caused a false test failure, fixed before commit**
- **Found during:** Task 3, first test run of `theSnapshotEntryIsNotAdjacentToTheMomentumSummary`
- **Issue:** The test located the Momentum summary section's source by searching for the substring `"D-08's Momentum summary section"`, but that exact fragment also appears earlier in `HomeHubView.swift` inside `momentumSummary`'s own `@State` doc comment ("D-08's Momentum summary section state: a plain..."). `String.range(of:)` matched that earlier occurrence, so the captured "section source" spanned from mid-`body` to end-of-file -- including this plan's own new bottom-of-file extension, whose doc comments legitimately name the snapshot entry, causing a false failure.
- **Fix:** Narrowed the marker to the unique `"MARK: - D-08's Momentum summary section"` heading, and bounded the captured range's upper edge to the start of the file's own `extension HomeHubView` block, so the test scans exactly the `momentumSection` computed property's source, no more.
- **Files modified:** `RithamApp/RithamTests/MovementSnapshotViewTests.swift`
- **Verification:** Test passes; all 28 tests in `HomeHubTests`/`MovementSnapshotViewTests` pass together.
- **Committed in:** `3ee912b` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 test-only bug caught before commit).
**Impact on plan:** Both fixes were required compile/test-gate necessities or self-inflicted test bugs caught by the plan's own verification loop before any commit landed. No scope creep.

## Issues Encountered
None blocking beyond the two deviations above, both caught and fixed during their own task's verification run before any commit.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MOMENTUM-07 is fully delivered: the opt-in defaults to off, uses the sanctioned chip control, the calendar screen carries no Momentum-adjacent state (structurally, via the directory-scoped boundary), and the hub entry is opt-in-gated with zero residue when off.
- `OnboardingStep.movementSnapshot` is registered in the same plan that introduced it; `StepRegistry.unregisteredSteps` stays empty (`PhaseCoverageTests` verified green).
- `Scripts/build-app.sh build`, `RithamCore/Scripts/test-core.sh`, and every named verification suite in this plan (`MovementSnapshotViewTests`, `MovementSnapshotRegistrationTests`, `MovementSnapshotTests`, `MomentumSummaryTests`, `HomeHubTests`, `PhaseCoverageTests`) all pass.
- Flag carried forward unchanged from 03-05/03-08 (not touched by this plan, out of file scope): the stale-comeback-window edge case in `MomentumReconciliation.reconcile`, and the pre-existing `StubURLProtocol` shared-state race between `RecoveryAdjustmentTests` and `RecommendationsTests.swift`'s suites.
- This was Phase 3's last file-conflicting pair (03-08/03-09 sharing `OnboardingStep.swift`/`HomeHubView.swift`); Phase 3's remaining plan(s), if any, can extend either file without needing to re-discover this plan's additions.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 4 created files verified present on disk; all 3 task commits (39f5414, 4d6abbe, 3ee912b)
verified present in `git log --oneline --all`.
