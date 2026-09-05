---
phase: 02-core-tracking-adjusted-guidance
plan: 13
subsystem: api
tags: [swift, urlsession, swiftui, observable, workout-plan, onboard-01]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "RithamService's POST /v1/workout-plan contract (02-05) -- exact field spellings this client's request/response types match character for character"
  - phase: 02-core-tracking-adjusted-guidance
    provides: "HealthDataStore's workout-preference accessors (02-08) -- loadWeeklyFrequency/experienceLevel/loadHasCompletedPreAssessment/markPreAssessmentCompleted, saveCalibrationBaseline/loadCalibrationBaseline"
  - phase: 02-core-tracking-adjusted-guidance
    provides: "RecommendationsRegistration's placeholder scaffolding and the .recommendations/.preAssessment step vocabulary (02-06)"
provides:
  - "WorkoutPlanClient: a URLSession-only network client enforcing D-07's three-field data-minimization boundary, with a local short-circuit for the most restrictive workout gate"
  - "PreAssessmentView: the real ONBOARD-01 walk-or-light-lift pre-assessment, baseline-only per D-04"
  - "RecommendationsView: D-03's dedicated Recommendations surface, gating the first plan request on the pre-assessment flag"
affects: ["02-16 (phase close-out: cross-process verification against a running Go service, AX3/AX5 accessibility pass now reachable via this plan's RadialSessionTimer host screen, and the ONBOARD-01 requirement-completion decision)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Model/View split for testability without rendering: an @Observable *Model class carries all logic (PreAssessmentModel, RecommendationsModel), matching CardioSessionModel/CardioActivityPickerModel's existing precedent"
    - "URLProtocol-stubbed network testing (StubURLProtocol) -- first use of this pattern in the app target; reads httpBodyStream as a fallback since URLSession frequently rewrites a small httpBody by the time URLProtocol observes the request"
    - ".serialized on any Suite touching shared static test-double state (StubURLProtocol), matching the existing StepRegistry-serialization precedent"

key-files:
  created:
    - RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift
    - RithamApp/Ritham/Recommendations/Views/PreAssessmentView.swift
    - RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift
    - RithamApp/RithamTests/RecommendationsTests.swift
  modified:
    - RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift

key-decisions:
  - "The walk half of the pre-assessment uses StopwatchCardioSession only, not GPSTrackingSession, even though both were cited as this phase's own capture adapters -- the walk completion bar (CalibrationThreshold.qualifyingWalkDuration) is duration-only, and requesting location authorization would reintroduce the blocking-prompt risk calibration's own D-02 precedent avoids"
  - "The lift half tracks LiftProgress directly with no capture-adapter type at all, since LiftProgress is already the exact shape CalibrationBaseline.derive accepts and no CalibrationSessionSource-style protocol conformance is needed to produce it"
  - "WorkoutPlanClient's local referral plan reuses WorkoutGuidanceCatalog.referralMessage rather than a second transcription, so the on-device short-circuit and the server's own required-blocking guidance note can never read as two different messages"
  - "RecommendationsView resolves the workout gate via GateEscalation.escalate(tags:answers:) with an empty ScreeningAnswers -- the same store-driven re-derivation pattern HealthProfileView (01-17) already established, carrying the same known G2/G3 answer-driven-escalation gap documented there"

patterns-established:
  - "Model/View split now proven across three phases of screens (Cardio, Recommendations) as the standard for behavior-testable SwiftUI screens without XCUITest"

requirements-completed: []

coverage:
  - id: D1
    description: "WorkoutPlanClient's request carries exactly three fields (frequencyPerWeek/experienceLevel/guidancePermission), enforced by an encode-and-inspect test, with zero occurrences of ConditionTag/ScreeningAnswers/SCOFF/matchedTags/CalibrationBaseline/deviceID/userID in the source file"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.encodingProducesExactlyThreeKeys"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.requestCarriesExactlyThreeProperties"
        status: pass
    human_judgment: false
  - id: D2
    description: "A restrictive workout gate returns a generic on-device referral plan and makes zero network requests; a successful response decodes into a plan; non-success status and transport/decode failures each surface a distinct typed error"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.restrictiveGateShortCircuitsLocally"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.successfulResponseDecodesIntoPlan"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.nonSuccessStatusSurfacesTypedError"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.malformedResponseSurfacesDecodeError"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#WorkoutPlanClientTests.unreachableServiceSurfacesTransportError"
        status: pass
    human_judgment: false
  - id: D3
    description: "A qualifying walk or lift derives a measured CalibrationBaseline; a short walk or under-threshold lift does not; completing marks the pre-assessment complete, stores the baseline, and adds zero cardio/lift sessions to training history; skipping stores no baseline and leaves the loaded baseline provisional"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.walkReachingQualifyingDurationDerivesBaseline"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.walkFallingShortDoesNotDeriveBaseline"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.liftReachingBothThresholdsDerivesBaseline"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.completingMarksCompleteAndStoresBaseline"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.completingAddsNoTrainingHistory"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#PreAssessmentTests.skippingLeavesProvisionalBaselineInPlace"
        status: pass
    human_judgment: false
  - id: D4
    description: "Requesting a plan before the pre-assessment is complete opens PreAssessmentView with zero network calls; after completion it fetches with the stored frequency and derived experience bucket; a transport error renders an error state, not a zero-session plan; a blocking gate renders the referral plan with zero network calls; both steps are registered as real screens (no placeholders, no self-reported frequency/experience control)"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#RecommendationsScreenTests.requestingPlanWithoutPreAssessmentOpensPreAssessment"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#RecommendationsScreenTests.requestingPlanAfterPreAssessmentFetchesPlan"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#RecommendationsScreenTests.transportErrorRendersErrorState"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#RecommendationsScreenTests.blockingGateRendersReferralPlanWithNoNetworkCall"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/RecommendationsTests.swift#RecommendationsScreenTests.sendsStoredFrequencyAndDerivedExperienceBucket"
        status: pass
      - kind: unit
        ref: "xcodebuild build -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17'"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 13: WorkoutPlanClient, Pre-Assessment, and Recommendations Surface Summary

**A URLSession-only WorkoutPlanClient enforcing D-07's three-field data-minimization boundary (with a zero-network local short-circuit for the most restrictive gate), plus the real ONBOARD-01 walk-or-light-lift pre-assessment and the dedicated Recommendations surface that gates the first plan request on it.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-05T21:29:00+05:30 (approx.)
- **Completed:** 2026-09-05T21:42:00+05:30
- **Tasks:** 3 completed
- **Files modified:** 5 (4 created, 1 modified)

## Accomplishments

- `WorkoutPlanClient` calls `POST /v1/workout-plan` over plain `URLSession` with a three-field, coding-key-pinned request (`frequencyPerWeek`/`experienceLevel`/`guidancePermission`) and typed errors (`transport`/`httpStatus`/`decoding`) so a non-success status or an unreachable service always reads as an error, never an empty plan.
- The client's local short-circuit returns an on-device referral plan (reusing `WorkoutGuidanceCatalog.referralMessage`) and constructs zero requests when the workout gate is `requiredBlocking` -- T-02-37's zero-data-in-the-worst-case rule, enforced by a request-count assertion.
- `PreAssessmentView` runs a real walk (via `StopwatchCardioSession`) or light lift (working sets tracked directly), converts the finished measurement into `CalibrationProgress` only at completion, and derives/stores a baseline through `CalibrationBaseline.derive` -- reusing Phase 1's already-tested completion rule per ROADMAP Phase 2 criterion 8, never conforming to `CalibrationSessionSource`. It calls neither `saveCardioSession` nor `saveLiftSession`, so the assessment never enters training history (D-04). `RadialSessionTimer` now has a second reachable host screen.
- `RecommendationsView` is D-03's dedicated surface: it gates the first "get my plan" request on `loadHasCompletedPreAssessment()`, sends only the stored weekly frequency and the store-derived experience bucket, resolves the workout gate through `GateEscalation.escalate` (the same store-driven pattern `HealthProfileView` established), and renders a distinct error state with retry for every client failure.
- `RecommendationsRegistration.swift` rewritten in place: both placeholders replaced with the real screens, no second registrar added, `StepBootstrap.swift` untouched.

## Task Commits

Each task followed the plan's `tdd="true"` RED/GREEN cycle:

1. **Task 1: Workout-plan client with a local short-circuit for the blocking case**
   - `a8e686c` (test): failing tests for `WorkoutPlanClient` (RED -- stub always throws `.transport`)
   - `69837e8` (feat): full client implementation, D-07 boundary enforced (GREEN)
2. **Task 2: The triggered walk-or-light-lift pre-assessment**
   - `e26d60f` (test): failing tests for `PreAssessmentModel` (RED -- stub hardcodes `isComplete == false`)
   - `7e66566` (feat): full walk/lift measurement, baseline derivation, and store writes (GREEN)
3. **Task 3: Recommendations surface and registrar rewrite**
   - `15619ad` (test): registrar rewrite + failing tests for `RecommendationsModel` (RED -- stub always opens the pre-assessment)
   - `65970ed` (feat): full gate-driven fetch/render behavior (GREEN)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift` - `WorkoutPlanClient`, its `Codable` request/response types, `WorkoutPlanClientError`
- `RithamApp/Ritham/Recommendations/Views/PreAssessmentView.swift` - `PreAssessmentMode`, `PreAssessmentModel`, `PreAssessmentView`
- `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` - `RecommendationsState`, `RecommendationsModel`, `RecommendationsView`
- `RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift` - rewritten in place, registers the two real screens
- `RithamApp/RithamTests/RecommendationsTests.swift` - `StubURLProtocol` + `WorkoutPlanClientTests`/`PreAssessmentTests`/`RecommendationsScreenTests` (21 tests total)

## Decisions Made

- **Walk measurement uses `StopwatchCardioSession` only, not `GPSTrackingSession`.** Both are "this phase's own capture adapters," but the walk completion bar is duration-only (`CalibrationThreshold.qualifyingWalkDuration`), and requesting location authorization on a screen meant to be a fast, zero-friction pre-check would reintroduce the blocking-prompt risk calibration's own D-02 precedent (via `CalibrationSessionView`/`LocationEnrichment`) deliberately avoids. Distance stays unmeasured; `CalibrationBaseline.derive` already falls back to its conservative pace zone when distance is 0, so completion and baseline `.source == .measured` are unaffected.
- **Lift measurement has no dedicated capture-adapter type.** `LiftProgress` (Phase 1's `RithamCore` value type) is already the exact shape `CalibrationBaseline.derive`/`CalibrationCompletion.evaluate` accept, so `PreAssessmentModel` tracks it directly with no `CalibrationSessionSource` conformance and no new wrapper type.
- **The client's referral plan reuses `WorkoutGuidanceCatalog.referralMessage`** rather than transcribing a second copy of the required-blocking message, so the on-device short-circuit path and the Go service's own required-blocking response can never drift into two different messages.
- **The workout gate is resolved via `GateEscalation.escalate(tags:answers:)` with an empty `ScreeningAnswers`**, the identical pattern `HealthProfileView` (01-17) already established for reconstructing a `GateResolutionResult` from persisted tags alone. This carries the same known, already-documented gap: the G2/G3 answer-driven required-blocking rule cannot be reconstructed from stored tags alone, since no raw screening answer is persisted after onboarding.

## Deviations from Plan

None - plan executed exactly as written. No Rule 1/2/3 auto-fixes were needed; the one non-obvious fix (draining `httpBodyStream` as a fallback in the test helper, since `URLSession` frequently rewrites a small `httpBody` into a stream by the time `URLProtocol` observes the request) was confined entirely to test infrastructure and did not touch any shipped file.

## Issues Encountered

- Two `RecommendationsScreenTests` initially failed with `.error(.transport)` instead of the expected plan/error state. Root cause: `HealthDataStore.activeConditionTags(now:)` requires an existing profile (`loadProfile()` throws `.profileMissing` otherwise) and those two tests never called `updateProfile` before requesting a plan. Fixed by seeding a profile in both tests -- not a client or view bug, a test-setup gap.
- `WorkoutPlanClientTests`' `successfulResponseDecodesIntoPlan` test intermittently decoded from a `.transport` error until `.serialized` was added to the suite; `StubURLProtocol`'s shared static `requestHandler`/`requestCount` race across Swift Testing's default parallel execution, the same class of issue `STATE.md`'s Blockers/Concerns already documents for `StepRegistry`-touching suites. Serializing both new suites (`WorkoutPlanClientTests`, `RecommendationsScreenTests`) that touch this shared static state resolved it.

## User Setup Required

None - no external service configuration required. The Debug build points at `127.0.0.1:8080`, the loopback address `RithamService` binds to by default; run it locally with `cd RithamService && go run ./cmd/ritham-service` for manual end-to-end verification (deferred to plan 02-16 per 02-VALIDATION.md's Manual-Only Verifications table).

## Requirements Note

`requirements-completed: []` above is deliberately empty even though this plan's frontmatter lists `requirements: [ONBOARD-01]`. Per `02-VALIDATION.md`'s Per-Task Verification Map, ONBOARD-01 spans four plans in this phase (02-05, 02-08, 02-13, 02-16). This plan builds the user-facing trigger and pre-assessment ONBOARD-01 actually describes, but phase close-out verification (02-16) -- including the cross-process check against a running Go service -- has not run yet. `REQUIREMENTS.md`'s ONBOARD-01 checkbox stays unchecked; its traceability-table row should be updated to reflect that only 02-16 remains.

## Next Phase Readiness

- `RadialSessionTimer` now has two reachable host screens (`CalibrationSessionView`, `PreAssessmentView`), which is what lets plan 02-16 finally discharge the carried-over AX3/AX5 accessibility check.
- Cross-process verification against a live `RithamService` instance is a checkpoint explicitly deferred to plan 02-16.
- No blockers. All three `-only-testing:` suites pass individually and together (21 tests), and a full `xcodebuild build` succeeds.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 5 created/modified files verified present on disk. All 6 task commit hashes
(`a8e686c`, `69837e8`, `e26d60f`, `7e66566`, `15619ad`, `65970ed`) verified present in
`git log --oneline --all`.
