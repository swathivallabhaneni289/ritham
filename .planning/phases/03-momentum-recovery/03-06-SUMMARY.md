---
phase: 03-momentum-recovery
plan: 06
subsystem: ui
tags: [swiftui, swiftdata, momentum, onboarding-step, design-system]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-05's MomentumSummary/MomentumSummaryReader (reconciliation-on-read, the three user-initiated guardrail actions) and 03-02's MomentumCopy catalog"
  - phase: 03-momentum-recovery
    provides: "03-01's MomentumLedger/MomentumMilestone/RecoveryWeekPeriod/InjuryFreezePeriod value types"
provides:
  - "MomentumView (RithamApp/Ritham/Momentum/Views/MomentumView.swift) -- the Momentum detail screen: weekly progress blocks, streak, shields, milestones, the by-date Comeback Session card, this week's session list with manual-vs-sensor labeling, and the two structurally separate self-report guardrail rows"
  - "MomentumProgressBlocks/ShieldRow/MilestoneBadgeList (RithamApp/Ritham/Momentum/Components/) -- three stateless display components built strictly from 03-UI-SPEC.md Components 1-3"
  - "OnboardingStep.momentum -- the new step case, registered through Phase3StepRegistration (this phase's aggregate registrar) and wired into StepBootstrap"
affects: [03-07, 03-08, 03-09, 03-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure, nonisolated static derivations on a View-conforming type: since SwiftUI's View protocol is itself @MainActor, every member of a conforming type is MainActor-isolated by default (including static funcs), which traps at runtime when called from Swift Testing's off-main-actor test functions. Every testable pure helper on MomentumProgressBlocks and MomentumView is declared `nonisolated static func` for this reason."
    - "Reconciliation-on-appear: MomentumView's onAppear constructs a MomentumSummaryReader over its own HealthDataStore and calls summary(now:) -- the only place on this screen reconciliation runs."
    - "Per-section empty states: each of shields/milestones/sessions independently swaps its own section for its own MomentumCopy.Empty pair when empty, rather than replacing the whole screen."

key-files:
  created:
    - RithamApp/Ritham/Momentum/Components/MomentumProgressBlocks.swift
    - RithamApp/Ritham/Momentum/Components/ShieldRow.swift
    - RithamApp/Ritham/Momentum/Components/MilestoneBadgeList.swift
    - RithamApp/Ritham/Momentum/Views/MomentumView.swift
    - RithamApp/Ritham/Momentum/MomentumRegistration.swift
    - RithamApp/Ritham/Momentum/Phase3StepRegistration.swift
    - RithamApp/RithamTests/MomentumViewTests.swift
  modified:
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift
    - RithamApp/Ritham/App/StepBootstrap.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "MomentumProgressBlocks.blockStates(filled:target:) (and every other pure test helper on a View-conforming type in this plan) is marked `nonisolated` -- SwiftUI's View protocol is itself @MainActor, so isolation is inferred onto every member of a conforming type by default, and Swift Testing's off-main-actor test functions crash at runtime (EXC_BREAKPOINT / actor-isolation assertion) calling an inferred-@MainActor static function directly. Found and fixed during Task 1's own first test run, before any commit."
  - "The Comeback Session card's single CTA routes to flow.open(.cardioActivityPicker) rather than offering two entry points -- 03-UI-SPEC.md Component 4 named both .cardioActivityPicker and .strengthSession as acceptable, leaving the exact choice to the executor; cardio's picker is the lower-friction single entry for a qualifying session of either modality, and strength stays reachable from the hub directly."
  - "Recovery Week's already-flagged row state reuses MomentumCopy.RecoveryWeek.flagButton as a plain non-interactive label rather than drafting new 'already flagged' copy -- no such string exists in the Copywriting Contract's Verbatim shipped strings table, and the plan gives no instruction to add one."
  - "noMomentumControlUsesTheDestructiveColor is implemented as a comment-filtered source-read check (reading MomentumView.swift's own source relative to #filePath and asserting no non-comment line contains RithamColor.destructive) since RithamColor.destructive is not reachable from a value-level Swift Testing assertion without view-rendering tooling this codebase does not have -- the plan's own stated fallback form."
  - "Each self-report alert's dismiss button uses a literal 'Cancel' string rather than a MomentumCopy constant, matching the existing codebase convention for this exact SwiftUI pattern (SessionEditView.swift, ExercisePickerView.swift already use the identical literal) -- a system-standard dismissal action, not phase-specific framing copy."

requirements-completed: [MOMENTUM-01, MOMENTUM-02, MOMENTUM-03, MOMENTUM-04, MOMENTUM-05, MOMENTUM-06, MOMENTUM-08]

coverage:
  - id: D1
    description: "Weekly progress renders as a block strip (never a ring/arc), placed in the scrollable content area, using only RithamColor/RithamType/RithamSpacing tokens and monospaced numerals"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (blockStatesAllFilledWhenFilledEqualsTarget, blockStatesAllUnfilledWhenFilledIsZero, blockStatesPartiallyFilledForMidRangeValue, weeklyProgressLabelMatchesMomentumCopy)"
        status: pass
      - kind: other
        ref: "source greps: zero RithamColor.volt/RithamColor.destructive/RingAndDot/Circle()/.trim(from:/Arc occurrences in RithamApp/Ritham/Momentum/"
        status: pass
    human_judgment: false
  - id: D2
    description: "This week's session list renders manual-vs-sensor labeling with identical styling on both cardio branches, and a lift row carries no verification label at all"
    requirement: "MOMENTUM-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (aCardioRowShowsItsVerificationLabelAndALiftRowShowsNone)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Shields render with no consumption animation of any kind and no interactive Button wrapper"
    requirement: "MOMENTUM-02"
    verification:
      - kind: other
        ref: "source grep: zero withAnimation/.transition(/.animation( and zero Button occurrences in ShieldRow.swift"
        status: pass
    human_judgment: false
  - id: D4
    description: "The Comeback Session card renders only when a window is open and shows a plain by-date statement with no countdown/timer/progress bar"
    requirement: "MOMENTUM-04"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (comebackCardPresentWhenWindowOpen, comebackCardAbsentWhenNoWindowOpen)"
        status: pass
      - kind: other
        ref: "source grep: zero Timer/countdown/ProgressView(value: occurrences in MomentumView.swift"
        status: pass
    human_judgment: false
  - id: D5
    description: "Milestones render as a plain list matching MomentumMilestone.tiers with competence-framed copy, no celebration animation"
    requirement: "MOMENTUM-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (milestoneBadgeListTiersEqualMomentumMilestoneTiers, everyMilestoneTierHasCopy)"
        status: pass
    human_judgment: false
  - id: D6
    description: "No sharing/export affordance of any kind exists on any Momentum surface built in this plan"
    requirement: "MOMENTUM-06"
    verification:
      - kind: other
        ref: "source grep: zero UIActivityViewController/ShareLink occurrences in RithamApp/Ritham/Momentum/"
        status: pass
    human_judgment: false
  - id: D7
    description: "The Recovery Week flag and the pain/injury freeze render as two structurally separate rows with two icons and two confirmations, sharing no presentation state, never using the destructive color"
    requirement: "MOMENTUM-03, MOMENTUM-08"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (recoveryWeekAlertStringsMatchMomentumCopyConstants, injuryAlertStringsMatchMomentumCopyAndLabelSwitchesWhenFrozen, theTwoSelfReportControlsShareNoState, noMomentumControlUsesTheDestructiveColor)"
        status: pass
    human_judgment: false
  - id: D8
    description: "The new .momentum step case resolves to MomentumView after StepBootstrap.registerAllSteps(), and the shipped unregistered-steps/idempotence/reachability gates all stay green"
    requirement: null
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/MomentumViewTests.swift (StepRegistryTouchingSuites/MomentumRegistrationTests: momentumStepResolvesToMomentumView, unregisteredStepsIsEmptyWithMomentumCaseIncluded, momentumStepResolvesWithoutTrapping)"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/PhaseCoverageTests.swift, Phase2CoverageTests.swift (unchanged, still passing)"
        status: pass
      - kind: unit
        ref: "RithamCore/Scripts/test-core.sh (394 tests, 30 suites)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 06: Momentum Detail Screen, Progress/Shield/Milestone Components Summary

**MomentumView (a new registered onboarding step) plus three stateless display components (block-grid weekly progress, shield row, milestone badge list) built to 03-UI-SPEC.md's exact component specs -- no ring, no lime, no destructive red, no loss animation, and two structurally separate self-report controls.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-06T15:44:00Z
- **Completed:** 2026-09-06T16:29:00Z
- **Tasks:** 3
- **Files modified:** 12 (7 new, 5 modified)

## Accomplishments
- `MomentumProgressBlocks` renders MOMENTUM-01's weekly progress as a block-grid strip (never a ring/arc), per 03-UI-SPEC.md Component 1's binding decision -- filled blocks use `RithamColor.hot`, unfilled blocks are translucent `RithamColor.paper` fills (never stroke-only), and the count label plus strip combine into one VoiceOver announcement matching `RadialSessionTimer`'s own precedent.
- `ShieldRow` and `MilestoneBadgeList` render MOMENTUM-02/MOMENTUM-05 with zero consumption/celebration animation of any kind -- a spent shield or a newly-reached milestone simply renders its new state on next appearance, and shield glyphs are deliberately non-interactive (no `Button` wrapper).
- `MomentumView` (registered as `OnboardingStep.momentum`) reads `MomentumSummaryReader` on `onAppear` (the sole reconciliation trigger on this screen) and renders progress, streak, shields, milestones, a by-date-only Comeback Session card, this week's session list with manual-vs-sensor labeling (a lift row carries no label at all), and per-section empty states -- one `MomentumSummary` read, no second data path.
- `Phase3StepRegistration`/`MomentumRegistration` establish this phase's single aggregate registrar, mirroring Phase 2's own precedent; `StepBootstrap` gained exactly one new call.
- Two structurally separate self-report rows (Recovery Week flag, injury/pain freeze) -- two different SF Symbols, two independent `@State` alert-presentation booleans, two separate `.alert(...)` confirmations, no shared state, no destructive color -- proven at the value level by `theTwoSelfReportControlsShareNoState`.
- Found and fixed a genuine runtime bug (not caught at compile time): a pure static helper on a `View`-conforming type inherits `@MainActor` isolation by default, which trapped at runtime the moment Task 1's own first test ran. Every pure test helper this plan added is `nonisolated`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Weekly progress blocks, shield row, and milestone badge list** - `60565e2` (feat)
2. **Task 2: Momentum detail screen, new step case, and phase registrar wiring** - `612a0f6` (feat)
3. **Task 3: Two structurally separate self-report controls on the Momentum screen** - `8ff82b4` (feat)

**Plan metadata:** (this commit, `docs(03-06): complete plan`)

## Files Created/Modified
- `RithamApp/Ritham/Momentum/Components/MomentumProgressBlocks.swift` - block-grid weekly progress display, `nonisolated static blockStates(filled:target:)` for testability
- `RithamApp/Ritham/Momentum/Components/ShieldRow.swift` - up to-3 shield glyphs, no consumption animation, non-interactive
- `RithamApp/Ritham/Momentum/Components/MilestoneBadgeList.swift` - one row per `MomentumMilestone.tiers`, no celebration animation
- `RithamApp/Ritham/Momentum/Views/MomentumView.swift` - the Momentum detail screen, `MomentumViewModel`, and the two self-report guardrail rows
- `RithamApp/Ritham/Momentum/MomentumRegistration.swift` - registers `MomentumView`
- `RithamApp/Ritham/Momentum/Phase3StepRegistration.swift` - this phase's aggregate registrar
- `RithamApp/RithamTests/MomentumViewTests.swift` - flat `MomentumViewTests` suite (16 tests) plus nested `StepRegistryTouchingSuites/MomentumRegistrationTests` (3 tests)
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift` - added `case momentum`
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` - added `.momentum` to the hub-reachable terminal-steps switch arm (Rule 3 blocking fix)
- `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift` - updated `OnboardingStep.allCases.count` expectation 24 -> 25 (Rule 1 fix)
- `RithamApp/Ritham/App/StepBootstrap.swift` - added `Phase3StepRegistration.registerAll()`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` for the new Components/Views directories

## Decisions Made
- `MomentumProgressBlocks.blockStates` and every pure derivation helper on `MomentumView` (`showsComebackCard`, `streakLine`, `showsVerificationLabel`, `injuryRowLabel`) are `nonisolated static func` -- required, not stylistic, since `View`'s own `@MainActor` isolation is inferred onto every member of a conforming type by default and traps at runtime when called from an off-main-actor test function.
- The Comeback Session CTA routes to `flow.open(.cardioActivityPicker)` only, per 03-UI-SPEC.md Component 4 leaving the exact single-entry-point choice to the executor.
- Recovery Week's already-flagged state reuses the same `flagButton` string as a plain label (no new copy drafted, none exists in the Copywriting Contract for this state).
- `noMomentumControlUsesTheDestructiveColor` uses a comment-filtered source-read check (the plan's own stated fallback), since `RithamColor.destructive` isn't reachable from a value-level assertion without view-rendering tooling.
- Each alert's "Cancel" dismiss button is a literal string, matching the existing codebase convention (`SessionEditView.swift`, `ExercisePickerView.swift`) rather than a new `MomentumCopy` constant for a system-standard action.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `MomentumProgressBlocks.blockStates` crashed at runtime under Swift Testing**
- **Found during:** Task 1, first test run of `MomentumViewTests`
- **Issue:** SwiftUI's `View` protocol is itself `@MainActor`; this infers `@MainActor` isolation onto every member of a conforming type by default, including a static function that touches no UI state. Swift Testing runs test functions off the main actor, so calling this static function directly from a test tripped a runtime actor-isolation assertion (`EXC_BREAKPOINT`/`SIGTRAP` via `_swift_task_checkIsolatedSwift`), crashing the test host app on every launch rather than failing to compile.
- **Fix:** Marked `blockStates(filled:target:)` `nonisolated`, matching the codebase's own existing precedent for pure helpers that must be callable from a nonisolated context (`HealthDataStore.swift`, `WorkoutFrequencyView.swift`). Applied the same `nonisolated` treatment proactively to every pure test helper added to `MomentumView` in Tasks 2 and 3.
- **Files modified:** `RithamApp/Ritham/Momentum/Components/MomentumProgressBlocks.swift`
- **Verification:** All 7 Task 1 tests pass after the fix; confirmed via a full crash-report analysis (`~/Library/Logs/DiagnosticReports/Ritham-*.ips`) before applying it, not a guess.
- **Committed in:** `60565e2` (Task 1 commit)

**2. [Rule 3 - Blocking] `OnboardingRouter.nextStep`'s exhaustive switch required a `.momentum` arm**
- **Found during:** Task 2, first build after adding `OnboardingStep.momentum`
- **Issue:** `OnboardingStep`'s `nextStep(after:answers:)` switch is exhaustive over all cases; adding the new case without a matching arm is a compile error (`switch must be exhaustive`), blocking every subsequent build and test run.
- **Fix:** Added `.momentum` to the existing hub-reachable terminal-steps case arm (alongside Phase 2's eight surfaces), returning `nil` -- reached only by explicit user choice from the hub, never by router advancement, exactly like the plan's own header-comment instruction for the new case.
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` (not in this task's stated file list, but required by the language itself once the new case exists)
- **Verification:** `RithamCore/Scripts/test-core.sh` (394 tests, 30 suites) passes.
- **Committed in:** `612a0f6` (Task 2 commit)

**3. [Rule 1 - Bug] `OnboardingFlowStateTests`'s hardcoded step-count expectation broke**
- **Found during:** Task 2, `RithamCore/Scripts/test-core.sh` run
- **Issue:** A pre-existing test (`phase2StepsRoundTripThroughRawValue`) asserted `OnboardingStep.allCases.count == 24`, a count that necessarily changes when any new case is added -- this plan's own `<verification>` section explicitly requires `RithamCore/Scripts/test-core.sh` to still pass after the step enum gains a case.
- **Fix:** Updated the expected count to 25, with a comment explaining the +1 is this plan's new `.momentum` case.
- **Files modified:** `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift`
- **Verification:** `RithamCore/Scripts/test-core.sh` passes (394/394).
- **Committed in:** `612a0f6` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 bug caught by the plan's own test suite, 1 blocking compile fix, 1 bug in a pre-existing hardcoded count).
**Impact on plan:** All three are necessary corrections directly caused by this plan's own changes (adding a new `OnboardingStep` case, and a real Swift-concurrency isolation gap this codebase already has an established fix pattern for). No scope creep -- no file outside this plan's stated set or its immediate compile-time consequence was touched.

## Issues Encountered
None beyond the deviations above, all caught and fixed before their respective task commits landed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `MomentumView` is registered and reachable; `HomeHubView` (plan 03-07) can add its own Momentum summary section reading the same `MomentumSummaryReader` without any change to this plan's files.
- `Scripts/build-app.sh build` succeeds; the full `RithamTests` target (342 tests, 44 suites) passes; `RithamCore/Scripts/test-core.sh` (394 tests, 30 suites) passes; `PhaseCoverageTests`/`Phase2CoverageTests` remain green with the new case included.
- No sharing/export affordance exists anywhere in `RithamApp/Ritham/Momentum/` (MOMENTUM-06's private-by-default scope for this phase, confirmed by source grep) -- this stays true for plan 03-10's own close-out gate to re-verify against later plans' additions.
- Physical-device/AX3-AX5 accessibility verification for this screen is deferred to the single end-of-project batched pass, per PROJECT.md's 2026-09-06 decision (same posture as every other Phase 2/3 screen) -- not a blocker for this plan or this phase's continuation.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 7 created files verified present on disk; all 3 task commits (60565e2, 612a0f6, 8ff82b4)
verified present in `git log --oneline --all`.
