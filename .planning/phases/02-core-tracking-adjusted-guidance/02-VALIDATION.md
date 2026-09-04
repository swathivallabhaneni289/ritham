---
phase: 02
slug: core-tracking-adjusted-guidance
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-04
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (Xcode 16+) for `RithamCore`/`RithamApp` — unchanged from Phase 1. Go standard `testing` package + `net/http/httptest` for the new `RithamService` Go backend (no third-party frameworks either side). |
| **Config file** | `RithamCore/Package.swift`, `RithamApp/project.yml` (both pre-existing, no new scaffold). `RithamService/go.mod` (new — created in Wave 0 for the Go backend). |
| **Quick run command** | Swift: `RithamCore/Scripts/test-core.sh`. Go: `go test ./...` from `RithamService/`. |
| **Full suite command** | Swift: `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17'`. Go: `go test ./...` from `RithamService/` (single small module — quick and full command are the same). |
| **Estimated runtime** | Swift core suite ~2-5s; Swift app suite ~30-60s (simulator boot dominates); Go suite <5s (no server binding needed, per httptest in-process pattern). |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the module just touched (`RithamCore/Scripts/test-core.sh` or app-target `-only-testing:` for Swift; `go test ./...` for Go).
- **After every plan wave:** Run the full Swift suite + full Go suite.
- **Before `/gsd-verify-work`:** Both suites must be green, plus one on-device manual pass for GPS/motion sensor paths (Simulator cannot validate these).
- **Max feedback latency:** ~60 seconds (Swift app-suite simulator boot is the long pole).

---

## Per-Task Verification Map

Filled in from the 16 plans the planner produced (2026-09-04) — supersedes the pre-planning
placeholder version of this table. Task-level IDs live inside each PLAN.md; this table maps at
plan granularity, which is what the sampling rate above actually runs against.

| Plan | Wave | Requirement(s) | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|------|------|----------------|------------|-----------------|-----------|--------------------|--------|
| 02-01 | 1 | CARDIO-01, CARDIO-02 | — | GPS/motion sanity-bounded; implausible jumps discarded (V5) | unit | `RithamCore/Scripts/test-core.sh` (`CardioSessionTests`, `GradeAdjustedPaceTests`) | ⬜ pending |
| 02-02 | 1 | STRENGTH-02, STRENGTH-04, MONETIZE-01 | — | Numeric inputs bounded to plausible positive ranges (V5) | unit | `RithamCore/Scripts/test-core.sh` (`PlateCalculatorTests`, `MovementPatternTests`) | ⬜ pending |
| 02-03 | 1 | STRENGTH-01, STRENGTH-03, STRENGTH-05 | — | N/A | unit | `RithamCore/Scripts/test-core.sh` (`LiftSessionTests`, `SupersetTests`, `SessionRevisionTests`) | ⬜ pending |
| 02-04 | 1 | HEALTH-03 | T-02-01 | `ContentPermission` enforced inside `GuidanceCatalog`, not view-level (V4) | unit | `RithamCore/Scripts/test-core.sh` (`GuidanceCatalogTests`, exhaustive-switch) | ⬜ pending |
| 02-05 | 1 | ONBOARD-01 | T-02-02 | Only the pre-resolved `ClearanceGate`/permission value crosses the API — never raw `ConditionTag`/SCOFF answers (D-07); malformed/out-of-range JSON rejected with 4xx, never a panic | unit | `RithamService`: `go test ./...` (`internal/plan/generate_test.go`, `internal/httpapi/handler_test.go`) | ⬜ pending |
| 02-06 | 1 | DIET-01 | — | Real navigation wires `DietPlanView` (already built in a prior session) into a reachable entry point — verify-only, not a re-implementation | unit + coverage | `RithamCore/Scripts/test-core.sh` (`OnboardingFlowStateTests`); app-target `-only-testing:RithamTests/HomeHubTests` | ⬜ pending |
| 02-07 | 2 | HEALTH-04, DIET-02, DIET-03 | T-02-01 | Under-18 resolves `.educationOnly` (never `.full`) for weight-management content (V4); DIET-02 renders nothing under `.requiredBlocking`; DIET-03 renders identically regardless of condition tag/gate | unit | `RithamCore/Scripts/test-core.sh` (`NutritionGuidanceCatalogTests`, `DietarySwapCatalogTests`) | ⬜ pending |
| 02-08 | 2 | CARDIO-01, CARDIO-03, STRENGTH-01, STRENGTH-05, ONBOARD-01, MONETIZE-01 | — | Persistence layer extends `HealthDataStore`'s existing facade pattern | unit | app-target `-only-testing:RithamTests/WorkoutStoreTests` | ⬜ pending |
| 02-09 | 2 | CARDIO-01, CARDIO-02, CROSSGEN-02 | — | Auto-detect surfaces a confirmation prompt only while the app is open — no silent background logging (Claude's Discretion default) | unit | app-target `-only-testing:RithamTests/CardioCaptureTests` | ⬜ pending |
| 02-10 | 3 | CARDIO-01, CARDIO-02, CARDIO-03, CROSSGEN-02 | — | Route/segment comparison stays single-user opt-in, defaulting off (planner discretion, bounded by PROJECT.md's no-heatmap prohibition) | unit + UI | app-target `-only-testing:RithamTests/CardioViewTests` | ⬜ pending |
| 02-11 | 3 | STRENGTH-01, STRENGTH-02, STRENGTH-03, STRENGTH-04 | — | N/A | unit + UI | app-target `-only-testing:RithamTests/StrengthLoggingTests` | ⬜ pending |
| 02-12 | 4 | HEALTH-03, HEALTH-04, DIET-02, DIET-03 | T-02-01 | Reuses Phase 1's disclaimer-tag pattern (`ConditionDisclaimerTag`, `RequiredBlockingMessageView`) rather than a new UI pattern (Claude's Discretion) | unit + UI | app-target `-only-testing:RithamTests/GuidanceViewTests` | ⬜ pending |
| 02-13 | 3 | ONBOARD-01 | T-02-02 | Recommendations surface + pre-assessment call the Go client (`WorkoutPlanClient`), never bypass it to send raw health data | unit + UI | app-target `-only-testing:RithamTests/RecommendationsTests` | ⬜ pending |
| 02-14 | 3 | MONETIZE-01 | — | "Always free" list names only shipped capabilities; heart-rate-display omission recorded in source (no wearable pairing this phase) | unit + UI | app-target `-only-testing:RithamTests/SettingsPhase2Tests` | ⬜ pending |
| 02-15 | 4 | STRENGTH-04, STRENGTH-05 | — | `LiftSet` retains stable identity across session merge/split | unit + UI | app-target `-only-testing:RithamTests/StrengthHistoryTests` | ⬜ pending |
| 02-16 | 5 | CARDIO-02, CROSSGEN-02, ONBOARD-01 | T-02-01, T-02-02 | Registry-race fix; full-suite coverage assertions; Go round-trip + on-device GPS/motion + AX3/AX5 manual checkpoints | coverage + manual | app-target `-only-testing:RithamTests/Phase2CoverageTests`; manual passes below | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Updated during execution, not at plan time.*

---

## Wave 0 Requirements

Corrected against the actual plan output (2026-09-04) — `LiftSessionTests.swift` replaces the
placeholder `ExerciseLogTests.swift` name; every other new suite the 16 plans introduce is listed.

**RithamCore (`RithamCore/Tests/RithamCoreTests/`):**
- [ ] `LiftSessionTests.swift` — covers STRENGTH-01 (02-03)
- [ ] `PlateCalculatorTests.swift` — covers STRENGTH-02, plus `OneRepMaxCalculatorTests` suite extension (02-02, 02-11)
- [ ] `SupersetTests.swift` — covers STRENGTH-03 (02-03)
- [ ] `MovementPatternTests.swift` — covers STRENGTH-04 (02-02)
- [ ] `SessionRevisionTests.swift` — covers STRENGTH-05 (02-03)
- [ ] `GuidanceCatalogTests.swift` — covers HEALTH-03, plus `WorkoutGuidanceCatalogTests` suite extension (02-04, 02-12), exhaustive-switch style mirroring Phase 1's `GateResolutionTests`
- [ ] `NutritionGuidanceCatalogTests.swift` — covers HEALTH-04 (02-07)
- [ ] `DietarySwapCatalogTests.swift` — covers DIET-02, DIET-03 (02-07)
- [ ] `CardioSessionTests.swift`, `CardioTrackAccumulatorTests.swift`, `GradeAdjustedPaceTests.swift` — cover CARDIO-01/02's confidence-gating behavior (02-01)
- [ ] `OnboardingFlowStateTests.swift` — extended (not new) for the nav-hub routing change (02-06)

**RithamApp (`RithamApp/RithamTests/`):**
- [ ] `CardioCaptureTests.swift`, `CardioViewTests.swift` — CROSSGEN-02, CARDIO-03 (02-09, 02-10)
- [ ] `StrengthLoggingTests.swift`, `StrengthHistoryTests.swift` — STRENGTH UI + retroactive edit/merge/split (02-11, 02-15)
- [ ] `GuidanceViewTests.swift` — inline guidance surfacing (02-12)
- [ ] `RecommendationsTests.swift` — ONBOARD-01's Go-client + pre-assessment UI (02-13)
- [ ] `SettingsPhase2Tests.swift` — MONETIZE-01's "always free" list + frequency preference (02-14)
- [ ] `WorkoutStoreTests.swift`, `WorkoutPreferenceTests.swift` — persistence layer (02-08)
- [ ] `HomeHubTests.swift` — the interim navigation hub (02-06)
- [ ] `Phase2CoverageTests.swift` — phase-wide coverage assertions (02-16)

**RithamService (Go — entirely new, no existing infrastructure to build on):**
- [ ] `RithamService/go.mod` + `cmd/ritham-service/`, `internal/plan/`, `internal/httpapi/` scaffold (02-05)
- [ ] `RithamService/internal/plan/generate_test.go` — workout-plan generation logic, table-driven (02-05)
- [ ] `RithamService/internal/httpapi/handler_test.go` — `POST /v1/workout-plan` handler via `httptest` (02-05)

*(Xcode scheme/destination already confirmed in research — see Test Framework table above; no Wave 0 action needed for that item. Go toolchain confirmed installed locally, Go 1.26.4.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| GPS pace/distance/elevation accuracy in real-world conditions | CARDIO-02 | Simulator cannot produce real GPS/motion sensor data | On a physical device: start a tracked walk/run, compare displayed pace/distance against a known route or reference app |
| CoreMotion auto-detect walk/run classification | CROSSGEN-02 | Simulator cannot produce real motion-sensor data | On a physical device: walk/run without manually starting a session, confirm the auto-detect prompt appears within the expected ramp-up window |
| iOS client ↔ local Go backend round-trip during development | Go backend (D-06) | Cross-process integration, not unit-testable in isolation | Run `go run ./cmd/ritham-service` locally, point a Debug build at `http://localhost:8080`, request a plan from the Recommendations surface, confirm a valid plan renders |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (Swift + Go)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
