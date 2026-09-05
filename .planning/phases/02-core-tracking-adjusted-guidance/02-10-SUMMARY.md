---
phase: 02-core-tracking-adjusted-guidance
plan: 10
subsystem: cardio-ui
tags: [swiftui, swiftdata, mapkit, coremotion, corelocation, cardio, gps, route-comparison]

requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "RithamCore's Foundation-only Cardio domain (ActivityType, CardioSession, CardioProgress, GradeAdjustedPace) from plan 02-01; StopwatchCardioSession/GPSTrackingSession/MotionActivityDetector from plan 02-09; HealthDataStore cardio/lift/preference accessors from plan 02-08"
provides:
  - "CardioActivityPickerView: activity-type selection (ActivityType.known), GPS vs. manual start, and the CROSSGEN-02 auto-detect accept/dismiss confirmation"
  - "CardioSessionView: live GPS/manual tracked session with two independent confidence indicators, grade-adjusted pace shown only when the elevation signal supports it, denied-authorization fallback to the manual timer, and session save on finish"
  - "CardioHistoryView: sensor-verified-vs-manual training history with a date-range filter, empty state, and a real (if data-starved) MapKit route-map surface"
  - "RouteComparisonView: single-user, opt-in-off-by-default route comparison with no cross-user concept anywhere in the file"
  - "CardioRegistration rewritten in place, replacing plan 02-06's three placeholders with real registrations"
  - "OnboardingFlow.cardioActivityType/cardioCaptureMode transient carriers and OnboardingFlow.returnToHub() (both added to StepRegistry.swift)"
affects: ["02-16 (on-device GPS/motion-detection verification checkpoint; StepRegistry cross-suite concurrency fix)"]

tech-stack:
  added: []
  patterns:
    - "Every screen's behavior lives in a @MainActor @Observable model class (CardioActivityPickerModel/CardioSessionModel/CardioHistoryModel/RouteComparisonModel), tested directly at the model level per the plan's explicit instruction -- no rendering in any test"
    - "Grade-adjusted pace and route-map data are both consumed via optional binding and omitted entirely (not a placeholder glyph/fabricated line) when the underlying signal/data isn't there -- one 'omit rather than fake' discipline applied twice"
    - "CardioActivityPickerView/CardioSessionView/CardioHistoryView created as real (non-'Placeholder'-named) minimal stand-ins in Task 1 so CardioRegistration could register all three real types immediately, then rewritten in full by Tasks 2 and 3 in the same files"

key-files:
  created:
    - RithamApp/Ritham/Cardio/Views/CardioActivityPickerView.swift
    - RithamApp/Ritham/Cardio/Views/CardioSessionView.swift
    - RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift
    - RithamApp/Ritham/Cardio/Views/RouteComparisonView.swift
    - RithamApp/RithamTests/CardioViewTests.swift
  modified:
    - RithamApp/Ritham/Cardio/CardioRegistration.swift
    - RithamApp/Ritham/App/StepRegistry.swift

key-decisions:
  - "OnboardingFlow (defined inside StepRegistry.swift, not a separate OnboardingFlow.swift) gained two transient fields (cardioActivityType/cardioCaptureMode) and a returnToHub() method, matching the existing calibrationMode precedent -- necessary to hand the picker's choice to the session screen and to pop two levels back to the hub on finish. Confirmed unclaimed by any of plans 02-11 through 02-16's files_modified before editing."
  - "CardioSessionModel.pause() calls StopwatchCardioSession.stop(), not .pause() -- .pause() zeroes continuousDuration via CardioProgress.recordInterruption() (the calibration break-continuity semantics its own doc comment describes), while .stop() freezes elapsed time without that penalty, which is what a live-session pause/resume needs. Caught by a failing unit test before commit."
  - "GPSTrackingSession has no resume() (02-09's deliberate scope decision); CardioSessionModel.resume() calls gpsSession.start() again for the GPS path, accepting the known limitation (documented in 02-09-SUMMARY) that this also resets GPSTrackingSession's own sessionStartedAt metadata field -- out of this plan's file scope to fix."
  - "No coordinate/location-trail data is persisted anywhere in the codebase this plan can reach (CardioProgress, CardioSessionRecord, and GPSTrackingSession's own accumulator all discard/never store per-sample coordinates). CardioHistoryView's routeMap(for:) is a real MapKit helper gated on non-empty input, called with [] today, rather than fabricating a route line or skipping MapKit entirely. RouteComparisonView's 'same route' is therefore approximated as this user's own sessions of the same activity type within a 250m distance band -- the only route identity the stored data supports -- documented explicitly in both files' header comments."

requirements-completed: [CARDIO-01, CARDIO-02, CARDIO-03, CROSSGEN-02]

coverage:
  - id: D1
    description: "Activity picker offers all six known activity types plus a GPS-tracked start and a permission-free manual start; the cardio registrar registers three real screens"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioViewTests.swift#CardioActivityPickerTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Auto-detect candidate surfaces as an accept/dismiss confirmation; dismissing writes nothing, accepting carries the activity type into the session that starts"
    requirement: "CROSSGEN-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioViewTests.swift#CardioActivityPickerTests (dismissingDetectionLeavesStoredSessionCountUnchanged, acceptingDetectionCarriesActivityType)"
        status: pass
    human_judgment: true
    rationale: "Real CMMotionActivityManager classification cannot be produced in the Simulator (02-09's own finding); on-device confirmation that the prompt actually surfaces from a real walk/run is a 02-16 checkpoint, per 02-VALIDATION.md's Manual-Only Verifications table. This plan's slice (the confirmation UI, accept/dismiss/carry-forward logic) is code-complete and unit-tested against synthetic candidates."
  - id: D3
    description: "Live session shows duration, distance, pace and splits, with two independent confidence indicators; grade-adjusted pace is omitted (not faked) when the elevation signal is weak; denied GPS authorization falls back to the manual timer without ending the session; finishing saves exactly one session"
    requirement: "CARDIO-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioViewTests.swift#CardioSessionScreenTests"
        status: pass
    human_judgment: true
    rationale: "Real GPS pace/distance/elevation accuracy cannot be produced in the Simulator; on-device confirmation against a known route is a 02-16 checkpoint. This plan's confidence-display, grade-adjusted-pace-omission, and denied-authorization-fallback logic are unit-tested directly."
  - id: D4
    description: "Training history lists sessions most recent first with a visible sensor-verified-vs-manual label, a date-range filter, and an explicit empty state"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioViewTests.swift#CardioHistoryTests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Route comparison is single-user and opt-in-off-by-default; the entry point is structurally absent (not merely hidden) when the opt-in is off, and matches are filtered to this user's own sessions only"
    requirement: "CARDIO-03"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioViewTests.swift#CardioHistoryTests (optInOffProducesNoComparisonEntryPoint, routeComparisonEmptyWhileOptedOut, routeComparisonListsOnlyMatchingOwnSessions)"
        status: pass
    human_judgment: false

duration: 90min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 10: Cardio User Interface Summary

**Four new cardio screens (activity picker, live tracked session, training history, opt-in single-user route comparison) built model-first and tested at the model level, closing out the code-complete slice of CARDIO-01/02/03 and CROSSGEN-02 with on-device sensor verification deferred to plan 02-16 as planned.**

## Performance

- **Duration:** ~90 min
- **Tasks:** 3/3
- **Files modified:** 4 new view files, 1 new test file, 2 modified (CardioRegistration.swift, StepRegistry.swift), plus `Ritham.xcodeproj/project.pbxproj` regenerated via `xcodegen generate` after each new file

## Accomplishments

- `CardioActivityPickerView` renders all six `ActivityType.known` values through the existing `ChoiceQuestionView`/`ChoiceChip` components, offers both a GPS-tracked start and a manual start that touches no CoreLocation API at all, and surfaces `MotionActivityDetector`'s candidate as an accept/dismiss confirmation whose dismiss path writes nothing and whose accept path carries the detected activity type forward.
- `CardioSessionView` drives either `GPSTrackingSession` or `StopwatchCardioSession` (chosen by the picker), rendering elapsed duration via the reused `RadialSessionTimer`, distance, pace, elevation, and splits. Position and elevation confidence render as two independent indicators (`horizontalConfidence`/`elevationConfidence`), never blended. Grade-adjusted pace is consumed via `if let` and the row is omitted entirely — never a placeholder glyph — when `GradeAdjustedPace.adjustedSecondsPerKm` returns `nil`. A denied/restricted GPS authorization switches to the manual timer without ending the session or showing a blocking dialog. Finishing saves exactly one session through `HealthDataStore.saveCardioSession` and pops back to the hub.
- `CardioHistoryView` lists sessions most recent first with a visible sensor-verified-vs-manual label, a date-range filter, an explicit empty state, and a real MapKit-based route-map helper — see Known Stubs below for why it always renders the "no location trail" branch in this milestone.
- `RouteComparisonView` is single-user and opt-in by construction: no leaderboard/ranking/cross-user concept anywhere in the file (asserted by a source-level acceptance grep), gated behind `HealthDataStore`'s route-comparison opt-in flag (defaults off), with its own inline toggle to turn comparison back off from the same screen.
- `CardioRegistration.swift` rewritten in place, replacing plan 02-06's three placeholder presenters with the three real screens above.

## Task Commits

Each task was committed atomically:

1. **Task 1: Activity picker, capture-mode choice, and the auto-detect confirmation** - `0835981` (feat)
2. **Task 2: Live session screen with visible confidence and session save** - `cbf5900` (feat)
3. **Task 3: Training history and opt-in single-user route comparison** - `b8d079e` (feat)

**Plan metadata:** _(this commit)_

_No TDD RED/GREEN split — like plans 02-08/02-09 before it, each task's behavior and tests were authored and verified together before committing, since no `MVP_MODE`/`TDD_MODE` gate is active for this phase._

## Files Created/Modified

- `RithamApp/Ritham/Cardio/Views/CardioActivityPickerView.swift` - activity/capture-mode picker + auto-detect confirmation
- `RithamApp/Ritham/Cardio/Views/CardioSessionView.swift` - live tracked session (GPS or manual), confidence, grade-adjusted pace, save
- `RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift` - training history, date filter, empty state, route-map stub
- `RithamApp/Ritham/Cardio/Views/RouteComparisonView.swift` - single-user opt-in route comparison
- `RithamApp/RithamTests/CardioViewTests.swift` - `CardioActivityPickerTests` (7), `CardioSessionScreenTests` (7), `CardioHistoryTests` (10) — 24 tests total
- `RithamApp/Ritham/Cardio/CardioRegistration.swift` - rewritten in place, registers the three real screens
- `RithamApp/Ritham/App/StepRegistry.swift` - added `OnboardingFlow.cardioActivityType`/`cardioCaptureMode`/`returnToHub()` (Rule 3 deviation)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each new file

## Decisions Made

See `key-decisions` in the frontmatter above for the four substantive decisions (OnboardingFlow carrier fields, the pause-vs-stop fix, the GPS-resume limitation, and the route-comparison distance-band proxy).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking issue] Added transient carrier fields and a navigation helper to `OnboardingFlow`**
- **Found during:** Task 1
- **Issue:** The picker needs to hand its chosen activity type and capture mode to `CardioSessionView`, and `CardioSessionView` needs to pop two levels back to the hub on finish. Neither mechanism existed, and this plan's own `files_modified` list didn't include the file where `OnboardingFlow` lives (`StepRegistry.swift`, not a separate `OnboardingFlow.swift` as its own class header comment might suggest to a reader skimming other plans' text).
- **Fix:** Added `cardioActivityType`/`cardioCaptureMode` (matching `calibrationMode`'s existing precedent exactly) and `returnToHub()` (matching `open(_:)`'s "no branching decision" reasoning). Confirmed via grep that no plan 02-11 through 02-16 claims `StepRegistry.swift` in its own `files_modified` before editing.
- **Files modified:** `RithamApp/Ritham/App/StepRegistry.swift`
- **Verification:** All 24 tests pass; full `xcodebuild build` succeeds.
- **Committed in:** `0835981` (Task 1), `cbf5900` (the `returnToHub()` addition landed alongside Task 1's fields but is exercised starting in Task 2)

**2. [Rule 1 - bug] `CardioSessionModel.pause()` used the wrong adapter method**
- **Found during:** Task 2, while writing the pause/resume unit test
- **Issue:** Calling `StopwatchCardioSession.pause()` zeroes `continuousDuration` via `CardioProgress.recordInterruption()` (that type's calibration-derived "this broke continuity" semantics) rather than freezing it — a real pause/resume unit test caught this immediately (`0.0` instead of `60.0` after pause).
- **Fix:** Changed to call `.stop()` instead, which freezes elapsed time without the interruption penalty; `.resume()` was already correct.
- **Files modified:** `RithamApp/Ritham/Cardio/Views/CardioSessionView.swift`
- **Verification:** `pausingFreezesAndResumingContinues` test passes.
- **Committed in:** `cbf5900`

**3. [Rule 2 - missing critical, scoped] `CardioHistoryView`'s route map has no coordinate data to render**
- **Found during:** Task 3, before writing any code (confirmed via advisor consultation)
- **Issue:** The plan's action text asks for "a route map for a selected session using MapKit," and `RouteComparisonView`'s single-user comparison implies matching sessions on "the same route." No file this plan can touch (or any file in the whole codebase) persists a per-sample coordinate trail — `CardioProgress` (02-01), `CardioSessionRecord` (02-08), and `GPSTrackingSession` (02-09) all store or expose only aggregate distance/elevation/splits. Adding coordinate storage would mean a `@Model` schema change across three other plans' owned files — a Rule 4 architectural change out of this plan's scope, not something to ask the user to approve mid-execution.
- **Fix:** `routeMap(for samples: [LocationSample])` is a real MapKit helper, gated on non-empty input, called with `[]` at every call site today; the absent-data branch states plainly that no location trail was recorded, rather than fabricating one. `RouteComparisonView`'s "same route" match is a documented distance-band-within-activity-type proxy instead of real polyline matching. Both files' header comments record this explicitly so a future plan that does persist a coordinate trail knows exactly what to change.
- **Files modified:** `RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift`, `RithamApp/Ritham/Cardio/Views/RouteComparisonView.swift`
- **Verification:** `import MapKit` present with no third-party mapping import; no leaderboard/ranking/cross-user identifier anywhere in `RouteComparisonView.swift`; `xcodebuild build` succeeds.
- **Committed in:** `b8d079e`

**4. [Rule 3 - blocking issue] Task 1 pre-created real (non-"Placeholder"-named) minimal stand-ins for `CardioSessionView`/`CardioHistoryView`**
- **Found during:** Task 1
- **Issue:** Task 1's own action text requires `CardioRegistration.swift` to register "the three real screens created in this plan" in the same commit, but `CardioSessionView.swift` and `CardioHistoryView.swift` are Task 2's and Task 3's primary deliverables — registering them before they exist would not compile.
- **Fix:** Task 1 created minimal, genuinely-named (not "Placeholder") versions of both files, satisfying `CardioRegistration.swift`'s registration requirement and the "Placeholder count is 0" acceptance criterion immediately. Tasks 2 and 3 then rewrote each file in full in place, exactly as their own action text describes.
- **Files modified:** `RithamApp/Ritham/Cardio/Views/CardioSessionView.swift`, `RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift` (both fully superseded by Tasks 2/3 later in the same plan)
- **Verification:** Task 1's own acceptance greps (`Placeholder` count 0, `StepRegistry.register` count 3) passed at Task 1's commit; both files' final content was verified against Task 2/3's own acceptance criteria at their respective commits.
- **Committed in:** `0835981` (Task 1's minimal versions), superseded by `cbf5900` and `b8d079e`

---

**Total deviations:** 4 (1 Rule 3 file-scope necessity, 1 Rule 1 bug caught by a failing test, 1 Rule 2 scoped gap around a pre-existing data-model limitation, 1 Rule 3 task-ordering necessity)
**Impact on plan:** All four are documented, low-risk, and reversible without touching any file this plan doesn't own. No scope creep — no new persistent schema, no new registrar files, no `StepBootstrap.swift` edit.

## Known Stubs

- **`CardioHistoryView.routeMap(for:)`** (`RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift`) — always called with `[]` (an empty `[LocationSample]` array) at every call site in this milestone, because no coordinate trail is persisted anywhere in the codebase this plan can reach. The helper itself is real MapKit code, exercised at every build, and the empty-input branch renders an honest "no location trail recorded" message rather than a blank or fabricated map. Resolved when a future plan adds coordinate-trail persistence to `CardioProgress`/`CardioSessionRecord`/`GPSTrackingSession` (currently unowned by any plan in this phase).
- **`RouteComparisonModel`'s "same route" match** (`RithamApp/Ritham/Cardio/Views/RouteComparisonView.swift`) — approximated as this user's own sessions of the same `activityType` within a 250m distance band, since no coordinate data exists to do real polyline matching. Documented in the file's header comment. Resolved by the same future coordinate-persistence plan referenced above.

## Threat Flags

None beyond what the plan's own threat model already covers (T-02-32, T-02-30, T-02-04, T-02-31, T-02-05 — all mitigated as specified; see coverage above). The Known Stubs entries above narrow T-02-32's disclosure surface further rather than widening it: with no coordinate data persisted anywhere, the route-comparison surface cannot disclose a location trail, this user's or anyone else's, even in principle.

## Issues Encountered

None beyond the four deviations documented above, all resolved before their respective task commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three `-only-testing:` suites (`CardioActivityPickerTests`: 7, `CardioSessionScreenTests`: 7, `CardioHistoryTests`: 10 — 24 tests total) pass individually and together in one run; `xcodebuild build` succeeds for the full scheme.
- `StepBootstrap.swift` and `HealthDataStore.swift` remain untouched by this plan, confirmed via `git diff --name-only` at each task commit.
- CARDIO-01/02/03 and CROSSGEN-02 are marked complete in `REQUIREMENTS.md`. On-device verification of GPS pace/distance/elevation accuracy and real motion-classification prompting remain open checkpoints tracked in `02-VALIDATION.md`'s Manual-Only Verifications table, owned by plan 02-16 — unchanged by this plan, just reconfirmed as still applicable.
- The pre-existing `StepRegistry` cross-suite concurrency flake (documented in `STATE.md` Blockers/Concerns) means this plan's three new suites were verified via their own `-only-testing:` targets (individually and combined), not a full unscoped `xcodebuild test` run, per the plan's own `<verification>` section.
- Plans 02-11 through 02-15 (strength logging/history, guidance, recommendations) can now build against a working cardio reference implementation for the same model-first, store-driven, MapKit-if-real-data-exists patterns established here.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 6 created/modified source files plus this SUMMARY.md confirmed present on disk; all three
task commit hashes (`0835981`, `cbf5900`, `b8d079e`) confirmed present in `git log --all`.
