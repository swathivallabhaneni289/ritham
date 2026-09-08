---
phase: 04-household-home
plan: 03
subsystem: testing
tags: [swift-testing, xcodebuild, structural-gate, step-registry, dashboard]

# Dependency graph
requires:
  - phase: 04-household-home
    provides: HomeHubView as a sectioned dashboard (04-02), embeddable Recommendations/diet content and the DIET-01 isolation gate (04-01)
provides:
  - Phase4CoverageTests, an 11-test structural gate covering registry completeness, the Momentum dashboard section's on-disk location, the dashboard's inline-not-navigational shape, forbidden layout/typography primitives, the Settings screening-question route, and Home-directory no-sharing coverage
  - Proof (via a recorded negative control) that Phase3CoverageTests' no-sharing directory walk was silently vacuous for a relocated Momentum dashboard section, and that Phase4CoverageTests test 4 closes that gap
  - A green full-repository automated test surface (RithamTests + RithamCore) and a successful app build
  - ROADMAP.md/REQUIREMENTS.md updated to record CROSSGEN-01 as delivered by Phase 4 round 1, with HOUSEHOLD-01/CROSSGEN-04 still open
  - A named, still-open gap: Task 3's Simulator click-through by a human has not run
affects: [phase-4-close-out, 04-VALIDATION.md if one exists, any future plan touching HomeHubView.swift or the Momentum/Home directories]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-phase structural coverage suite (Phase4CoverageTests) nested inside StepRegistryTouchingSuites, following the Phase2CoverageTests/Phase3CoverageTests precedent -- source-scans HomeHubView.swift's comment-filtered text for both required inline-section symbols and banned layout/typography tokens, so a future edit that violates D-01's dashboard shape fails a test instead of only a design review."

key-files:
  created:
    - RithamApp/RithamTests/Phase4CoverageTests.swift
  modified:
    - RithamApp/Ritham.xcodeproj/project.pbxproj
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "Test 1 (`.home` registry resolution) asserts against the real registered type, `HomeStepView.self` (an OnboardingStepPresenting shim that constructs HomeHubView), not `HomeHubView.self` as the plan's literal text specified -- StepRegistry registers presenter shims, not the destination view types directly, matching the existing `.screeningComplete`/`ScreeningCompleteStepView` indirection. The must_haves truth ('.home resolves to HomeHubView') is separately proven by source-scanning HomeStepView.swift for the literal `HomeHubView(` construction call. Documented in the test's own doc comment as a Rule 1 correction to the plan text."
  - "No-sharing coverage for Ritham/Home/ was added as a new test inside Phase4CoverageTests rather than by editing Phase3CoverageTests.swift to widen its directory walk, per 04-RESEARCH.md's assumption A2 (don't touch Phase 3's own coverage file) and the plan's explicit instruction."

requirements-completed: [CROSSGEN-01]

coverage:
  - id: D1
    description: "Phase4CoverageTests (11 tests) gates registry completeness (.home/.recommendations resolution, zero unregistered steps), the Momentum dashboard section's on-disk location, the dashboard's inline-section shape (no List/Form, no sub-label typography, no second navigation container, no placeholder framing), the Settings route to the food-allergy screening question, and Home-directory no-sharing coverage"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/Phase4CoverageTests (11 tests, 2 suites, all pass)"
        status: pass
      - kind: integration
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/PhaseCoverageTests -only-testing:RithamTests/StepRegistryTouchingSuites/Phase2CoverageTests -only-testing:RithamTests/StepRegistryTouchingSuites/Phase3CoverageTests (17 tests, 4 suites, all pass -- confirms the enlarged StepRegistryTouchingSuites subtree stays stable)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both required negative controls (relocating MomentumDashboardSection.swift out of Ritham/Momentum/Components/; deleting the DietPlanSectionContent reference from HomeHubView.swift) were run by hand, confirmed to fail the intended test, and reverted"
    requirement: "CROSSGEN-01"
    verification:
      - kind: manual_procedural
        ref: "Run by the prior (interrupted) executor session before this session began; results recorded below in Issues Encountered / Deviations. This session did not re-run the negative controls per the recovery instruction not to repeat them."
        status: pass
    human_judgment: true
    rationale: "The negative-control runs themselves happened in a prior, now-terminated session; this session verified their resulting artifact (Phase4CoverageTests.swift, green with no negative control active) but did not re-witness the fail/revert cycle first-hand, so it is recorded as human-attested rather than a fresh automated pass in this session."
  - id: D3
    description: "Full repository automated test surface is green: Scripts/build-app.sh test (RithamTests, full target), RithamCore/Scripts/test-core.sh, and Scripts/build-app.sh build"
    requirement: "CROSSGEN-01"
    verification:
      - kind: integration
        ref: "Scripts/build-app.sh test (412 tests, 51 suites, all pass, PersistenceTests.makeContext() flake did not appear)"
        status: pass
      - kind: unit
        ref: "RithamCore/Scripts/test-core.sh (396 tests, 30 suites, all pass)"
        status: pass
      - kind: other
        ref: "Scripts/build-app.sh build"
        status: pass
    human_judgment: false
  - id: D4
    description: "A human has seen the dashboard render in the Simulator (Task 3) and confirmed it is the screen the product owner asked for, walking all 10 verification steps in 04-03-PLAN.md"
    requirement: "CROSSGEN-01"
    verification: []
    human_judgment: true
    rationale: "Task 3 is an explicit checkpoint:human-verify, gate=\"blocking\" task requiring a person to tap through the running app in the iOS Simulator (log a sleep check-in, change pickers, force-quit and relaunch, compare against saved state). No touch-injection tool is available in this environment to automate that click-through; this executor did not attempt it, per its own instructions."

# Metrics
duration: 25min (this session; Task 1's own authoring/negative-control work happened in a prior, interrupted session)
completed: 2026-09-08
status: blocked
---

# Phase 4 Plan 03: Structural Coverage Gates and Full-Suite Green (Task 3 Pending) Summary

**`Phase4CoverageTests` (11 tests) makes CROSSGEN-01's dashboard shape, the Momentum section's file location, and the Settings screening-route survival into automated gates; the full RithamTests + RithamCore surface is green and the app builds; ROADMAP.md/REQUIREMENTS.md now record CROSSGEN-01 as delivered. The plan's Task 3 (a human Simulator click-through) is a blocking checkpoint this executor could not and did not attempt.**

## Performance

- **Duration:** ~25 min this session (resumed after a prior executor run completed Task 1's authoring and negative controls, then stalled and was terminated; the orchestrator restored the working tree to a clean state before this session began)
- **Started:** 2026-09-08 (this session)
- **Completed:** 2026-09-08 (Tasks 1-2 committed; Task 3 blocked)
- **Tasks:** 2 of 3 completed and committed; Task 3 is a blocking human-verify checkpoint, not attempted
- **Files modified:** 2 (Task 1: new test file + regenerated project.pbxproj) + 2 (Task 2: ROADMAP.md + REQUIREMENTS.md)

## Accomplishments

- Verified `RithamApp/RithamTests/Phase4CoverageTests.swift` (created and negative-control-verified by the prior session) is complete, correctly nested inside `extension StepRegistryTouchingSuites`, and green: `Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/Phase4CoverageTests` reports **11 tests passed**, matching the plan's acceptance criterion ("at least 11 tests," count read from the Swift Testing summary, not just exit code).
- Ran the four-suite regression check (`PhaseCoverageTests`, `Phase2CoverageTests`, `Phase3CoverageTests` alongside `Phase4CoverageTests`) — **17 tests, 4 suites, all pass** — confirming the newly-enlarged `StepRegistryTouchingSuites` serialized subtree is still stable with a fourth registry-touching member.
- Committed Task 1's deliverable (the test file was already authored and negative-control-verified by the interrupted prior session; this session confirmed the green state and made the task commit, since the prior session's work had not yet been committed to git).
- Ran the full automated test surface: `Scripts/build-app.sh test` (full `RithamTests` target) — **412 tests, 51 suites, all pass**, with no occurrence of the pre-existing `PersistenceTests.makeContext()` SwiftData flake documented in STATE.md's Blockers/Concerns. `RithamCore/Scripts/test-core.sh` — **396 tests, 30 suites, all pass**. `Scripts/build-app.sh build` — **BUILD SUCCEEDED**.
- Updated `.planning/ROADMAP.md` with scoped, additive edits: Phase 4's `**Plans**` line now reads `3/3 plans complete`, all three plan checkboxes ticked, the Progress table's Phase 4 row updated to `3/3 | In Progress (round 1 complete)`, both existing dated 2026-09-08 annotations left byte-for-byte unchanged, and a new dated note added recording that round 1 shipped CROSSGEN-01's dashboard while HOUSEHOLD-01/CROSSGEN-04 remain open — mirroring Phase 2 criterion 6's and Phase 3 criterion 5's existing annotation style. The Phase 4 entry in the top-level phase list stays unticked, as instructed, since criteria 2 and 3 are still deferred.
- Updated `.planning/REQUIREMENTS.md`: `CROSSGEN-01` checkbox ticked and its row in the requirement/phase status table set to `Complete`; `HOUSEHOLD-01` and `CROSSGEN-04` left `Pending`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Phase4CoverageTests — CROSSGEN-01's structural gates** - `300a184` (test)
2. **Task 2: Full-suite green and roadmap/requirements status update** - `080857b` (docs)

**Task 3 is not committed** — see Checkpoint below. This plan's own metadata/SUMMARY commit follows this file.

_Note: this session performed no TDD red/green cycle; Task 1's test-writing and negative-control verification had already happened in the prior, interrupted session before this session began. This session's Task 1 commit captures that already-completed, already-verified work._

## Files Created/Modified

- `RithamApp/RithamTests/Phase4CoverageTests.swift` - new suite, nested in `StepRegistryTouchingSuites`, 11 tests covering registry completeness, Momentum-directory non-vacuity, dashboard inline-section shape, Settings-route survival, and Home-directory no-sharing
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new test file
- `.planning/ROADMAP.md` - Phase 4 at 3/3 plans complete, all three plan lines ticked, Progress table updated, new dated round-1-shipped annotation added, existing annotations preserved verbatim
- `.planning/REQUIREMENTS.md` - `CROSSGEN-01` ticked and Complete; `HOUSEHOLD-01`/`CROSSGEN-04` still Pending

## Decisions Made

- Test 1 (`theHomeStepResolvesToTheDashboardScreen`) asserts `StepRegistry.registeredPresenterType(for: .home) == HomeStepView.self`, not `HomeHubView.self` as the plan's literal action text specified — the registry holds presenter shims (`OnboardingStepPresenting` conformers whose `makeView(flow:)` constructs the real screen), matching the pre-existing `.screeningComplete`/`ScreeningCompleteStepView` pattern. The test separately source-scans `HomeStepView.swift` for the literal `HomeHubView(` construction to prove the must_haves truth ("`.home` resolves to `HomeHubView`") without asserting a type equality that would fail against the real registry shape. This is a Rule 1 correction to the plan text, documented inline in the test file's own doc comment by the authoring (prior) session.
- Home-directory no-sharing coverage (`noHomeSurfaceOffersASharingAffordance`) was added as its own new test inside `Phase4CoverageTests`, not by widening `Phase3CoverageTests.swift`'s existing directory walk — per 04-RESEARCH.md's assumption A2 and the plan's explicit instruction not to touch Phase 3's own coverage file.
- Requirements-completed for this SUMMARY includes `CROSSGEN-01`, matching the plan's own Task 2 instruction to tick it in REQUIREMENTS.md on the strength of the automated structural gates and full-suite green — Task 3's human Simulator walkthrough is treated as a final confirming QA pass on already-delivered, already-gated functionality, not as a precondition for the requirement's own completion mark. If Task 3 surfaces a real defect, the plan's own instructions call for fixing it and re-presenting, which would not retroactively un-tick the requirement but would need a follow-up fix commit.

## Deviations from Plan

None beyond the one documented above (Rule 1 correction to the plan's literal `.home`/`HomeHubView.self` assertion, made and recorded by the prior authoring session, verified unchanged by this session).

## Issues Encountered

- This plan's execution was split across two sessions: a prior session completed Task 1's test authoring and ran both required negative controls (moving `MomentumDashboardSection.swift` to `Ritham/Home/`, confirming it failed test 4 while `Phase3CoverageTests` stayed green — the exact non-vacuity proof test 4 exists for; and deleting the `DietPlanSectionContent` reference from `HomeHubView.swift`, confirming it failed test 5), then reverted both changes and stalled before committing. The orchestrator restored the working tree to a clean, correct state (confirmed via `git diff` showing zero diff on `HomeHubView.swift` against the last commit) before this session began. This session independently re-verified the resulting `Phase4CoverageTests.swift` is complete and green with no negative control active, then made the Task 1 commit — it did not re-run the negative controls itself, per the recovery instruction to avoid repeating them and risking another stall.
- No new occurrence of the pre-existing `PersistenceTests.makeContext()` SwiftData `ModelContainer` flake (STATE.md Blockers/Concerns, ~1-in-17 full-target runs) was observed during this session's full-suite run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Tasks 1 and 2 are fully committed and independently re-verified in this session: `Phase4CoverageTests` is a real, green, negative-control-proven structural gate; the entire automated surface (`RithamTests` full target, `RithamCore`, and the app build) is green; and `ROADMAP.md`/`REQUIREMENTS.md` correctly record `CROSSGEN-01` as delivered by Phase 4 round 1 while `HOUSEHOLD-01`/`CROSSGEN-04` remain open for a later round — the Phase 4 top-level checkbox is correctly left unticked.

**Task 3 remains open** — a blocking `checkpoint:human-verify` requiring a person to build and run the app in the iOS Simulator, complete or re-enter onboarding, and walk all 10 verification steps in `04-03-PLAN.md` (confirm the sectioned-card layout, no placeholder framing, sleep-card stability across a check-in, workout-plan-card idle-after-relaunch behavior, diet-picker persistence across Settings/dashboard round-trips per 04-RESEARCH.md Pitfall 3, Movement Snapshot placement, and Settings reachability). No touch-injection tool (idb/XCUITest) is available in this environment to automate that walkthrough, only `simctl`. Phase 4 round 1 cannot close until a human runs those steps and returns an explicit "approved" verdict, or reports findings to be fixed and re-presented per the plan's own Task 3 instructions.

---
*Phase: 04-household-home*
*Completed: 2026-09-08 (Tasks 1-2 only; Task 3 pending human action)*

## Self-Check: PASSED

- FOUND: `RithamApp/RithamTests/Phase4CoverageTests.swift`
- FOUND: `.planning/phases/04-household-home/04-03-SUMMARY.md`
- FOUND commit `300a184` (Task 1)
- FOUND commit `080857b` (Task 2)
- FOUND commit `849258d` (this SUMMARY)
