---
phase: 02-core-tracking-adjusted-guidance
plan: 09
subsystem: cardio-capture
tags: [swift, coreLocation, coreMotion, swiftui, cardio, gps, motion-classification]

requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "RithamCore's Foundation-only Cardio domain (ActivityType, CardioSession, CardioProgress, CardioTrackAccumulator, LocationSample) from plan 02-01"
provides:
  - "StopwatchCardioSession: zero-permission manual cardio timer (no CoreLocation/CoreMotion import)"
  - "GPSTrackingSession: first-class CLLocationManager wrapper requesting when-in-use authorization at session start, feeding CardioTrackAccumulator"
  - "MotionActivityDetector: CMMotionActivityManager wrapper publishing a confidence-gated walk/run detection candidate, with no session-writing path"
  - "Reworded NSLocationWhenInUseUsageDescription / NSMotionUsageDescription describing Phase 2's actual use"
affects: ["02-10 (cardio session view, activity picker, confirmation-prompt UI consuming these three adapters)"]

tech-stack:
  added: []
  patterns:
    - "App-layer sensor adapters are peers of Phase 1's calibration adapters, not extensions (RithamCore stays Foundation-only; new types instead of stretching CalibrationSessionSource)"
    - "GPS authorization inversion documented in-file: calibration's no-prompt rule does not generalize to a user-requested GPS feature"
    - "Pure mapping functions (MotionActivityDetector.makeCandidate/mapConfidence) kept separate from framework callbacks so sensor logic neither the app target nor the Simulator can exercise for real is still unit-testable"

key-files:
  created:
    - RithamApp/Ritham/Cardio/StopwatchCardioSession.swift
    - RithamApp/Ritham/Cardio/GPSTrackingSession.swift
    - RithamApp/Ritham/Cardio/MotionActivityDetector.swift
    - RithamApp/RithamTests/CardioCaptureTests.swift
  modified:
    - RithamApp/Ritham/Resources/Info.plist

key-decisions:
  - "GPSTrackingSession requests when-in-use authorization only (never always) and never enables background location updates; startUpdatingLocation is confined to a single call site in start()"
  - "GPSTrackingSession exposes authorizationStatus and requiresManualFallback for the view layer; it never presents an alert or navigates itself"
  - "MotionActivityDetector's foreground/background lifecycle is the caller's (plan 02-10 view's) responsibility via startObserving()/stopObserving(), matching PedometerSession's precedent of not self-managing app lifecycle"
  - "When CMMotionActivityManager reports both walking and running above threshold confidence, running wins as the more specific classification"

requirements-completed: []

coverage:
  - id: D1
    description: "Manual stopwatch cardio session times a session with an injected clock, imports no sensor framework, and produces a manually-sourced CardioSession"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioCaptureTests.swift#StopwatchCardioSessionTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "GPSTrackingSession requests when-in-use authorization at session start, scopes location updates to the session lifecycle, and delegates all measurement to CardioTrackAccumulator"
    requirement: "CARDIO-02"
    verification:
      - kind: other
        ref: "xcodebuild build -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17' (BUILD SUCCEEDED) plus source-level acceptance-criteria greps in 02-09-PLAN.md Task 2"
        status: pass
    human_judgment: true
    rationale: "The Simulator cannot produce real GPS movement or a real authorization prompt; on-device verification is deferred to plan 02-16 per 02-VALIDATION.md's Manual-Only Verifications table."
  - id: D3
    description: "MotionActivityDetector publishes a confidence-thresholded walk/run detection candidate and has no code path that writes a session"
    requirement: "CROSSGEN-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/CardioCaptureTests.swift#MotionActivityDetectorTests"
        status: pass
    human_judgment: true
    rationale: "CROSSGEN-02 also requires the user-facing confirmation prompt (plan 02-10) and real on-device motion classification (Simulator cannot produce it, per 02-VALIDATION.md); this plan's slice is the detector only."

duration: 15min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 09: Cardio Capture Adapters Summary

**Three new app-layer sensor adapters — a zero-permission manual stopwatch, a first-class GPS tracking session that requests when-in-use authorization and delegates all math to the pure `CardioTrackAccumulator`, and a foreground `CMMotionActivityManager` auto-detect wrapper that only ever offers, never logs — plus reworded location/motion usage-description strings.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-05T11:02:54Z
- **Completed:** 2026-09-05T11:17:21Z
- **Tasks:** 3/3
- **Files modified:** 4 created, 1 modified (plus `Ritham.xcodeproj/project.pbxproj` regenerated via `xcodegen` after each new file)

## Accomplishments

- `StopwatchCardioSession` times a manual cardio session against an injected clock, imports neither `CoreLocation` nor `CoreMotion`, and is never blocked by a permission decision — preserving PROJECT.md's phone-only promise. Its `finish()` always produces a `.manualStopwatch`-sourced `CardioSession` (`isSensorVerified == false`).
- `GPSTrackingSession` requests when-in-use authorization exactly once, at session start, and confines `startUpdatingLocation()` to that single call site with a matching `stopUpdatingLocation()` on pause/stop. It never requests always-authorization or enables background updates. Every `CLLocation` it receives is mapped into RithamCore's `LocationSample` and fed to `CardioTrackAccumulator`, which owns all accuracy filtering, distance, elevation, and split computation.
- `MotionActivityDetector` wraps `CMMotionActivityManager` (a distinct CoreMotion class from Phase 1's `CMPedometer`-based `PedometerSession`), publishing a `MotionDetectionCandidate` only when confidence is at or above medium — the candidate-mapping logic (`makeCandidate`/`mapConfidence`) is a pure static function tested directly with synthetic inputs, since the Simulator cannot produce real motion classification. The type has no method that creates, saves, or starts a session.
- `Info.plist`'s `NSLocationWhenInUseUsageDescription` and `NSMotionUsageDescription` were reworded to describe Phase 2's actual use (pace/distance/elevation/splits during a user-started workout; movement measurement plus walk/run detection with explicit confirmation) instead of the calibration walk. Neither string references calibration; `plutil -lint` passes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Manual stopwatch cardio session** - `b6ea99f` (test — implementation + TDD suite in one commit, see Deviations)
2. **Task 2: First-class GPS tracking session and updated usage descriptions** - `532325b` (feat)
3. **Task 3: Foreground-only motion auto-detect** - `63a7586` (feat)

**Plan metadata:** _(pending — this commit)_

## Files Created/Modified

- `RithamApp/Ritham/Cardio/StopwatchCardioSession.swift` - manual cardio stopwatch, zero-permission
- `RithamApp/Ritham/Cardio/GPSTrackingSession.swift` - first-class GPS tracking session, when-in-use authorization
- `RithamApp/Ritham/Cardio/MotionActivityDetector.swift` - foreground motion auto-detect, offer-only
- `RithamApp/RithamTests/CardioCaptureTests.swift` - `StopwatchCardioSessionTests` (6 tests), `MotionActivityDetectorTests` (6 tests)
- `RithamApp/Ritham/Resources/Info.plist` - reworded `NSLocationWhenInUseUsageDescription` / `NSMotionUsageDescription`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each new file (Rule 3 precedent from plan 02-06)

## Decisions Made

- `GPSTrackingSession` does not expose a `resume()` method — the plan's own "Artifacts this phase produces" list names only `start`/`pause`/`stop`/`finish`, and an initial `resume()` implementation was removed once the acceptance criterion "`startUpdatingLocation` exactly 1 occurrence in the file" surfaced the mismatch. Pause/resume-by-restarting-location-updates, if wanted, belongs to a future plan that revisits the contract.
- Reworded the GPS-inversion header comment to describe both `CLLocationManager` authorization-request methods by role rather than by literal method name, after the acceptance criterion "`requestWhenInUseAuthorization` count is exactly 1" caught the doc comment's own reference to that method name as a second match.
- `MotionActivityDetector`'s `startObserving()`/`stopObserving()` do not self-manage app-foreground/background lifecycle internally (e.g. via `NotificationCenter` observers) — that responsibility is left to the caller (plan 02-10's session view), matching `PedometerSession`'s existing precedent of not self-managing lifecycle. This keeps the type a plain, synchronously-testable wrapper.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking issue] Removed an unplanned `resume()` from `GPSTrackingSession`**
- **Found during:** Task 2, while verifying acceptance criteria
- **Issue:** An initial draft added a `resume()` method calling `startUpdatingLocation()` a second time, which broke the acceptance criterion requiring exactly one `startUpdatingLocation` call site in the file, and was never listed in the plan's own artifact list for this type.
- **Fix:** Removed `resume()`; `start()`/`pause()`/`stop()`/`finish()` are the complete public surface, matching the plan's artifact table.
- **Files modified:** `RithamApp/Ritham/Cardio/GPSTrackingSession.swift`
- **Verification:** `grep -c 'startUpdatingLocation'` returns 1; `xcodebuild build` still succeeds.
- **Committed in:** `532325b` (part of Task 2's commit)

**2. [Rule 1 - bug] Reworded a doc comment that accidentally duplicated a grepped API name**
- **Found during:** Task 2, while verifying acceptance criteria
- **Issue:** The header comment's own prose used the literal token `requestWhenInUseAuthorization`, making `grep -c 'requestWhenInUseAuthorization'` return 2 instead of the required exactly-1 (the real call site plus the comment).
- **Fix:** Reworded the comment to refer to "both of CLLocationManager's authorization-request methods" without repeating either literal method name.
- **Files modified:** `RithamApp/Ritham/Cardio/GPSTrackingSession.swift`
- **Verification:** `grep -c 'requestWhenInUseAuthorization'` returns 1.
- **Committed in:** `532325b` (part of Task 2's commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1/3, both caught by the plan's own acceptance-criteria greps before committing)
**Impact on plan:** Both fixes tightened the implementation to match the plan's stated artifact surface exactly; no scope creep.

## Issues Encountered

Task 1 is marked `tdd="true"` in the plan, but the test suite (`StopwatchCardioSessionTests`) and the implementation (`StopwatchCardioSession.swift`) were written together and committed in a single `test(...)` commit rather than as separate RED-then-GREEN commits, since no `MVP_MODE`/`TDD_MODE` gate was active for this phase and the plan itself supplies both `<behavior>` and `<action>` as a combined spec. All six behaviors were verified passing before commit. Flagging this for the record rather than silently treating it as full TDD-gate compliance — see `## TDD Gate Compliance` below.

## TDD Gate Compliance

Task 1 (`tdd="true"`) does not have a separate failing-test commit before the implementation commit — test and implementation landed together in `b6ea99f`. All 6 `StopwatchCardioSessionTests` were confirmed passing before that commit. No RED-gate commit exists to point to.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-10 can now build the cardio session view, activity picker, and detection-confirmation prompt directly on top of these three adapters: `StopwatchCardioSession` and `GPSTrackingSession` share the same `start`/`pause`/`stop`/`finish` shape, and `MotionActivityDetector.detectionCandidate` is ready to drive a confirm-or-dismiss prompt.
- `CROSSGEN-02` stays unchecked in `REQUIREMENTS.md` (already `[ ]` before this plan) — this plan delivers the detector half only; the user-facing confirmation prompt and full manual-configuration surface are 02-10's scope, per that plan's own `requirements: [CARDIO-01, CARDIO-02, CARDIO-03, CROSSGEN-02]` frontmatter. `CARDIO-01`/`CARDIO-02` were already marked `[x]` in `REQUIREMENTS.md` by plan 02-01's RithamCore domain work; no change made here.
- On-device verification of both the GPS authorization prompt/tracking and real motion classification remains open, tracked as a plan 02-16 checkpoint per `02-VALIDATION.md`'s Manual-Only Verifications table — unchanged by this plan, just reconfirmed as still applicable.
- The known cross-suite `StepRegistry` concurrency flake (documented in `STATE.md` Blockers/Concerns) means this plan's two new suites were verified via their individual `-only-testing:` targets, not a full `xcodebuild test` run, per the plan's own `<verification>` section.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*
