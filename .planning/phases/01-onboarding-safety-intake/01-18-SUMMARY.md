---
phase: 01-onboarding-safety-intake
plan: 18
subsystem: testing
tags: [swift-testing, swiftui, onboarding, accessibility, dynamic-type]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake (01-13, 01-15, 01-16, 01-17)
    provides: Every onboarding/screening screen and its registrar (AboutYouRegistration, CalibrationRegistration, ScreeningRegistration)
provides:
  - StepBootstrap.registerAllSteps() — the single call site that registers every screen group at app launch, idempotent
  - OnboardingCompletionRegistration — registers .screeningComplete and .home, closing a gap deferred-items.md flagged
  - PhaseCoverageTests — the phase's completeness gate (unregisteredSteps empty, every step resolves without trapping, router traversal reaches only registered steps, every ConditionTag has a gate + unique displayName)
  - Human-verified AX3/AX5 accessibility pass across onboarding (Task 2, Group A)
affects: [phase-2-planning, phase-4-navigation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bootstrap-in-last-wave: registrar call sites owned by the phase's final plan, not by each screen-group plan, to avoid a shared-file write conflict between parallel executors"

key-files:
  created:
    - RithamApp/Ritham/App/StepBootstrap.swift
    - RithamApp/RithamTests/PhaseCoverageTests.swift
  modified:
    - RithamApp/Ritham/App/RithamApp.swift

key-decisions:
  - "Task 1 (StepBootstrap + PhaseCoverageTests) was already implemented and committed (695c1e5, 2026-08-28) in a prior session — this plan's remaining work was verifying it still holds and closing out Task 2, not building it fresh."
  - "Task 2's physical-device calibration walk (Group B, items 8-12) is moot per ROADMAP.md's 2026-09-01 note: calibration moved out of onboarding entirely and is router-unreachable from .welcome, so its human-verification requirement no longer applies to this plan — only the AX3/AX5 accessibility pass (Group A) was actually required to close this plan out."
  - "Group A items 6-7 (the compact disclaimer tag's tap target and expand behavior, on HealthProfileView) could not be exercised through real navigation — nothing in the shipped app currently routes into SettingsView; that navigation is Phase 4 scope. Spot-checked once via a throwaway debug root-view swap (not shipped, reverted immediately) and deferred to a full re-check once Phase 4 wires up real Settings navigation, rather than treating a debug-only spot-check as equivalent to verifying the real user experience."

patterns-established:
  - "Group A accessibility checks (header dropout at AX3/AX5, flat charcoal on health-data screens, minimum text size, dark-on-fill contrast) are the durable acceptance bar for every future onboarding-adjacent screen, not a one-time gate."

requirements-completed: [ONBOARD-01, CROSSGEN-05, HEALTH-01]

coverage:
  - id: D1
    description: "StepBootstrap.registerAllSteps() registers every screen group (About You, Calibration, Screening, Completion) at app launch, idempotently"
    requirement: CROSSGEN-05
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/PhaseCoverageTests.swift#calling StepBootstrap.registerAllSteps() twice leaves unregisteredSteps empty and every step still resolvable"
        status: pass
    human_judgment: false
  - id: D2
    description: "PhaseCoverageTests proves no onboarding step was left on the unimplemented fallback, every step resolves without trapping, and reachable router paths (baseline, skipped-calibration, gate-triggered, SCOFF-triggered) visit only registered steps"
    requirement: ONBOARD-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/PhaseCoverageTests.swift (StepRegistry.unregisteredSteps is empty / view(for:flow:) without trapping / baseline+skipped-calibration+gate-triggered+scoff-triggered path tests)"
        status: pass
      - kind: unit
        ref: "cd RithamCore && ./Scripts/test-core.sh (164 tests, 11 suites)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every ConditionTag case has a defined GateEscalation.baseGates(for:) value in both domains, and a non-empty, unique displayName"
    requirement: HEALTH-01
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/PhaseCoverageTests.swift#GateEscalation.baseGates(for:) returns a value for every ConditionTag case / every ConditionTag case has a non-empty, unique displayName"
        status: pass
    human_judgment: false
  - id: D4
    description: "Accessibility reflow at AX3/AX5 across onboarding: decorative headers drop out, health-data screens stay flat charcoal at every size, no text renders below the footer disclaimer's size, filled coral/lime controls always carry dark labels"
    requirement: ONBOARD-01
    verification: []
    human_judgment: true
    rationale: "Rendering correctness at accessibility text sizes is not meaningfully assertable in a unit test (01-VALIDATION.md's own stated reason) — confirmed conversationally by the developer, item by item, in the simulator."
  - id: D5
    description: "Compact disclaimer tag (HealthProfileView) is easy to hit with a thumb and reveals the full disclaimer on tap"
    verification: []
    human_judgment: true
    rationale: "Deferred, not verified — HealthProfileView is unreachable through real app navigation (no path into SettingsView exists yet; that's Phase 4 scope). Spot-checked once via a throwaway debug root-view swap, not the shipped experience. Re-check required once Phase 4 wires up real Settings navigation; logged in deferred-items.md."

duration: n/a (Task 1 executed in a prior session; this session closed out verification)
completed: 2026-09-03
status: complete
---

# Phase 1: Onboarding & Safety Intake Summary

**Every onboarding step resolves to a registered screen (StepBootstrap + PhaseCoverageTests), and the AX3/AX5 accessibility pass — the only human-verification actually required per the 2026-09-01 calibration-scope decision — is confirmed, closing Phase 1.**

## Performance

- **Task 1:** Implemented in a prior session (commit `695c1e5`, 2026-08-28); reverified this session.
- **Task 2:** Human-verify checkpoint, executed conversationally this session (2026-09-03).
- **Tasks:** 2 (both closed)
- **Files modified this session:** 2 (`.planning/phases/01-onboarding-safety-intake/deferred-items.md`, this SUMMARY.md)

## Accomplishments
- Confirmed `StepBootstrap.registerAllSteps()` registers all four screen-group registrars and is invoked from `RithamApp.swift` before the root view renders; calling it twice does not duplicate registrations.
- Confirmed `PhaseCoverageTests` passes in full: `StepRegistry.unregisteredSteps` is empty, `StepRegistry.view(for:flow:)` resolves every `OnboardingStep` without trapping, four reachable router paths (baseline, skipped-calibration, gate-triggered, SCOFF-triggered) visit only registered steps, every `ConditionTag` has a defined gate in both domains, and every `ConditionTag` has a non-empty, unique `displayName`.
- Ran both official test suites clean: `RithamCore/Scripts/test-core.sh` (164/164) and `Scripts/build-app.sh test` (105/105, `TEST SUCCEEDED`).
- Established that Task 2's Group B (physical-device calibration walk) is moot for this plan, per `ROADMAP.md`'s own 2026-09-01 decision record — calibration is no longer part of onboarding and is router-unreachable from `.welcome`.
- Verified Task 2's Group A (accessibility reflow) item by item with the developer: baseline rendering, AX3/AX5 header dropout, flat charcoal on health-data screens at every size, minimum text size (nothing smaller than the footer disclaimer), and dark-on-fill contrast for coral/lime controls.
- Identified and documented a real gap: the compact disclaimer tag (Group A items 6-7) lives on `HealthProfileView`, reachable only via `SettingsView` — and nothing in the shipped app currently navigates into `SettingsView`. Logged as deferred in `deferred-items.md` rather than either skipping silently or treating a debug-only spot-check as real verification.

## Task Commits

Task 1 was implemented and committed in a prior session:
1. **Task 1: Step bootstrap and phase coverage assertions across both suites** - `695c1e5` (feat, 2026-08-28)

Task 2 (human-verify checkpoint) produced no source changes; its one deviation was documented:
2. **Task 2: Deferral of disclaimer-tag checks** - `0c40c55` (docs)

**Plan metadata:** this commit (docs: complete plan)

## Files Created/Modified
- `RithamApp/Ritham/App/StepBootstrap.swift` - single registrar call site (prior session)
- `RithamApp/RithamTests/PhaseCoverageTests.swift` - phase completeness gate (prior session)
- `RithamApp/Ritham/App/RithamApp.swift` - invokes `StepBootstrap.registerAllSteps()` before root view (prior session)
- `.planning/phases/01-onboarding-safety-intake/deferred-items.md` - logged the Settings-navigation-unreachable gap (this session)

## Decisions Made
- Task 2's Group B (physical-device calibration) is moot for this plan's closure — see `key-decisions` above and `ROADMAP.md`'s 2026-09-01 note. Not re-litigated here; treated as an existing, authoritative project decision.
- Group A items 6-7 (disclaimer tag) deferred rather than force-verified through a debug shortcut — checking a screen nobody can reach yet doesn't verify the real shipped experience.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 2's stated Group B requirement superseded by a later project decision**
- **Found during:** Task 2 (re-reading 01-18-PLAN.md's own text against ROADMAP.md)
- **Issue:** 01-18-PLAN.md's Task 2 still lists the physical-device calibration walk (Group B) as required, but predates the 2026-09-01 decision that moved calibration out of onboarding entirely (router-unreachable from `.welcome`). ROADMAP.md's own note explicitly resolves this: "only the AX3/AX5 accessibility pass remains for 01-18."
- **Fix:** Treated Group B as satisfied-by-supersession rather than asking the developer to perform a 10+ minute physical walk test for a flow the shipped app can no longer reach from onboarding. Group A (accessibility) carried the full verification weight.
- **Files modified:** None (a scope-interpretation deviation, not a code change)
- **Verification:** Directly quoted the authoritative ROADMAP.md passage to the developer before treating Group B as resolved.
- **Committed in:** n/a (documented in conversation and in this SUMMARY)

---

**Total deviations:** 1 auto-fixed (1 blocking-scope correction)
**Impact on plan:** Corrects a stale plan against an already-decided, later project override. No scope creep — if anything, this narrows what was actually required.

## Issues Encountered
- Group A items 6-7 could not be verified through real app navigation (Settings has no entry point in the shipped app yet). Resolved by spot-checking once via a throwaway debug root-view swap (never shipped, reverted immediately after) and formally deferring the real check to whichever plan wires up Phase 4's home-screen navigation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 (Onboarding & Safety Intake) is complete: every onboarding/screening step is registered and reachable, the phase's own completeness gate (`PhaseCoverageTests`) passes, and the required human accessibility verification is confirmed.
- Calibration (walk/lift sessions, `RadialSessionTimer`) is fully built, tested, and intact but currently unreachable from onboarding — reserved for Phase 2's `ONBOARD-01` triggered pre-assessment. `RadialSessionTimer` has not yet been verified at AX3/AX5 itself (carried forward to whichever phase builds the recommend-exercises trigger, per ROADMAP.md).
- A pending todo captures a Phase 2 product requirement worth discussing when that phase starts: workout-plan frequency selection (3/5/7 days a week) and experience-level scaling, tied to the same triggered calibration pre-assessment (`.planning/todos/pending/2026-09-03-workout-plan-frequency-selection-and-experience-scaling.md`).
- Known, deliberately deferred gap: `SettingsView`/`HealthProfileView` have no navigation entry point from the shipped app. Phase 4 (Household & Home) is expected to resolve this when it builds the real home screen; `deferred-items.md` carries the specifics (including the compact disclaimer tag re-check and `EditAnswerFlow`'s fresh-launch data-hydration limitation).
- No blockers for starting Phase 2.

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-09-03*
