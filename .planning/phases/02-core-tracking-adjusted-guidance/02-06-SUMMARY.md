---
phase: 02-core-tracking-adjusted-guidance
plan: 06
subsystem: ui
tags: [swiftui, navigation, onboarding-router, step-registry, xcodegen]

requires:
  - phase: 01-onboarding-safety-intake
    provides: OnboardingStep/OnboardingRouter/StepRegistry/OnboardingFlow (CROSSGEN-05's single
      navigation-container contract), SettingsView with an already-built DietPlanView sheet
      (DIET-01), HealthProfileView
provides:
  - Eight new OnboardingStep cases (cardio/strength/guidance/recommendations/pre-assessment)
    as ordinary members of the one step enum, treated as terminal by OnboardingRouter
  - OnboardingFlow.open(_:), a branch-free user-initiated push, as the hub's navigation
    primitive alongside advance/goBack
  - Five per-area registrar files (Cardio, Strength x2, Guidance, Recommendations) each
    registering placeholder presenters, aggregated by Phase2StepRegistration and called once
    from StepBootstrap
  - HomeHubView: the interim navigation hub replacing the .home dead-end, with working routes
    to cardio, strength, guidance, recommendations, both history surfaces, and Settings
  - SettingsView constructed in app code for the first time -> DietPlanView (DIET-01) is
    reachable end to end without any change to DietPlanView itself
affects: [02-10-cardio-tracking, 02-11-strength-logging, 02-12-guidance, 02-13-recommendations,
  02-15-strength-history, 02-16-stepregistry-race-fix]

tech-stack:
  added: []
  patterns:
    - "OnboardingFlow.open(_:) as the third and only other path-mutating method beyond
      advance/goBack, for user-initiated pushes to steps the router deliberately never
      routes into"
    - "One registrar file per Phase 2 feature area, each with a header comment instructing the
      owning plan to rewrite the file in place rather than append a second registrar, so
      StepBootstrap needed exactly one new line total for the whole phase"

key-files:
  created:
    - RithamApp/Ritham/Home/Phase2StepRegistration.swift
    - RithamApp/Ritham/Home/HomeHubView.swift
    - RithamApp/Ritham/Cardio/CardioRegistration.swift
    - RithamApp/Ritham/Strength/StrengthLoggingRegistration.swift
    - RithamApp/Ritham/Strength/StrengthHistoryRegistration.swift
    - RithamApp/Ritham/Guidance/GuidanceRegistration.swift
    - RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift
    - RithamApp/RithamTests/HomeHubTests.swift
  modified:
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
    - RithamApp/Ritham/App/StepRegistry.swift
    - RithamApp/Ritham/App/StepBootstrap.swift
    - RithamApp/Ritham/Onboarding/Steps/HomeStepView.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "HomeHubView uses DecorativeSurface.boundedHeaderOnly, not .flat -- it collects no health
    data (the nine enumerated flat-locked screens don't include it), and .boundedHeaderOnly's
    own doc comment describes exactly this case: a screen that introduces something without
    collecting/confirming/blocking health or age data"
  - "Regenerated Ritham.xcodeproj via xcodegen and committed project.pbxproj with each task
    that added files -- project.yml scans the Ritham/ directory at generate time, so new
    subdirectories and files are invisible to xcodebuild until the project is regenerated
    (Rule 3 deviation, not in this plan's declared files_modified)"

requirements-completed: [DIET-01]

coverage:
  - id: D1
    description: "Eight Phase 2 steps declared as ordinary OnboardingStep cases, terminal in
      OnboardingRouter, with no change to existing routing behavior"
    requirement: "DIET-01"
    verification:
      - kind: unit
        ref: "RithamCoreTests/OnboardingFlowStateTests.swift#phase2StepsRoundTripThroughRawValue, #phase2StepsAreTerminal, #recommendationsIsTerminalForFullyAnsweredUser, #welcomeThroughHomeSequenceUnchangedByPhase2Steps"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every Phase 2 step has a registered placeholder presenter from this wave
      onward; StepBootstrap gained exactly one new call site"
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:RithamTests/PhaseCoverageTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "HomeHubView replaces the .home stub with working navigation to five feature
      areas plus both history surfaces and Settings, via OnboardingFlow.open(_:) only"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/HomeHubTests.swift (8 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "SettingsView is constructed in app code for the first time, making
      DietPlanView (DIET-01) reachable end to end in the running app"
    requirement: "DIET-01"
    verification:
      - kind: manual_procedural
        ref: "Launch the app, complete onboarding, tap Settings on the hub, tap Diet plan"
        status: unknown
    human_judgment: true
    rationale: "This plan's own verification section calls this a spot-check via launching the
      app; no XCUITest harness exists in this repo to automate a full onboarding walk plus
      sheet presentation. Source-level wiring (HomeHubView -> SettingsView -> DietPlanView,
      unchanged) was reviewed directly and the pieces test green individually, but the
      end-to-end interactive path itself was not run in this session."

duration: 55min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 06: Interim Navigation Hub and Phase 2 Step Vocabulary Summary

**Eight new terminal `OnboardingStep` cases, five per-area placeholder registrars behind one
`Phase2StepRegistration` aggregate, and a working `HomeHubView` that replaces the `.home`
dead-end and makes `SettingsView` (and therefore DIET-01's `DietPlanView`) reachable in the
running app for the first time.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-09-05T09:51:04Z (per STATE.md session start)
- **Completed:** 2026-09-05
- **Tasks:** 3 completed
- **Files modified:** 14 (8 created, 6 modified, including the regenerated `project.pbxproj`)

## Accomplishments
- `OnboardingStep` gained eight ordinary cases (`cardioActivityPicker`, `cardioSession`,
  `cardioHistory`, `strengthSession`, `strengthHistory`, `guidance`, `recommendations`,
  `preAssessment`); `OnboardingRouter` treats all eight as terminal, with zero change to any
  existing routing sequence.
- `OnboardingFlow.open(_:)` added as a branch-free, user-initiated push -- the hub's navigation
  primitive, distinct from `advance`'s router-delegated flow.
- Five new registrar files (Cardio, Strength logging, Strength history, Guidance,
  Recommendations), each registering placeholder presenters and each headed with a comment
  naming the future plan that owns rewriting it in place.
- `Phase2StepRegistration` aggregates all five; `StepBootstrap.registerAllSteps()` gained
  exactly one new line for the whole phase.
- `HomeHubView` replaces `.home`'s dead-end acknowledgement screen with real routes to cardio,
  strength, guidance, recommendations, both history surfaces, and a Settings sheet.
- `SettingsView` is constructed in app code for the first time (from the hub's Settings sheet),
  which is what finally makes DIET-01's already-built `DietPlanView` reachable end to end.

## Task Commits

Each task was committed atomically (Task 1 used the RED/GREEN TDD cycle):

1. **Task 1: Declare Phase 2's step vocabulary and routing behaviour**
   - RED: `b412851` (test) - failing raw-value/count assertions for the eight new cases
   - GREEN: `90f1d46` (feat) - eight cases added, router extended, all tests pass
2. **Task 2: Per-area registrar files with placeholders, and the single bootstrap call site** -
   `898fd61` (feat)
3. **Task 3: Interim navigation hub replacing the .home stub** - `b9c952b` (feat)

**Plan metadata:** (this commit, immediately following)

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift` - eight new cases
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` - eight new terminal arms
- `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift` - new coverage for the
  above
- `RithamApp/Ritham/App/StepRegistry.swift` - `OnboardingFlow.open(_:)`
- `RithamApp/Ritham/App/StepBootstrap.swift` - one new call to `Phase2StepRegistration.registerAll()`
- `RithamApp/Ritham/Home/Phase2StepRegistration.swift` - new aggregate registrar
- `RithamApp/Ritham/Home/HomeHubView.swift` - new interim hub
- `RithamApp/Ritham/Cardio/CardioRegistration.swift` - new placeholder registrar (3 steps)
- `RithamApp/Ritham/Strength/StrengthLoggingRegistration.swift` - new placeholder registrar
- `RithamApp/Ritham/Strength/StrengthHistoryRegistration.swift` - new placeholder registrar
- `RithamApp/Ritham/Guidance/GuidanceRegistration.swift` - new placeholder registrar
- `RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift` - new placeholder
  registrar (2 steps)
- `RithamApp/Ritham/Onboarding/Steps/HomeStepView.swift` - rewritten to delegate to `HomeHubView`
- `RithamApp/RithamTests/HomeHubTests.swift` - new suite, 8 tests
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` (Rule 3)

## Decisions Made
- `HomeHubView` uses `DecorativeSurface.boundedHeaderOnly`, not `.flat` -- it introduces/explains
  rather than collecting, confirming, or blocking on health data, matching that surface's own
  documented rationale, and it isn't one of the nine screens `.flat`'s header comment
  enumerates.
- Regenerated and committed `Ritham.xcodeproj/project.pbxproj` alongside Tasks 2 and 3 (not in
  the plan's declared `files_modified`) because `project.yml`'s `sources: - path: Ritham` scans
  the directory at `xcodegen generate` time; new subdirectories/files are invisible to
  `xcodebuild` until regenerated. Documented as a Rule 3 (blocking-issue) deviation per task.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated `Ritham.xcodeproj` after adding new source files/directories**
- **Found during:** Task 2 (per-area registrars) and Task 3 (HomeHubView/HomeHubTests)
- **Issue:** `project.yml` uses a directory-scan source list (`path: Ritham`); five new
  subdirectories (Cardio, Strength, Guidance, Recommendations, Home) and two new test/source
  files would not appear in the generated Xcode project without regeneration, so the plan's own
  `-only-testing:` gates would fail to find or compile them.
- **Fix:** Ran `xcodegen generate` in `RithamApp/` before each `xcodebuild` verification and
  committed the resulting `project.pbxproj` diff alongside the task's other files.
- **Files modified:** `RithamApp/Ritham.xcodeproj/project.pbxproj`
- **Verification:** `xcodebuild test -only-testing:RithamTests/PhaseCoverageTests` and
  `-only-testing:RithamTests/HomeHubTests` both report `TEST SUCCEEDED`.
- **Committed in:** `898fd61` (Task 2), `b9c952b` (Task 3)

---

**Total deviations:** 1 auto-fixed (1 blocking, Rule 3)
**Impact on plan:** Necessary for the plan's own stated verification commands to run at all;
no scope creep beyond regenerating the build file the plan's structure already implied.

## TDD Gate Compliance

Task 1 (`tdd="true"`) followed the full RED/GREEN cycle: `b412851` (test, failing) then
`90f1d46` (feat, passing) -- no REFACTOR commit was needed.

Task 3 is also `tdd="true"`, but its `<behavior>` assertions (opening each destination appends
exactly that step; opening twice appends once) are proven entirely by `OnboardingFlow.open(_:)`,
which Task 2 built and committed (`898fd61`) as part of the shared navigation primitive every
Phase 2 plan uses. Writing `HomeHubTests` against already-working code cannot produce a genuine
RED: there is no bug to reproduce and no unimplemented behavior to fail against, so a
manufactured failing test would not have been testing anything real. Per the executor's own
fail-fast guidance, this is the plan's own task split (Task 2 owns `open`, Task 3 owns the hub
and its tests) rather than an unexpected pre-existing feature -- Task 3's RED gate is considered
satisfied at Task 2, where `open` was actually built and verified. `HomeHubTests` was written,
run, and confirmed green (`b9c952b`).

## Issues Encountered
- Task 1's TDD RED phase initially asserted a welcome-through-home sequence that omitted
  `.gateSection` -- the actual pre-existing router sequence includes it (the current
  screening flow already passes through the gate section before the condition checklist for a
  default-answers user). Corrected the expected sequence before treating the run as a valid RED
  baseline; not a deviation from the plan, just a test-authoring correction caught immediately
  by running the suite.
- `OnboardingCopy.Home` (RithamCore) is now unrendered: `HomeStepView` no longer reads
  `.headline`/`.body` from it since `HomeHubView` supplies its own inline copy, matching how
  `SettingsView` and other hub-adjacent screens already inline their strings rather than
  routing through `OnboardingCopy`. Left untouched per the plan's `files_modified` list;
  `OnboardingCopyTests` only asserts non-emptiness, so this is inert rather than broken.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plans 02-10 (cardio), 02-11 (strength logging), 02-12 (guidance), 02-13 (recommendations),
  and 02-15 (strength history) each have exactly one registrar file to rewrite in place, with
  no `StepBootstrap` edits needed.
- `HomeHubView` is a stable extension point: each later plan's real screen replaces the
  corresponding placeholder in its own registrar without touching `HomeHubView` itself.
- DIET-01's end-to-end interactive spot-check (launch app -> finish onboarding -> Settings ->
  Diet plan) was not run interactively this session (see coverage D4); source-level wiring is
  unchanged and verified by passing unit/integration tests, but a manual click-through remains
  open before this can be marked fully verified in UAT.
- The documented `StepRegistry` cross-suite test-concurrency race (STATE.md Blockers/Concerns)
  is unaffected by this plan -- all gates here ran via `-only-testing:` single-suite
  invocations, as the plan's own verification section directs. Plan 02-16 still owns fixing it
  before a full-target `xcodebuild test` run can be trusted.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 9 created files verified present on disk; all 5 commit hashes (`b412851`, `90f1d46`,
`898fd61`, `b9c952b`, `44187b7`) verified present in git history.
