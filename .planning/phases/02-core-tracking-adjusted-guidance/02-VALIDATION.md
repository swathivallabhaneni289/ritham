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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | STRENGTH-01 | — | N/A | unit | `RithamCore/Scripts/test-core.sh` (`ExerciseLogTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | STRENGTH-02 | — | Numeric inputs bounded to plausible positive ranges (V5) | unit | `RithamCore/Scripts/test-core.sh` (`PlateCalculatorTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | STRENGTH-03 | — | N/A | unit | `RithamCore/Scripts/test-core.sh` (`SupersetTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | STRENGTH-04 | — | N/A | unit | `RithamCore/Scripts/test-core.sh` (`MovementPatternTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | STRENGTH-05 | — | N/A | unit | `RithamCore/Scripts/test-core.sh` or app-target SwiftData test | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | HEALTH-03 | T-02-01 | `ContentPermission` enforced inside `GuidanceCatalog`, not view-level (V4) | unit | `RithamCore/Scripts/test-core.sh` (`GuidanceCatalogTests`, exhaustive-switch) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | HEALTH-04 | T-02-01 | Under-18 resolves `.educationOnly` (never `.full`) for weight-management content (V4) | unit | `RithamCore/Scripts/test-core.sh` (`GuidanceCatalogTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | DIET-02 | — | Renders nothing under `.requiredBlocking` | unit | `RithamCore/Scripts/test-core.sh` (`DietarySwapCatalogTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | DIET-03 | — | Renders identically regardless of condition tag/gate | unit | `RithamCore/Scripts/test-core.sh` (`DietarySwapCatalogTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | CARDIO-02 | — | GPS/motion sanity-bounded; implausible jumps discarded (V5) | unit | `RithamCore/Scripts/test-core.sh` (`GradeAdjustedPaceTests`) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | Go: workout-plan generation | T-02-02 | Only the pre-resolved `ClearanceGate` value crosses the API — never raw `ConditionTag`/SCOFF answers (D-07) | unit | `RithamService`: `go test ./internal/plan/...` (table-driven) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | Go: `POST /v1/workout-plan` handler | T-02-02 | Malformed/out-of-range request JSON rejected with 4xx, never a panic | unit | `RithamService`: `go test ./internal/httpapi/...` (`httptest`) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Task IDs filled in once the planner assigns them.*

---

## Wave 0 Requirements

- [ ] `RithamCoreTests/ExerciseLogTests.swift` — covers STRENGTH-01
- [ ] `RithamCoreTests/PlateCalculatorTests.swift` — covers STRENGTH-02
- [ ] `RithamCoreTests/SupersetTests.swift` — covers STRENGTH-03
- [ ] `RithamCoreTests/MovementPatternTests.swift` — covers STRENGTH-04
- [ ] `RithamCoreTests/GuidanceCatalogTests.swift` — covers HEALTH-03, HEALTH-04 (exhaustive-switch style, mirroring Phase 1's `GateResolutionTests`)
- [ ] `RithamCoreTests/DietarySwapCatalogTests.swift` — covers DIET-02, DIET-03
- [ ] `RithamCoreTests/GradeAdjustedPaceTests.swift` — covers CARDIO-02's confidence-gating behavior
- [ ] `RithamService/go.mod` + `RithamService/cmd/ritham-service/`, `internal/plan/`, `internal/httpapi/` scaffold — new Go module, no existing infrastructure to build on
- [ ] `RithamService/internal/plan/generate_test.go` — stubs for workout-plan generation logic
- [ ] `RithamService/internal/httpapi/handler_test.go` — stubs for the `POST /v1/workout-plan` handler

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
