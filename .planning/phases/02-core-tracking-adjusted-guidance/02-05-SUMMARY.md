---
phase: 02-core-tracking-adjusted-guidance
plan: 05
subsystem: api
tags: [go, net/http, stdlib-only, json, workout-plan]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake
    provides: "ClearanceGate/GateResolutionResult (RithamCore) -- the three-value guidancePermission signal this service consumes"
provides:
  - "RithamService/, the repo's first Go module: a dependency-free go.mod, a pure plan.Generate function, and one HTTP endpoint"
  - "POST /v1/workout-plan contract (frequencyPerWeek/experienceLevel/guidancePermission in, a plan object out), enforced by a reflection test"
affects: [02-13 (iOS WorkoutPlanClient calling this endpoint)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Go stdlib-only backend: net/http + Go 1.22+ enhanced ServeMux, no third-party router/framework"
    - "cmd/ + internal/ layout, no /pkg (nothing outside this repo imports the module)"
    - "internal/plan (pure logic, no HTTP import) kept separate from internal/httpapi (decode/generate/encode)"
    - "Reflection-asserted request-contract shape as an enforceable data-minimization gate (D-07)"

key-files:
  created:
    - RithamService/go.mod
    - RithamService/README.md
    - RithamService/cmd/ritham-service/main.go
    - RithamService/internal/plan/generate.go
    - RithamService/internal/plan/generate_test.go
    - RithamService/internal/httpapi/contract.go
    - RithamService/internal/httpapi/handler.go
    - RithamService/internal/httpapi/handler_test.go
  modified:
    - .gitignore

key-decisions:
  - "requiredBlocking zeroes FrequencyPerWeek too, not just Sessions -- the action text says 'no numeric field populated anywhere in the returned structure,' a stricter reading than the acceptance criteria's own zero-sessions-and-non-empty-note check"
  - "Added a third sentinel error (ErrUnknownGuidancePermission) for an unrecognized guidancePermission value, failing closed rather than silently defaulting to a full plan -- the plan only specified sentinels for frequency and experience level"
  - "Added explicit JSON tags to plan.Plan/Session/Exercise (not scoped to Task 1's pure-logic behavior) so the response actually serializes per the documented wire shape once Task 2 wraps it in WorkoutPlanResponse"

patterns-established:
  - "TDD RED via a compiling stub (Generate/handler returning a zero value or 200-always) so RED is a genuine assertion failure, not a build error"

requirements-completed: [ONBOARD-01]

coverage:
  - id: D1
    description: "plan.Generate returns the correct session count for each supported weekly frequency (3/5/7) and a sentinel error for any other frequency"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_SessionCountMatchesFrequency"
        status: pass
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_UnsupportedFrequencyReturnsError"
        status: pass
    human_judgment: false
  - id: D2
    description: "plan.Generate rejects an unknown experience bucket and an unknown guidance permission with distinct sentinel errors"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_UnknownExperienceLevelReturnsError"
        status: pass
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_UnknownGuidancePermissionReturnsError"
        status: pass
    human_judgment: false
  - id: D3
    description: "Guidance-permission tiers behave correctly: full prescriptions at none, prescriptions plus a consultation note at recommended, zero sessions/zero numeric fields plus a referral note at requiredBlocking (HEALTH-03 parity)"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_LeastRestrictivePermissionCarriesPrescriptions"
        status: pass
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_MiddlePermissionCarriesPrescriptionsAndConsultationNote"
        status: pass
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_MostRestrictivePermissionCarriesNoNumericPrescriptions"
        status: pass
    human_judgment: false
  - id: D4
    description: "Session focus areas vary across the week at every supported frequency, and volume scales by experience bucket (fewer sets/higher reps for beginner)"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_FocusAreasVaryAcrossTheWeek"
        status: pass
      - kind: unit
        ref: "RithamService/internal/plan/generate_test.go#TestGenerate_ExperienceLevelScalesVolume"
        status: pass
    human_judgment: false
  - id: D5
    description: "WorkoutPlanRequest has exactly three fields tagged frequencyPerWeek/experienceLevel/guidancePermission (D-07 boundary), asserted by reflection and by literal marshaled-byte inspection, and round-trips"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestWorkoutPlanRequest_ShapeIsExactlyThreeMinimizedFields"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestWorkoutPlanRequest_MarshaledFieldNamesMatchWireContract"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestWorkoutPlanRequest_RoundTrips"
        status: pass
    human_judgment: false
  - id: D6
    description: "POST /v1/workout-plan returns 200 with a plan key for a valid request, 400 for invalid JSON/string-typed frequency/unsupported frequency/unknown experience level/an unexpected field, and 405 for GET -- never a panic"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_ValidRequestReturns200WithPlanKey"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_InvalidJSONReturns400"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_StringFrequencyReturns400"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_UnsupportedFrequencyReturns400"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_UnknownExperienceLevelReturns400"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_UnknownFieldReturns400"
        status: pass
      - kind: unit
        ref: "RithamService/internal/httpapi/handler_test.go#TestHandleWorkoutPlan_GETReturns405"
        status: pass
    human_judgment: false
  - id: D7
    description: "The server binds to 127.0.0.1 only, with explicit read/write/idle timeouts, and a real POST /v1/workout-plan against a running instance returns 200 with a full plan body"
    requirement: ONBOARD-01
    verification:
      - kind: manual_procedural
        ref: "cd RithamService && PORT=9091 go run ./cmd/ritham-service, then curl -X POST http://127.0.0.1:9091/v1/workout-plan -- returned 200 with a full 3-session plan body this session"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 5: RithamService Go Backend Summary

**RithamService: a dependency-free Go module (`net/http` stdlib only) exposing `POST /v1/workout-plan`, which turns a weekly frequency, an experience bucket, and a three-value clearance-gate signal into a scaled workout plan -- or, under the most restrictive permission, zero sessions and a referral note.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-09-05T09:34:00Z (approx.)
- **Completed:** 2026-09-05T09:48:14Z
- **Tasks:** 3 completed
- **Files modified:** 9 (8 created, 1 modified)

## Accomplishments

- Scaffolded `RithamService/` as a sibling of `RithamApp/`/`RithamCore/` with a `go.mod` carrying no `require` block -- the repo's first Go code, matching the Swift side's zero-third-party-dependency discipline.
- Built `internal/plan.Generate`, a pure function (no `net/http` import) that scales exercise volume by a four-bucket experience level, rotates session focus across a fixed 7-entry list so no supported frequency (3/5/7) repeats a focus, and honors three guidance-permission tiers matching HEALTH-03's existing general/consultation/referral semantics.
- Built `internal/httpapi`'s `WorkoutPlanRequest`/`WorkoutPlanResponse` contract and the `POST /v1/workout-plan` handler: a three-field request enforced by a reflection test (D-07's minimized data boundary), a 64 KiB body cap plus `DisallowUnknownFields` (D-07 enforcement, not just documentation), and a decode/generate/encode pipeline where each step maps its own failure to 400 or 500.
- Wired a loopback-bound (`127.0.0.1`) entrypoint with explicit 5s/10s/60s read/write/idle timeouts; verified live against a running instance (`PORT=9091 go run ./cmd/ritham-service`) that a valid POST returns 200 with a full plan body.

## Task Commits

Each task followed the plan's `tdd="true"` RED/GREEN cycle where specified:

1. **Task 1: Go module scaffold and the pure plan-generation function**
   - `12ac766` (chore): scaffold go.mod, README.md, .gitignore entry
   - `6b66695` (test): failing tests for `plan.Generate` (RED -- stub returns zero-value `Plan`)
   - `462be54` (feat): full `plan.Generate` implementation (GREEN)
2. **Task 2: HTTP contract and handler for POST /v1/workout-plan**
   - `81341de` (test): `contract.go` + JSON tags on `plan.Plan`/`Session`/`Exercise` + failing handler tests (RED -- handler stub always returns 200)
   - `9ef5e67` (feat): full handler implementation (GREEN)
3. **Task 3: Loopback-bound entrypoint**
   - `e03cbff` (feat): `cmd/ritham-service/main.go`

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `RithamService/go.mod` - module `github.com/swathivallabhaneni289/ritham/RithamService`, no `require` block
- `RithamService/README.md` - local run/test instructions, first-pass scope note
- `RithamService/internal/plan/generate.go` - `ExperienceLevel`, `GuidancePermission`, `Exercise`, `Session`, `Plan`, `Generate`, three sentinel errors
- `RithamService/internal/plan/generate_test.go` - table-driven tests covering every behavior bullet
- `RithamService/internal/httpapi/contract.go` - `WorkoutPlanRequest`/`WorkoutPlanResponse`, D-07 boundary comment
- `RithamService/internal/httpapi/handler.go` - `NewMux()`, `POST /v1/workout-plan` handler
- `RithamService/internal/httpapi/handler_test.go` - reflection, round-trip, and status-code tests
- `RithamService/cmd/ritham-service/main.go` - loopback-bound `http.Server` with explicit timeouts
- `.gitignore` - build-output-only entries for the compiled binary (source stays tracked)

## Decisions Made

- **requiredBlocking zeroes `FrequencyPerWeek` too, not just `Sessions`.** The task's action text says "no numeric field populated anywhere in the returned structure," a stricter reading than the acceptance criteria's own "zero sessions and a non-empty guidance note" check. Applied the stricter reading and added a direct test assertion for it (`TestGenerate_MostRestrictivePermissionCarriesNoNumericPrescriptions`). No consumer exists yet (02-13 is unbuilt), so this costs nothing and closes a real gap between the acceptance criteria and the action text.
- **Added `ErrUnknownGuidancePermission`, a third sentinel error not named in the plan's action text** (which only specifies sentinels for frequency and experience level). An unrecognized `guidancePermission` string now fails closed with 400 rather than silently falling through to a full plan -- the wrong failure mode for a health-adjacent gate. Covered by its own test and mapped to 400 in the handler.
- **Added explicit JSON tags to `plan.Plan`/`Session`/`Exercise`**, technically outside Task 1's pure-logic behavior scope, because Task 2's response contract wraps `plan.Plan` directly and the response would not serialize per the documented wire shape (`frequencyPerWeek`/`sessions`/`guidanceNote`, etc.) without them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - missing critical functionality] Added a third sentinel error for an unrecognized `guidancePermission`**
- **Found during:** Task 1 (`plan.Generate`)
- **Issue:** The plan's action text names sentinel errors only for invalid frequency and unknown experience level; an unrecognized guidance-permission string had no defined failure path, which would have defaulted to the `switch` statement's fall-through behavior for a health-adjacent gate.
- **Fix:** Added `ErrUnknownGuidancePermission`, a `default` case in `Generate`'s permission switch, and a test asserting it fires and maps to 400 in the handler.
- **Files modified:** `RithamService/internal/plan/generate.go`, `RithamService/internal/plan/generate_test.go`
- **Verification:** `TestGenerate_UnknownGuidancePermissionReturnsError` passes; handler-level 400 mapping verified via `statusForGenerateError`.
- **Committed in:** `6b66695` (test), `462be54` (feat)

**2. [Rule 1 - bug] Added JSON tags to `plan.Plan`/`Session`/`Exercise`**
- **Found during:** Task 2 (writing `httpapi.WorkoutPlanResponse`, which wraps `plan.Plan`)
- **Issue:** Without explicit tags, `encoding/json` would have serialized the response using Go's capitalized field names (`FrequencyPerWeek`, `RepRange`, etc.) instead of the documented camelCase wire shape from 02-RESEARCH.md §3, breaking the contract the Swift client (plan 02-13) is specified to match character for character.
- **Fix:** Added `json:"..."` tags matching the researched response shape to all three types.
- **Files modified:** `RithamService/internal/plan/generate.go`
- **Verification:** `TestHandleWorkoutPlan_ValidRequestReturns200WithPlanKey` confirms the top-level `plan` key; manual curl verification in Task 3 confirms the full nested shape (`frequencyPerWeek`, `sessions[].dayIndex/focus/exercises[].name/sets/repRange`, `guidanceNote`).
- **Committed in:** `81341de` (test)

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2)
**Impact on plan:** Both deviations were necessary for correctness (the response contract literally would not serialize per spec without #2) and for closing a fail-closed gap on a health-adjacent gate (#1). No scope creep -- no framework, no new endpoints, no infrastructure added beyond what the plan specified.

## Issues Encountered

None. `go vet`, `go build`, and `go test ./...` were clean on every run; no dependency, tooling, or environment issues.

## User Setup Required

None - no external service configuration required. `RithamService` runs entirely locally via `go run ./cmd/ritham-service`.

## Requirements Note

`requirements-completed: [ONBOARD-01]` above lists this plan's frontmatter `requirements` field
for traceability, but ONBOARD-01 is **not** marked complete in `REQUIREMENTS.md` -- per
02-VALIDATION.md's Per-Task Verification Map, ONBOARD-01 spans four plans in this phase
(02-05, 02-08, 02-13, 02-16), and the triggered pre-assessment entry point that ONBOARD-01
actually describes ("the first time a user requests exercise recommendations...") isn't built
until 02-13 wires the iOS `WorkoutPlanClient` to a real trigger. Checking the requirement off now
would be premature; it stays unchecked until the plan that completes the user-facing behavior.

## Next Phase Readiness

- `POST /v1/workout-plan` is live and tested; plan 02-13 (the iOS `WorkoutPlanClient`) can now be built against this exact contract (`frequencyPerWeek`/`experienceLevel`/`guidancePermission` in, `plan` object out, exact field spellings verbatim in this SUMMARY and in `internal/httpapi/contract.go`).
- No blockers. The absent-auth gap is documented in `main.go`'s header comment and the README as a prerequisite for any real hosting decision, not something plan 02-13 needs to solve -- Simulator debug builds talk to `127.0.0.1` directly.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 9 created/modified files verified present on disk. All 6 task commit hashes
(`12ac766`, `6b66695`, `462be54`, `81341de`, `9ef5e67`, `e03cbff`) verified present in
`git log --oneline --all`.
