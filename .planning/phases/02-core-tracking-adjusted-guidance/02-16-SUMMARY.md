---
phase: 02-core-tracking-adjusted-guidance
plan: 16
subsystem: testing
tags: [swift-testing, xcodebuild, go, accessibility, gps, motion, ax3-ax5]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: cardio capture (GPS + manual stopwatch + motion auto-detect), strength logging/history, guidance, recommendations + pre-assessment, the Go workout-plan service
provides:
  - A fixed cross-suite Swift Testing race (StepRegistry's shared static state), verified over ten consecutive full-target runs
  - Phase2CoverageTests asserting all eight Phase 2 steps resolve to their real screen type, none a placeholder
  - Curl-verified contract behaviour of the local Go workout-plan service (all three permission tiers, and the service-down transport-error path)
  - A named, still-open gap: the three physical-device/simulator-UI verifications this plan's Tasks 2-3 require (real GPS, real motion auto-detect, on-device app rendering of the Go round trip, and the AX3/AX5 accessibility walkthrough) were not performable in this environment
affects: [phase-2-close-out, 02-VALIDATION.md Manual-Only Verifications table]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Swift Testing cross-suite serialization via an empty `.serialized` parent suite, with member suites nested into it through per-file `extension ParentSuite { ... }` blocks (Swift permits a nested type declaration to live in an extension in a different file from the type it extends). `.serialized` on a suite recurses through its entire subtree, which is the real fix a per-suite trait alone cannot provide."

key-files:
  created:
    - RithamApp/RithamTests/StepRegistrySerialization.swift
    - RithamApp/RithamTests/Phase2CoverageTests.swift
  modified:
    - RithamApp/RithamTests/AppShellTests.swift
    - RithamApp/RithamTests/AboutYouStepTests.swift
    - RithamApp/RithamTests/CalibrationSourceTests.swift
    - RithamApp/RithamTests/PhaseCoverageTests.swift
    - RithamApp/RithamTests/ScreeningFlowTests.swift
    - RithamApp/Ritham/App/StepRegistry.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj
    - .planning/STATE.md

key-decisions:
  - "Fixed the cross-suite StepRegistry race by nesting the five affected suites (plus the new Phase2CoverageTests) under one empty `.serialized` parent suite, rather than adding another per-suite trait or giving each suite its own registry state -- the plan's own action text explicitly rules out the former as the arrangement that already fails."
  - "Added StepRegistry.registeredPresenterType(for:) (Rule 3 deviation, StepRegistry.swift not in this plan's declared file list) because AnyView's type erasure makes it structurally impossible to assert 'which real screen type backs a step' any other reliable way; a Mirror-based reflection into AnyView's private storage was considered and rejected as fragile across SDK versions."
  - "Verified the Go service's round-trip contract (all three guidancePermission tiers, plus the service-down transport-error path) via direct curl against a locally-run instance on an alternate port (8090, not 8080), because port 8080 on this Mac is already bound by an unrelated long-running process from a different project (`sp-print`) that must not be killed. This confirms the service's own behaviour but does not substitute for the on-device 'app actually renders a plan / actually shows an error state' check Task 2 requires."

requirements-completed: []

coverage:
  - id: D1
    description: "Ten consecutive full-target xcodebuild test runs pass with no run reporting a registered step as unregistered, fixing the pre-existing StepRegistry cross-suite race"
    requirement: "CROSSGEN-02"
    verification:
      - kind: integration
        ref: "xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17' (run 10x consecutively)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase2CoverageTests asserts each of the eight Phase 2 steps resolves to its real presenter type, and none is a placeholder"
    requirement: "CROSSGEN-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/Phase2CoverageTests.swift#eachPhase2StepResolvesToItsRealScreenType, #noPhase2StepResolvesToAPlaceholderType"
        status: pass
    human_judgment: false
  - id: D3
    description: "Real GPS pace/distance measurement, confirmed against a real walk on a physical device"
    requirement: "CARDIO-02"
    verification: []
    human_judgment: true
    rationale: "Requires a physical iPhone walking a real route; no physical device is attached to this Mac, only the Simulator, which cannot produce real GPS signal. Genuine checkpoint, not automatable."
  - id: D4
    description: "Real motion auto-detect prompt confirmed on a physical device, and the Go round trip (plan render + service-down error state) confirmed against the app on a Debug build"
    requirement: "CROSSGEN-02, ONBOARD-01"
    verification:
      - kind: manual_procedural
        ref: "curl round-trip against a locally-run RithamService instance (all three permission tiers + service-down transport error) -- confirms the service contract only, not the on-device UI"
        status: pass
    human_judgment: true
    rationale: "Motion classification requires real ambulatory movement no simulator can produce. The on-device app-renders-a-plan / app-shows-error-state halves of the Go round trip require a running Debug build a human can look at; no touch-injection tool (idb/XCUITest) is available in this environment to drive the UI, only simctl."
  - id: D5
    description: "Every Phase 2 screen usable at AX3/AX5 Dynamic Type, including the carried Phase 1 radial-timer check"
    requirement: "ONBOARD-01"
    verification: []
    human_judgment: true
    rationale: "Visual clipping/overlap judgment across ~13 screens at two text sizes requires a human looking at rendered UI; no automated accessibility-snapshot tooling was available in this environment."

# Metrics
duration: 65min
completed: 2026-09-06
status: blocked
---

# Phase 2 Plan 16: Registry Race Fix, Phase 2 Coverage Gate, and Physical-Device Verification Checkpoint Summary

**Fixed the cross-suite StepRegistry test race via Swift Testing's real nesting-based serialization mechanism, added the Phase 2 placeholder-elimination coverage gate, curl-verified the Go service's contract on an alternate port -- and hit a genuine, unavoidable stopping point: three physical-device/UI verifications this environment cannot perform.**

## Performance

- **Duration:** 65 min
- **Started:** 2026-09-06T04:55:00Z (approx.)
- **Completed:** 2026-09-06 (Task 1 committed; Tasks 2-3 blocked)
- **Tasks:** 1 of 3 completed and committed; Tasks 2 and 3 blocked on a single combined checkpoint
- **Files modified:** 10 (Task 1)

## Accomplishments

- Diagnosed and fixed the pre-existing full-target `xcodebuild test` flake STATE.md's Blockers section had documented since 2026-09-01: `StepRegistry`'s shared static state races across concurrently-running Swift Testing suites. The fix nests every registry-touching suite (`AppShellTests`, `AboutYouStepTests`, `CalibrationSourceTests`, `PhaseCoverageTests`, `ScreeningFlowTests`, and the new `Phase2CoverageTests`) under one empty `@Suite(.serialized)` parent (`StepRegistryTouchingSuites`), which is Swift Testing's real cross-suite ordering mechanism -- `.serialized` recurses through a suite's entire nested subtree, unlike a per-suite trait which only orders tests within that one suite.
- Verified the fix over **ten consecutive full-target `xcodebuild test` runs**, all green, no run reporting a registered step as unregistered.
- Added `Phase2CoverageTests`, asserting each of the eight Phase 2 steps (`cardioActivityPicker` through `preAssessment`) resolves to the exact real presenter type its owning plan created, and that none of the eight is a placeholder type -- closing the gap plan 02-06's deliberate three-wave placeholder scaffolding left open.
- Confirmed via grep that no `Placeholder`-named type remains anywhere in `RithamApp/Ritham/` (all five per-area registrars are clean).
- Ran `RithamCore/Scripts/test-core.sh` (285 tests, 24 suites, exit 0) and `RithamService`'s `go test ./...` (exit 0) -- both green.
- Started the Go workout-plan service locally and curl-verified its full contract: all three `guidancePermission` tiers (`none`, `recommended`, `requiredBlocking`) produce well-formed, correctly-shaped responses, and stopping the service produces a connection failure at the transport layer (the shape `WorkoutPlanClient.fetchPlan` maps to `.transport`, which the UI renders as an error state with retry, never an empty/zero-session plan).
- Discovered and documented (not fixed, per this plan's own scope boundary) a separate, unrelated, low-frequency flake: `PersistenceTests.makeContext()` crashed once across seventeen total full-target runs performed during this verification, likely from concurrent SwiftData in-memory `ModelContainer` creation across three non-serialized suites. Recorded in STATE.md's Blockers/Concerns for a future pass.

## Task Commits

1. **Task 1: Serialize registry-touching suites and assert phase-wide step coverage** - `1b65149` (test)

**Tasks 2 and 3 are not committed** -- see Checkpoint below. This plan's metadata/SUMMARY commit will follow once this checkpoint response is written.

## Files Created/Modified

- `RithamApp/RithamTests/StepRegistrySerialization.swift` - new empty `@Suite("StepRegistryTouchingSuites", .serialized)` parent suite
- `RithamApp/RithamTests/Phase2CoverageTests.swift` - new suite asserting Phase 2's eight steps resolve to real, non-placeholder types
- `RithamApp/RithamTests/AppShellTests.swift`, `AboutYouStepTests.swift`, `CalibrationSourceTests.swift`, `PhaseCoverageTests.swift`, `ScreeningFlowTests.swift` - each re-declared inside `extension StepRegistryTouchingSuites { ... }` so Swift Testing nests them under the serialized parent
- `RithamApp/Ritham/App/StepRegistry.swift` - added a `presenterTypes` side-table and `registeredPresenterType(for:)`, so tests can assert the concrete presenter type per step (impossible to do reliably any other way against `AnyView`'s type erasure)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to pick up the two new test files
- `.planning/STATE.md` - Blockers section updated: the registry race is now recorded fixed (with the mechanism named), and a new entry records the separate `PersistenceTests` SwiftData flake found during verification

## Decisions Made

- Nesting-based cross-suite serialization (an empty `.serialized` parent suite, with member suites re-declared via `extension` in their own files) was chosen over the plan's stated fallback ("give each suite its own registry state") because it is Swift Testing's documented, real mechanism for cross-suite ordering, it required no change to any suite's own test bodies, and it worked on the first attempt (verified via both a targeted run and ten consecutive full-target runs).
- `StepRegistry.swift` was edited even though it's not in this plan's declared `files_modified` list (Rule 3 deviation): `Phase2CoverageTests`'s mandated assertion -- "asserts a resolved presenter type for each of the eight Phase 2 steps" -- cannot be written against `StepRegistry.view(for:flow:)`'s `AnyView` return, since `AnyView` erases the underlying type. The alternative (reflecting into `AnyView`'s private `storage`/`view` fields via `Mirror`) was considered and rejected: it depends on SwiftUI's undocumented internal layout and could silently break on a future SDK. A small, explicit side-table (`presenterTypes: [OnboardingStep: Any.Type]`, populated in `register`, cleared in `reset`) is the minimal, non-fragile alternative.
- The Go round-trip curl verification ran on port 8090, not the app's hardcoded Debug default of 8080, because port 8080 on this Mac is already bound by an unrelated long-running process (`sp-print`, a different project entirely, running for 12+ hours) that must not be killed. This proves the service's contract correctness but is explicitly **not** a substitute for Task 2's on-device "app actually renders the plan" / "app actually shows retry" verification, which is why that item remains in the checkpoint below rather than being marked discharged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `StepRegistry.registeredPresenterType(for:)`**
- **Found during:** Task 1
- **Issue:** `Phase2CoverageTests`'s mandated behavior assertion ("asserts a resolved presenter type for each of the eight Phase 2 steps ... and asserts none is a placeholder type") cannot be written against `StepRegistry.view(for:flow:)`'s `AnyView` return, which erases the concrete presenter type before returning it.
- **Fix:** Added a private `presenterTypes: [OnboardingStep: Any.Type]` side-table to `StepRegistry`, populated in `register(_:)` alongside the existing `factories` dictionary, cleared in `reset()`, and exposed via a new `registeredPresenterType(for:)` accessor.
- **Files modified:** `RithamApp/Ritham/App/StepRegistry.swift`
- **Verification:** `Phase2CoverageTests.eachPhase2StepResolvesToItsRealScreenType` and `.noPhase2StepResolvesToAPlaceholderType` both pass; ten consecutive full-target runs remain green.
- **Committed in:** `1b65149` (Task 1 commit)

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** Necessary for the plan's own mandated test assertion to be writable at all. No scope creep beyond that -- the change is additive, test-only in purpose, and does not alter `StepRegistry`'s existing production behavior (`factories`/`view(for:flow:)`/`unregisteredSteps` are all unchanged).

## Issues Encountered

- A ten-consecutive-run verification pass (the second of two performed) hit one crash unrelated to this plan's changes: `PersistenceTests.makeContext()` (an in-memory SwiftData `ModelContainer` creation) crashed the test host once, taking ~34 unrelated tests down with it as collateral (the host process dying mid-run, not individual assertion failures). Re-running the full ten-consecutive-run loop immediately afterward produced ten clean passes with zero failures, confirming this is a low-frequency (1 of 17 total runs observed), pre-existing, and separate flake from the StepRegistry race this plan fixes -- `PersistenceTests.swift`, `HealthDataStoreTests.swift`, and `EditAnswerFlowTests.swift` all create in-memory `ModelContainer`s without a `.serialized` trait, which is the likely mechanism. Per this plan's scope boundary (pre-existing, unrelated file, not caused by this plan's own changes), it was not fixed -- only documented, in `.planning/STATE.md`'s Blockers/Concerns section, for a future pass.
- Port 8080 (the app's hardcoded Debug `WorkoutPlanClient.defaultBaseURL`) was already bound by an unrelated process from a different project on this Mac (`sp-print`, 12+ hours uptime). Rather than killing another project's long-running server, the Go service was run on port 8090 instead and curl-verified directly against that port, which confirms the service's contract but not the app's literal hardcoded default endpoint.

## User Setup Required

None - no external service configuration required. (The Go service itself requires no setup beyond `go run ./cmd/ritham-service`, per `RithamService/README.md`.)

## Next Phase Readiness

Task 1 (the registry-race fix and Phase 2 coverage gate) is fully committed and independently verified -- Phase 2's own full-suite gate is now trustworthy. **Tasks 2 and 3 remain open**, blocked on the checkpoint below. Phase 2 cannot close until a human runs the physical-device and AX3/AX5 steps this environment structurally cannot perform, and returns to confirm or report findings.

---

## CHECKPOINT REACHED

**Type:** human-verify (combined: Task 2 + Task 3, both blocking gates)
**Plan:** 02-16
**Progress:** 1/3 tasks complete

### Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Serialize registry-touching suites and assert phase-wide step coverage | `1b65149` | StepRegistrySerialization.swift, Phase2CoverageTests.swift, 5 modified test suites, StepRegistry.swift, project.pbxproj, STATE.md |

### Current Task

**Tasks 2 and 3:** Physical-device sensor verification, the local Go round trip, and the AX3/AX5 accessibility pass (including the carried Phase 1 radial-timer check)
**Status:** blocked -- no physical iPhone is attached to this Mac, and no touch-injection tool (idb/XCUITest) is available to drive Simulator UI, only `simctl`
**Blocked by:** Real GPS movement, real motion-sensor walking, and visual clipping/overlap judgment across ~13 screens at two Dynamic Type sizes all require either a physical device or a human directly operating and looking at a running UI -- neither is available to an unattended agent in this environment.

### What was automated (do not re-verify these)

- **The Go service's contract itself** (not the on-device app): started `RithamService` locally (on port 8090, since 8080 was occupied by an unrelated project's long-running process on this Mac -- see Issues Encountered), and curl-verified:
  - `guidancePermission: "none"` -> full 7-day-capable plan shape, HTTP 200, well-formed JSON matching `WorkoutPlanResponse`
  - `guidancePermission: "recommended"` -> full plan with adjusted sets/reps and a caveated guidance note, HTTP 200
  - `guidancePermission: "requiredBlocking"` -> `frequencyPerWeek: 0`, `sessions: []`, and the referral guidance note, HTTP 200 (never an error -- this is the on-device-computed local-referral-plan shape mirrored server-side, matching `WorkoutPlanClient.localReferralPlan`)
  - Stopping the service and retrying -> `curl: (7) Failed to connect` (connection refused), which is exactly the transport-layer failure `WorkoutPlanClient.fetchPlan` maps to `WorkoutPlanClientError.transport`, which the UI is coded to render as an error state with retry, never an empty/zero-session plan (T-02-38)
- **Everything in Task 1's automated scope** (see Accomplishments above): the registry race fix, the Phase 2 coverage suite, ten consecutive clean full-target test runs, `RithamCore`'s test-core.sh, and `RithamService`'s `go test ./...`.

### What still needs a human on a physical device (Task 2's how-to-verify steps 1-10)

1. Build and install the app on a physical iPhone from Xcode. **Not done** -- no physical device attached to this Mac.
2. Finish onboarding to reach the hub, open cardio tracking, pick Walk, start a GPS-tracked session, grant location access. **Not done.**
3. Walk a route of known length (roughly 500m+). Confirm distance/pace/elevation update live, the position confidence indicator is visible and changes with signal quality, and displayed distance is within a reasonable margin of the route's real length. **Not done** -- needs a real GPS route and a real walk; record the route's real length and the app's displayed distance as two numbers.
4. Confirm the grade-adjusted pace row shows a real figure or is absent entirely -- never a placeholder glyph. **Not done.**
5. Finish the session; confirm it's labelled sensor-verified in cardio history. **Not done.**
6. Start a second session via manual stopwatch; confirm no location prompt, and its history row reads manually entered, distinguishable from step 5's row. **Not done.**
7. With no session running, walk/jog ~1 minute; confirm the auto-detect prompt appears and offers to log; dismiss it and confirm nothing was recorded. **Not done** -- needs real ambulatory motion; the underlying `MotionActivityDetector` unit-level offer-never-log behavior is already covered by `RithamCoreTests`, but the real-sensor trigger itself is untested.
8. On the Mac, run the Go service locally and confirm it logs a loopback listen address. **Partially done automatically** -- confirmed the service starts and logs `ritham-service listening on 127.0.0.1:<port>` (done on port 8090 here; the app's actual Debug build points at 8080, so re-run this on 8080 once `sp-print` isn't occupying it, or confirm the app can be pointed at 8090 for this check).
9. In a Debug build, open Recommendations, request a plan (completing/skipping the pre-assessment on first run); confirm a plan renders with sessions, focuses, exercises, and a guidance note. **Not done on-device** -- the service's response shape was curl-verified directly (see above) and matches what the app expects to decode, but the actual on-screen render was not observed.
10. Stop the Go service, request a plan again; confirm an error state with retry appears (not an empty/zero-session plan). **Not done on-device** -- the transport-layer failure was curl-verified (connection refused), which is the exact condition `WorkoutPlanClient` maps to its `.transport` error case, but the resulting UI screen was not observed.

### What still needs a human at AX3/AX5 (Task 3's how-to-verify steps 1-7)

1-3. Set Dynamic Type to AX3, walk every Phase 2 screen (hub, cardio picker, live cardio session, cardio history/route comparison, strength logging with plate calculator and supersets, strength history with year-jump and retroactive editing, guidance and its inline banners, Recommendations, pre-assessment, the two new Settings screens), confirm no clipping/unreachable controls/scroll failures; repeat at AX5. **Not done** -- requires visual judgment across ~13 screens at two sizes; no automated accessibility-snapshot tooling is available in this environment.
4. On the pre-assessment session screen specifically, at both AX3 and AX5, confirm the radial timer's elapsed-time label stays legible and uncropped inside the ring, with no overlap on surrounding text -- **this is the carried Phase 1 item** (`RadialSessionTimer`, built 2026-09-01, never previously verified at these sizes because its only host screen was unreachable until plan 02-13's pre-assessment screen). **Not done** -- still open, still carried forward.
5. On the guidance screen and both live session screens, confirm the persistent condition-disclaimer tag is present, expands on tap, and lists every matched condition. **Not done.**
6. Confirm the always-free list in Settings reads accurately against what's actually usable in steps 2-5. **Not done.**
7. Note any screen where a required-blocking referral message appeared, and confirm logging/timing/saving still worked there. **Not done.**

### Resume Signal

Type "approved" once all ten of Task 2's steps and all seven of Task 3's steps have been run on a physical device (Task 2) and at both AX3/AX5 (Task 3), with each step's outcome recorded -- or describe what differed at each numbered step so the affected work can be fixed and re-verified. Per-step pass/fail recording is required by this plan's own acceptance criteria; a bare "approved" without per-step detail does not satisfy them, but is sufficient to let this plan close if that per-step detail is supplied alongside it (e.g. "approved, steps 1-10 and Task-3 steps 1-7 all passed as described").
