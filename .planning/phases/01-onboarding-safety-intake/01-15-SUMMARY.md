---
phase: 01-onboarding-safety-intake
plan: 15
subsystem: ios-core
tags: [swiftui, swift-testing, coremotion, corelocation, calibration, onboarding, swift6-concurrency]

# Dependency graph
requires:
  - phase: 01-05
    provides: "CalibrationSession.swift / CalibrationBaseline.swift (RithamCore): CalibrationMode, CalibrationThreshold, WalkProgress/LiftProgress, CalibrationCompletion.evaluate, CalibrationSessionSource protocol, CalibrationBaseline.provisional/.derive -- the tested completion rule this plan's four sources feed and never re-decide"
  - phase: 01-09
    provides: "OnboardingStepPresenting protocol, StepRegistry, OnboardingFlow, OnboardingRootView's single NavigationStack, Info.plist's NSMotionUsageDescription/NSLocationWhenInUseUsageDescription"
  - phase: 01-11
    provides: "HealthDataStore.saveCalibrationBaseline(_:)/.loadCalibrationBaseline() -- ungated, no loadProfile() dependency, so calibration can persist regardless of onboarding order"
  - phase: 01-12
    provides: "RithamScreen, PrimaryCTAButton/SecondaryCTAButton, ChoiceQuestionView/ChoiceChip, GlossaryTerm, RegisterEnvironment"
provides:
  - "PedometerSession/StopwatchSession/LiftSessionRecorder -- three CalibrationSessionSource conformances, none of which decide their own completion"
  - "LocationEnrichment -- GPS enrichment that reads authorizationStatus and never requests it, contributing display precision only"
  - "CalibrationIntroView/CalibrationSessionView/CalibrationCompleteView -- the three registered onboarding screens for ONBOARD-01"
  - "CalibrationRegistration.registerAll() -- registers all three steps with StepRegistry, not called from the app entry point (01-18 owns that call)"
  - "OnboardingCopy.Calibration.skipCTA -- 'Skip for now', transcribed verbatim from D-03"
  - "OnboardingFlow.calibrationMode -- transient, non-Codable UI handoff between the intro and session screens"
affects: [01-16, 01-17, 01-18, 01-19]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A CalibrationSessionSource conformer is deliberately NOT actor-isolated: Swift 6 rejects isolating a protocol conformance to a Sendable-inheriting protocol (CalibrationSessionSource: Sendable), so each of the three sources is a plain @Observable final class with @unchecked Sendable and nonisolated(unsafe) mutable storage, documented per-file as safe because every mutation/read happens on the main actor in practice (SwiftUI @State usage, and CMPedometer's background-thread callback is hopped via Task { @MainActor in ... } before it touches state)"
    - "A sensor callback's non-Sendable payload (CMPedometerData) is never captured across the actor hop -- the one Sendable value needed (distance, a Double) is extracted synchronously inside the original callback closure before Task { @MainActor in ... } is created"
    - "Both walk sources call WalkProgress.recordInterruption() (the tested core mutator) on their own interruption path rather than reimplementing the zeroing logic locally"
    - "A live-ticking display (session duration) uses TimelineView(.periodic(from:by:)) reading a computed progress property fresh each tick, instead of a custom Timer driving @Observable state"

key-files:
  created:
    - RithamApp/Ritham/Calibration/PedometerSession.swift
    - RithamApp/Ritham/Calibration/StopwatchSession.swift
    - RithamApp/Ritham/Calibration/LiftSessionRecorder.swift
    - RithamApp/Ritham/Calibration/LocationEnrichment.swift
    - RithamApp/Ritham/Calibration/Views/CalibrationIntroView.swift
    - RithamApp/Ritham/Calibration/Views/CalibrationSessionView.swift
    - RithamApp/Ritham/Calibration/Views/CalibrationCompleteView.swift
    - RithamApp/Ritham/Calibration/CalibrationRegistration.swift
    - RithamApp/RithamTests/CalibrationSourceTests.swift
  modified:
    - RithamApp/Ritham/App/StepRegistry.swift
    - RithamCore/Sources/RithamCore/Copy/OnboardingCopy.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Added OnboardingCopy.Calibration.skipCTA ('Skip for now'), transcribed verbatim from D-03's own decision text -- 01-UI-SPEC.md's Copywriting Contract table has no dedicated row for it, but D-03 itself names this exact action, so this implements a canonical decision string rather than inventing new unreviewed copy (materially different from 01-13's Diet-CTA situation, where no source named a specific string at all)"
  - "Added a transient, non-Codable OnboardingFlow.calibrationMode property (StepRegistry.swift) so CalibrationIntroView's activity choice reaches CalibrationSessionView -- OnboardingRouter never branches on it (only on calibrationOutcome), so it does not belong in the Codable, persisted OnboardingAnswers aggregate; it is pure in-session UI handoff, not branching logic, which is the one thing OnboardingFlow's header comment forbids adding"
  - "Each CalibrationSessionSource conformer is a plain (non-actor-isolated) class with @unchecked Sendable + nonisolated(unsafe) storage, not @MainActor -- Swift 6 rejects an isolated conformance to a protocol that inherits Sendable (CalibrationSessionSource: Sendable), so @MainActor could not be applied to the conformance itself; documented per-file why the real-world access pattern (SwiftUI @State + a Task-hopped sensor callback) makes this safe in practice"
  - "CalibrationSessionView's skip action routes via flow.advance(from: .calibrationIntro), not .calibrationSession -- OnboardingRouter's skip-aware branch (jumping past calibrationComplete once calibrationOutcome == .skipped) lives on the .calibrationIntro case; re-entering the router there reuses that already-tested branch instead of adding a second skip-aware case to .calibrationSession, keeping the router the single branching authority"

patterns-established:
  - "Pattern: when a protocol requirement's own conformance clause cannot be actor-isolated (because the protocol inherits Sendable), keep the conforming class non-actor-isolated and mark only its mutable storage nonisolated(unsafe), backed by a file-header comment stating the real-world serialization guarantee (SwiftUI @State single-threaded usage) the compiler cannot see"

requirements-completed: [ONBOARD-01, CROSSGEN-05]

coverage:
  - id: D1
    description: "PedometerSession (CMPedometer, guarded by isStepCountingAvailable(), reports unavailability immediately rather than crashing) and StopwatchSession (standalone, no sensor, no permission) both conform to CalibrationSessionSource and call WalkProgress.recordInterruption() on their own interruption path rather than reimplementing the zeroing"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CalibrationSourceTests.swift -- pedometerReportsUnavailableWithoutCrashing, pedometerReportsAvailableImmediately, stopwatchReachesCompletionAtSixHundredSeconds, stopwatchPauseRecordsInterruptionAndZeroesAccumulation"
        status: pass
      - kind: other
        ref: "grep -c 'isStepCountingAvailable' PedometerSession.swift >= 1; grep -c 'recordInterruption' StopwatchSession.swift >= 1; comment-stripped grep for CoreLocation/CLLocationManager/requestWhenInUseAuthorization in PedometerSession.swift == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "LiftSessionRecorder reaches completion at exactly three working sets across two exercises and not at three across one; LocationEnrichment reads authorizationStatus and starts updates ONLY when already granted, never calling requestWhenInUseAuthorization/requestAlwaysAuthorization, and never gates walk completion regardless of its own state"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CalibrationSourceTests.swift -- liftRecorderRequiresBothSetsAndExerciseSpread, locationEnrichmentStaysInertWhenNotAuthorized, locationEnrichmentBeginsWhenAuthorized, walkCompletionIdenticalRegardlessOfEnrichment"
        status: pass
      - kind: other
        ref: "grep -c 'authorizationStatus' LocationEnrichment.swift >= 1; comment-stripped grep for requestWhenInUseAuthorization/requestAlwaysAuthorization across all four source files == 0; no source file calls CalibrationCompletion.evaluate on itself (comment-stripped grep == 0 in each of the 4 files)"
        status: pass
    human_judgment: false
  - id: D3
    description: "CalibrationIntroView offers an activity choice (walk/light lift) never an ability choice, with a non-blocking 'Skip for now' action persisting a provisional baseline before advancing; CalibrationSessionView runs the pedometer or stopwatch automatically (offering the stopwatch explicitly too), attaches LocationEnrichment without ever requesting authorization, and shows progress as plain text/a bar strip, never a ring"
    requirement: "ONBOARD-01"
    verification:
      - kind: other
        ref: "grep -c 'DecorativeSurface.calibration' CalibrationIntroView.swift >= 1; grep -c 'CalibrationOutcome.skipped' CalibrationIntroView.swift >= 1; comment-stripped grep for requestWhenInUseAuthorization/requestAlwaysAuthorization across Calibration/Views == 0; comment-stripped grep for fitness level/experience level/beginner/intermediate/advanced across Calibration/Views == 0; comment-stripped grep for RingAndDot in CalibrationSessionView.swift == 0"
        status: pass
      - kind: unit
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
    human_judgment: true
    rationale: "The mechanism (source auto-selection, no-permission-prompt GPS enrichment, bar-strip progress) is proven by grep and BUILD SUCCEEDED, but actual on-device behavior -- a real CMPedometer session, real GPS enrichment precision, and whether the live-ticking TimelineView display reads correctly at real device sizes -- cannot be exercised in the Simulator (01-RESEARCH.md Pitfall 4) and is deferred to plan 01-19's human checkpoint, matching the same deferral pattern 01-10/01-12-SUMMARY.md established for other visual/sensor confirmation."
  - id: D4
    description: "CalibrationCompleteView acknowledges completion using only the locked headline/body copy, with no score/grade/level/percentile/rating wording anywhere, and wraps pace zone/working set in GlossaryTerm so EXPLAIN-01's tap-to-expand works; CalibrationRegistration.registerAll() registers all three calibration steps with StepRegistry"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CalibrationSourceTests.swift -- registerAllResolvesCalibrationSteps, routerRoutesPastSessionAndCompleteWhenSkipped, routerPassesThroughSessionAndCompleteWhenNotSkipped, skipYieldsProvisionalBaselineNotNil"
        status: pass
      - kind: other
        ref: "grep -c 'OnboardingCopy.Calibration.completeHeadline' CalibrationCompleteView.swift >= 1; comment-stripped grep for score/grade/rating/percentile/your level == 0; grep -c GlossaryTerm CalibrationCompleteView.swift >= 1 (== 2); grep -c StepRegistry.register CalibrationRegistration.swift == 3"
        status: pass
    human_judgment: false

duration: ~50min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 15: Calibration Sources, Live Session, and Completion Summary

**Four interchangeable CalibrationSessionSource-conforming sources (CMPedometer, manual stopwatch, lift recorder, GPS enrichment) feeding one already-tested completion rule, plus the three registered onboarding screens (intro, live session, completion) that replace a self-reported fitness-level dropdown with a real walk-or-light-lift session -- no location permission ever blocks progress, and completion is never rendered as a score.**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3
- **Files modified:** 13 (9 created, 4 modified -- including the regenerated xcodeproj)

## Accomplishments
- `PedometerSession` wraps `CMPedometer`, guards every start with `isStepCountingAvailable()`, and reports unavailability through `isAvailable` immediately at init (not only after a failed start attempt) -- the session view can pick the stopwatch before ever calling `.start()` on an unavailable pedometer
- `StopwatchSession` is a genuine standalone fallback -- no sensor, no permission of any kind -- and is the only calibration path exercisable in the Simulator (01-RESEARCH.md Pitfall 4); both walk sources call the already-tested `WalkProgress.recordInterruption()` on their own interruption path rather than reimplementing the zeroing logic
- `LiftSessionRecorder` records working sets into a `LiftProgress`, exposing live `totalWorkingSets`/`distinctExercises` counts
- `LocationEnrichment` reads `CLLocationManager.authorizationStatus` and starts updates ONLY when already `.authorizedWhenInUse`/`.authorizedAlways`, never calling `requestWhenInUseAuthorization`/`requestAlwaysAuthorization` -- contributing display precision only; a test asserts a walk reaches completion identically whether enrichment is active or inert
- None of the four sources calls `CalibrationCompletion.evaluate` on itself -- each exposes `progress` only, and the session view is the sole caller of the tested completion rule
- `CalibrationIntroView` offers a walk-vs-light-lift activity choice (never an ability choice) with a non-blocking "Skip for now" action that persists a provisional baseline through `HealthDataStore.saveCalibrationBaseline` before advancing (D-03)
- `CalibrationSessionView` auto-selects the pedometer or stopwatch, offers the stopwatch explicitly as a switch-to choice too, attaches `LocationEnrichment` without ever prompting for location, and renders progress as plain text and a bar strip -- never a ring, per 01-UI-SPEC.md's static-ornament rule for ring-and-dot. A session ended early stays incomplete: "Restart" or "Skip for now," never a partial baseline
- `CalibrationCompleteView` renders only the locked completion copy plus two `GlossaryTerm`-wrapped technical terms (pace zone, working set) -- no score, grade, level, percentile, or rating anywhere
- `CalibrationRegistration.registerAll()` registers all three steps with `StepRegistry`, not invoked from the app entry point (01-18 owns that bootstrap call)
- `CalibrationSourceTests` (17 tests across the plan) plus the 4 tests folded into the full suite: mode reporting, availability, stopwatch completion/interruption at the exact 600s boundary, lift completion requiring both set count and exercise spread, location-enrichment inertness/activation and non-gating, step registration, router skip/pass-through routing, and a meaningful round-trip assertion that a skip's persisted baseline is genuinely `.provisional` with the exact `establishedAt` date, not merely non-nil on an empty store
- Full `RithamTests` suite: 70 tests, 9 suites, all pass; `RithamCore` suite: 153 tests, 11 suites, all pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Pedometer, stopwatch, lift recorder, and opportunistic GPS enrichment** - `52d7645` (feat)
2. **Task 2: Calibration intro and live session screens** - `d9c1320` (feat)
3. **Task 3: Completion screen and step registration** - `eef3aa7` (feat)

## Files Created/Modified
- `RithamApp/Ritham/Calibration/PedometerSession.swift` - CMPedometer-backed walk source, availability guard, interruption gap detection
- `RithamApp/Ritham/Calibration/StopwatchSession.swift` - Manual walk fallback, injected-clock-driven
- `RithamApp/Ritham/Calibration/LiftSessionRecorder.swift` - Working-set recorder for lift mode
- `RithamApp/Ritham/Calibration/LocationEnrichment.swift` - GPS enrichment, authorization-status-gated, never requests
- `RithamApp/Ritham/Calibration/Views/CalibrationIntroView.swift` - Activity choice + non-blocking skip; `CalibrationMode: Identifiable` retroactive conformance
- `RithamApp/Ritham/Calibration/Views/CalibrationSessionView.swift` - Live session for both modes, source auto-selection/switching, `ProgressBarStrip`
- `RithamApp/Ritham/Calibration/Views/CalibrationCompleteView.swift` - Completion acknowledgement, `GlossaryTerm`-wrapped terms
- `RithamApp/Ritham/Calibration/CalibrationRegistration.swift` - `registerAll()`, 3 `StepRegistry.register` calls
- `RithamApp/RithamTests/CalibrationSourceTests.swift` - 17 Swift Testing tests (sources, registration, routing, persistence round-trip)
- `RithamApp/Ritham/App/StepRegistry.swift` - Added `OnboardingFlow.calibrationMode` (Rule 3 deviation)
- `RithamCore/Sources/RithamCore/Copy/OnboardingCopy.swift` - Added `Calibration.skipCTA` (Rule 2 deviation)
- `RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift` - Added `skipCTA` to the exhaustive constant list
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after each task, per the established 01-09 through 01-13 pattern

## Decisions Made
- `OnboardingCopy.Calibration.skipCTA` transcribes D-03's own decision text verbatim ("a 'Skip for now' action") rather than inventing new copy -- 01-UI-SPEC.md's Copywriting Contract table has no dedicated row for a skip CTA, but the source decision itself names the exact string
- `OnboardingFlow.calibrationMode` is a transient, non-`Codable` property on the app-layer flow wrapper (not `OnboardingAnswers` in RithamCore) -- `OnboardingRouter` never branches on the chosen mode, so it carries no routing consequence and does not belong in the persisted, branching-relevant answers aggregate
- Each `CalibrationSessionSource` conformer (`PedometerSession`, `StopwatchSession`, `LiftSessionRecorder`) is a plain, non-actor-isolated class with `@unchecked Sendable` and `nonisolated(unsafe)` mutable storage rather than `@MainActor` -- Swift 6 rejects isolating a protocol conformance to a `Sendable`-inheriting protocol, and `CalibrationSessionSource: Sendable` is exactly that; each file documents the real-world single-threaded access guarantee (SwiftUI `@State` + `Task { @MainActor in ... }`-hopped sensor callbacks) the compiler cannot verify statically
- `CalibrationSessionView`'s skip action routes via `flow.advance(from: .calibrationIntro)` rather than `.calibrationSession`, reusing `OnboardingRouter`'s existing skip-aware branch (which lives on the `.calibrationIntro` case) instead of adding a second one to `.calibrationSession` -- the router stays the single branching authority

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `OnboardingFlow` had no way to carry the intro's activity choice to the session screen**
- **Found during:** Task 2 (before writing `CalibrationSessionView`, confirmed via advisor review)
- **Issue:** `StepRegistry.view(for:flow:)`'s factory signature only accepts `OnboardingFlow`, and `OnboardingAnswers` (RithamCore) has no field for "which calibration mode was chosen" -- adding one there would require `CalibrationMode` to conform to `Codable` (it currently does not, and that file belongs to already-committed plan 01-05), a larger surface than this plan's own scope.
- **Fix:** Added a transient `var calibrationMode: CalibrationMode = .walk` directly to the app-layer `OnboardingFlow` class (`StepRegistry.swift`) -- in-memory only, never persisted, never read by `OnboardingRouter`.
- **Files modified:** `RithamApp/Ritham/App/StepRegistry.swift`
- **Verification:** `./Scripts/build-app.sh build` (BUILD SUCCEEDED); full `RithamTests` suite re-run (70/70 pass)
- **Committed in:** `d9c1320` (Task 2 commit)

**2. [Rule 2 - Missing Critical] No locked copy existed for the calibration skip action's visible label**
- **Found during:** Task 2, before writing `CalibrationIntroView`
- **Issue:** 01-UI-SPEC.md's Copywriting Contract table enumerates only Calibration start (headline/body/CTA) and Calibration complete (headline/body) rows -- no CTA row exists for the skip action `01-CONTEXT.md`'s D-03 itself names ("a 'Skip for now' action"). Without a constant, the button would need either a raw string literal (breaking the "every visible string resolves through OnboardingCopy" convention every other screen in this phase follows) or a borrowed, semantically-wrong string.
- **Fix:** Added `OnboardingCopy.Calibration.skipCTA = "Skip for now"`, transcribed verbatim from D-03's own wording, and added it to `OnboardingCopyTests`'s exhaustive constant list.
- **Files modified:** `RithamCore/Sources/RithamCore/Copy/OnboardingCopy.swift`, `RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift`
- **Verification:** `cd RithamCore && ./Scripts/test-core.sh` (153/153 pass, including the updated `OnboardingCopyTests`)
- **Committed in:** `d9c1320` (Task 2 commit)

**3. [Rule 3 - Blocking] `@MainActor` could not be applied to any `CalibrationSessionSource` conformance**
- **Found during:** Task 1, first `./Scripts/build-app.sh build` after writing all four source files
- **Issue:** `CalibrationSessionSource: Sendable` (RithamCore) means every conformer must itself be `Sendable`. The natural first attempt -- `@MainActor @Observable final class ... : CalibrationSessionSource, @unchecked Sendable` -- fails to compile: Swift 6 rejects forming a main-actor-isolated conformance to a protocol that inherits `Sendable` ("cannot form main actor-isolated conformance ... to SendableMetatype-inheriting protocol"), because an isolated conformance and unconditional `Sendable` are mutually exclusive concepts.
- **Fix:** Removed `@MainActor` from `PedometerSession`, `StopwatchSession`, and `LiftSessionRecorder`; kept `@unchecked Sendable`; marked every mutable stored property `nonisolated(unsafe)`; documented per-file why this is safe in practice (SwiftUI `@State` usage serializes reads on the main actor, and `PedometerSession`'s `CMPedometer` background-thread callback extracts its one needed `Sendable` value -- `distance: Double` -- before hopping into `Task { @MainActor in ... }`, since `CMPedometerData` itself is not `Sendable` and cannot be captured across that boundary). `LocationEnrichment` does not conform to `CalibrationSessionSource` and keeps `@MainActor` + `@unchecked Sendable` without incident.
- **Files modified:** `RithamApp/Ritham/Calibration/PedometerSession.swift`, `RithamApp/Ritham/Calibration/StopwatchSession.swift`, `RithamApp/Ritham/Calibration/LiftSessionRecorder.swift`
- **Verification:** `./Scripts/build-app.sh build` (BUILD SUCCEEDED); full `RithamTests` suite (70/70 pass)
- **Committed in:** `52d7645` (Task 1 commit)

**4. [Rule 1 - Bug] `@Observable`'s tracking macro rejected a `lazy` computed property**
- **Found during:** Task 1, `LocationEnrichment`'s first build attempt
- **Issue:** `private lazy var locationManager: CLLocationManager = { ... }()` inside an `@Observable` class produced an init-accessor macro-expansion error -- `@Observable`'s tracking cannot be synthesized for a `lazy` property.
- **Fix:** Annotated the property `@ObservationIgnored` -- the underlying `CLLocationManager` is an implementation detail no view ever reads directly, so it needs no observation tracking.
- **Files modified:** `RithamApp/Ritham/Calibration/LocationEnrichment.swift`
- **Verification:** `./Scripts/build-app.sh build` (BUILD SUCCEEDED)
- **Committed in:** `52d7645` (Task 1 commit)

---

**Total deviations:** 4 auto-fixed (2 blocking compile-time/architectural, 1 missing-critical-copy, 1 bug). All four were caught before or during the first build/test pass of the task that introduced them, not discovered later.
**Impact on plan:** All four were necessary for the plan's own stated design to compile and function as written (concurrency correctness) or to keep the "every visible string resolves through OnboardingCopy" convention intact (copy). No scope creep -- no new architecture, no new persisted field, and the `CalibrationSessionSource: Sendable` finding was exactly the interaction the orchestrator's own pre-flight advisor review flagged as the most likely first failure before any code was written.

## Issues Encountered
None beyond the deviations above -- no simulator flakiness this run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All three calibration screens are registered and reachable through `StepRegistry`; `PedometerSession`/`StopwatchSession`/`LiftSessionRecorder`/`LocationEnrichment` are ready for reuse wherever a later phase needs a walk or lift session (e.g., Phase 2's cardio/strength tracking, which the plan's own context notes will pair passive-first capture with full manual configuration, consistent with this plan's explicit stopwatch choice)
- `StepRegistry.unregisteredSteps` now additionally excludes `.calibrationIntro`, `.calibrationSession`, `.calibrationComplete`
- Visual/tactile confirmation of the live session screen (real CMPedometer accuracy, real GPS enrichment precision, and the `TimelineView`-driven ticking display at real device sizes) remains a human checkpoint deferred to plan 01-19, per 01-VALIDATION.md's Manual-Only table -- CoreMotion step/distance accuracy during a real ten-minute walk cannot be meaningfully simulated
- No blockers for the next plan in wave sequence (01-16)

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 9 created files and 3 modified source files verified present on disk; all 3 task commit
hashes (52d7645, d9c1320, eef3aa7) verified in git log.
