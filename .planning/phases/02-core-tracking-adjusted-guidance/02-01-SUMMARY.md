---
phase: 02-core-tracking-adjusted-guidance
plan: 01
subsystem: domain
tags: [swift, foundation-only, cardio, gps, minetti, grade-adjusted-pace]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake
    provides: CalibrationSession.swift's Foundation-only session-progress pattern (CalibrationThreshold, private(set)-plus-mutating-method discipline), reused as the shape for this new peer domain
provides:
  - Extensible ActivityType vocabulary (RawRepresentable struct, not a closed enum)
  - CardioSession/CardioProgress/CardioQualification pure-Swift domain, sharing CalibrationThreshold.qualifyingWalkDuration with Phase 1's calibration domain (D-02)
  - CardioCaptureSource.isSensorVerified (manual-vs-sensor-verified provenance) for Phase 3's Momentum
  - CardioTrackAccumulator: accuracy- and plausible-speed-filtered distance/elevation/split accumulation from LocationSample
  - GradeAdjustedPace: Minetti-grounded grade adjustment, nil-gated on elevation confidence
affects: [02-08 (SwiftData persistence of CardioSession), 02-09 (CoreLocation/CoreMotion adapters mapping into LocationSample/CardioTrackAccumulator), phase-3-momentum (reads CardioCaptureSource.isSensorVerified)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extensible RawRepresentable-struct vocabulary (ActivityType) instead of a closed enum, for CARDIO-01's no-source-edit extensibility requirement"
    - "Independent SignalConfidence tracking for horizontal vs. elevation signals, never blended into one confidence value"
    - "nil-on-low-confidence gating with no confidence-free overload (GradeAdjustedPace), preventing any caller from rendering a fabricated number"
    - "Accuracy-threshold + plausible-speed sample filtering (not Kalman/Hampel smoothing) ahead of distance accumulation"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Cardio/ActivityType.swift
    - RithamCore/Sources/RithamCore/Cardio/CardioSession.swift
    - RithamCore/Sources/RithamCore/Cardio/CardioTrackAccumulator.swift
    - RithamCore/Sources/RithamCore/Cardio/GradeAdjustedPace.swift
    - RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift
    - RithamCore/Tests/RithamCoreTests/CardioTrackAccumulatorTests.swift
    - RithamCore/Tests/RithamCoreTests/GradeAdjustedPaceTests.swift
  modified: []

key-decisions:
  - "CardioProgress.recordInterruption() zeroes only continuousDuration (the qualifying-bar clock), never distanceMeters/elevationGainMeters — ground already covered during a cardio session is real and stays recorded, unlike WalkProgress's calibration-specific full reset"
  - "GradeAdjustedPace.adjustedSecondsPerKm divides raw pace by a grade-derived effort factor (not multiplies): uphill (effort factor > 1) yields a faster/smaller adjusted number, moderate downhill (factor < 1) yields a slower/larger one, and the -10% inflection point is where downhill benefit peaks before reversing due to eccentric-braking cost"
  - "CardioTrackAccumulator's horizontal/elevation confidence-mapping functions are private, not part of the public API surface — only accept(_:) and progress are exposed, matching CardioProgress's own no-public-setters discipline"

patterns-established:
  - "Grade-adjusted pace as effort-factor division (pace / (1 + costFraction)), with three named coefficient regimes (uphill, downhill-to-inflection, past-inflection) instead of inline literals"

requirements-completed: [CARDIO-01, CARDIO-02]

coverage:
  - id: D1
    description: "Extensible ActivityType vocabulary (run/walk/cycle/hike/swim/elliptical, plus any raw value outside known) with no exhaustive-switch edit required to add an activity"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift#unknownActivityTypeIsUsableButNotInKnown"
        status: pass
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift#knownActivityTypesRoundTripThroughRawValue"
        status: pass
    human_judgment: false
  - id: D2
    description: "CardioSession/CardioProgress/CardioQualification domain, sharing CalibrationThreshold.qualifyingWalkDuration rather than restating 600, and distinguishing manual-stopwatch from sensor-verified capture"
    requirement: "CARDIO-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift#evaluateIsCompleteAtExactlyTheBar"
        status: pass
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift#manualStopwatchIsNotSensorVerified"
        status: pass
    human_judgment: false
  - id: D3
    description: "CardioTrackAccumulator rejects samples beyond rejectionAccuracyMeters and above implausibleSpeedMetersPerSecond before they reach distance, and tracks horizontal/elevation confidence independently"
    requirement: "CARDIO-02"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioTrackAccumulatorTests.swift#implausibleSpeedSampleIsDiscarded"
        status: pass
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/CardioTrackAccumulatorTests.swift#elevationConfidenceIsIndependentOfHorizontalConfidence"
        status: pass
    human_judgment: false
  - id: D4
    description: "GradeAdjustedPace returns nil (never an approximate number) whenever elevation confidence is unavailable/low, grounded in the Minetti curve rather than a proprietary formula"
    requirement: "CARDIO-02"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GradeAdjustedPaceTests.swift#returnsNilForLowConfidenceAtEveryGrade"
        status: pass
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GradeAdjustedPaceTests.swift#steepDownhillReversesBenefitPastInflection"
        status: pass
    human_judgment: false

# Metrics
duration: 20min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 01: Cardio Domain Foundation Summary

**Pure-Swift cardio session domain — extensible ActivityType, accuracy-filtered CardioTrackAccumulator, and Minetti-grounded GradeAdjustedPace with elevation-confidence gating**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-05T07:39:21Z
- **Completed:** 2026-09-05T08:00:00Z
- **Tasks:** 3
- **Files modified:** 7 (all new)

## Accomplishments
- `ActivityType` is an extensible `RawRepresentable` struct (not a closed enum) — `ActivityType(rawValue: "rowing")` works with no source edit, per CARDIO-01
- `CardioSession`/`CardioProgress`/`CardioQualification` form a pure-Swift, Foundation-only domain that is a deliberate peer of Phase 1's `CalibrationSession` (D-02), sharing only `CalibrationThreshold.qualifyingWalkDuration`
- `CardioCaptureSource.isSensorVerified` records manual-stopwatch-vs-sensor-verified provenance now, ahead of Phase 3's Momentum needing it
- `CardioTrackAccumulator` filters GPS samples by horizontal accuracy and by plausible instantaneous speed before they can inflate distance (T-02-03), tracks horizontal/elevation `SignalConfidence` independently, and emits a `CardioSplit` per kilometre
- `GradeAdjustedPace.adjustedSecondsPerKm` computes a Minetti-grounded grade adjustment and returns `nil` — never an approximate number — whenever elevation confidence is `.unavailable`/`.low`, with no confidence-free overload (CARDIO-02, T-02-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Activity-type vocabulary and cardio session value types** - `656d759` (feat)
2. **Task 2: Accuracy-filtered track accumulator and split generation** - `86114eb` (feat)
3. **Task 3: Grade-adjusted pace with elevation-confidence gating** - `0f66eae` (feat)

_No TDD RED/GREEN/REFACTOR commit split was used — each task's source file and its test suite were written and verified together before a single commit, consistent with how Phase 1's plans in this repo committed tdd="true" tasks._

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Cardio/ActivityType.swift` - Extensible activity-type vocabulary
- `RithamCore/Sources/RithamCore/Cardio/CardioSession.swift` - `CardioCaptureSource`, `CardioSplit`, `SignalConfidence`, `CardioProgress`, `CardioSession`, `CardioQualification`
- `RithamCore/Sources/RithamCore/Cardio/CardioTrackAccumulator.swift` - `LocationSample`, accuracy/speed-filtered distance and split accumulation
- `RithamCore/Sources/RithamCore/Cardio/GradeAdjustedPace.swift` - Grade computation and confidence-gated pace adjustment
- `RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift` - 11 tests
- `RithamCore/Tests/RithamCoreTests/CardioTrackAccumulatorTests.swift` - 6 tests
- `RithamCore/Tests/RithamCoreTests/GradeAdjustedPaceTests.swift` - 12 tests

## Decisions Made
- `CardioProgress.recordInterruption()` zeroes only `continuousDuration`, never `distanceMeters`/`elevationGainMeters` — a cardio session's ground already covered is real training data and stays recorded, unlike `WalkProgress`'s calibration-specific full reset (calibration is a one-time pass/fail gate; cardio tracking is an ongoing session whose partial distance still matters after an interruption).
- `GradeAdjustedPace.adjustedSecondsPerKm` divides the raw pace by a grade-derived effort factor rather than multiplying: an uphill effort factor above 1 yields a *faster* (smaller) adjusted number (climbing at a given pace reflects more work, i.e. an equivalent flat effort would be faster), and a downhill factor below 1 yields a *slower* (larger) one. The -10% inflection point is where downhill benefit peaks before reversing (eccentric-braking cost), so a -20% grade produces a smaller, less generous adjustment than -10% does — not a larger one, since the physiological benefit of descent shrinks past that point.
- The accumulator's horizontal-accuracy-to-confidence and vertical-accuracy-to-confidence mapping functions are kept `private` — only `accept(_:)` and `progress` are exposed, matching `CardioProgress`'s own no-public-setters discipline and keeping the threshold-to-confidence mapping an implementation detail.

## Deviations from Plan

None - plan executed exactly as written. All must-haves, artifacts, and key-links from the plan frontmatter are present: `CardioQualification.evaluate` reads `CalibrationThreshold.qualifyingWalkDuration`; `GradeAdjustedPace.adjustedSecondsPerKm` returns `nil` for low-confidence elevation with no confidence-free overload; `CardioTrackAccumulator` rejects samples above the accuracy and plausible-speed thresholds before they reach distance.

## Issues Encountered
- An initial draft of `GradeAdjustedPace.adjustedSecondsPerKm` used multiplication (`pace * (1 + costFraction)`) with a cost fraction that grew for both uphill and downhill grades. This produced the wrong direction for uphill (a slower, larger number instead of the required faster, smaller one) and the wrong ordering for the -10%/-20% comparison. Caught before committing, by working through the required test behaviors against the draft formula's actual output rather than assuming the first draft was correct; corrected to a division-based effort-factor model (see Decisions Made) and verified against all listed behaviors before the Task 3 commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `RithamCore/Cardio/` now provides the Foundation-only domain plan 02-09's CoreLocation/CoreMotion adapters and plan 02-08's SwiftData persistence layer both need to target.
- `CardioCaptureSource.isSensorVerified` is recorded from day one, so a later Phase 3 Momentum plan does not need to backfill capture provenance onto already-recorded sessions.
- No blockers. `cd RithamCore && ./Scripts/test-core.sh` is green with 193 tests across 14 suites, including the three new suites from this plan.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 7 created files verified present on disk; all 3 task commit hashes (656d759, 86114eb, 0f66eae) verified present in git history.
