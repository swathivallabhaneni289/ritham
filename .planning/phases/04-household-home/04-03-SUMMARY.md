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
  - Task 3's Simulator checkpoint, now discharged with an explicit "this looks fine just continue" approval after seven rounds of direct human-checkpoint feedback (see Checkpoint Iteration History below)
  - The final approved dashboard shape: `.flat` decorative surface (no band header), shell-less Momentum/Exercise sections, a static non-scrolling icon-strip row (Sleep/Workout plan/Diet plan), a 2x2 logging-action grid, and a narrow dated extension of the accent-color reservation to the workout tile's ready-state numeral
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
    description: "A human has seen the dashboard render in the Simulator (Task 3) and confirmed it is the screen the product owner asked for. This ran as seven rounds of direct build-test-relaunch-screenshot iteration rather than a single walkthrough of the plan's 10 scripted steps, since every round surfaced new discretionary layout/aesthetic feedback the plan's own text left to implementation discretion (04-UI-SPEC.md's Claude's Discretion section) -- see Checkpoint Iteration History below for the full sequence and each round's verbatim feedback."
    requirement: "CROSSGEN-01"
    verification:
      - kind: human_verification
        ref: "Product owner's explicit verdict, this session: \"this looks fine just continue\" -- the plan's own resume-signal condition (\"Type 'approved'...\") satisfied in substance, not literal wording."
        status: pass
    human_judgment: true
    rationale: "Task 3 is an explicit checkpoint:human-verify, gate=\"blocking\" task. No touch-injection tool is available in this environment (idb/XCUITest absent, only simctl), so every round's verification was: implement -> Scripts/build-app.sh test -> Scripts/build-app.sh build -> simctl install/launch -> simctl io screenshot -> present to the product owner. The product owner reviewed the live Simulator directly on their own machine each round."

# Metrics
duration: 25min (Tasks 1-2, prior session) + ~5.5hr (this session: Task 3's seven-round checkpoint iteration, including a design-panel workflow and a build-tooling bug found and fixed mid-session)
completed: 2026-09-09
status: complete
---

# Phase 4 Plan 03: Structural Coverage Gates and Full-Suite Green, Task 3 Approved — Summary

**`Phase4CoverageTests` (11 tests) makes CROSSGEN-01's dashboard shape, the Momentum section's file location, and the Settings screening-route survival into automated gates; the full RithamTests + RithamCore surface is green and the app builds; ROADMAP.md/REQUIREMENTS.md record CROSSGEN-01 as delivered. Task 3's human Simulator checkpoint ran as seven rounds of direct feedback and iteration (grid layout → tap-to-open cards → design-panel-synthesized icon-strip → shell removal → flat header/color) and closed with an explicit approval. Phase 4 round 1 is complete; HOUSEHOLD-01/CROSSGEN-04 remain open for a later round.**

## Checkpoint Iteration History (Task 3)

The plan's 10 scripted verification steps assumed a single walkthrough; in practice the product
owner reviewed the live Simulator on their own machine after every round of changes and gave new
discretionary feedback each time, since 04-UI-SPEC.md's own "Claude's Discretion" section left
exact visual arrangement unspecified. Seven rounds, each with a real build→test→install→launch→
screenshot cycle:

1. **"not stacked one after the other"** → Momentum/sleep became a two-column grid row.
2. **"not too much text"** → workout-plan/diet-plan sections shrank to compact status lines.
3. **"diet/workout should open only on tap... follow how Apple tracks exercises"** → tap-to-open
   sheets (`RecommendationsQuickView`, `DietPlanQuickEditView`); per-row activity icons added.
4. **"too basic, no proper aesthetics... bunch of boxes with text"** → icon badges on every
   section heading, hairline card borders, Momentum promoted to a full-width hero card with a
   `RithamType.display` streak numeral.
5. **"I don't wanna see them horizontally. No."** (rejecting an interim horizontally-swiped
   `TabView` carousel built in response to a "sliding dashboard" request that round) → a design
   panel (three independently-proposed, three-lens-judged directions, synthesized) diagnosed that
   every round so far had changed container shape while keeping the same card *shell*; the
   winning direction dropped the shell entirely for Sleep/Workout plan/Diet plan in favor of a
   static, non-scrolling `iconTile` row (icon + short label, no fill, no stroke, no chevron), with
   the workout tile's ready-state session count rendered as a big numeral instead of a sentence.
   A real build-tooling bug was found and fixed mid-round: two stale Xcode DerivedData
   directories existed, and a naive `find ... | head -1` glob for installing onto the Simulator
   was silently picking the *older* one every time regardless of which one had just been rebuilt
   — several rounds of "verification" screenshots had actually been showing a two-day-old build.
   Fixed by resolving `BUILT_PRODUCTS_DIR` explicitly via `xcodebuild -showBuildSettings` and
   deleting the stale DerivedData directory.
6. **"even history or cardio track... too much of boxes and text... a bunch of words clump
   together"** + **"This week's activity... a little too big"** → Momentum and Exercise dropped
   their own card shell too (the whole dashboard is now shell-less throughout, separated by
   `RithamSpacing.lg` whitespace and icon+heading only); the four cardio/strength logging buttons
   moved from four stacked full-width rows to a 2x2 grid.
7. **"we don't need the stripes... use the whole page... add some color to some of the
   features"** → the screen's decorative band header moved from `DecorativeSurface.boundedHeaderOnly`
   to `.flat` (reclaiming the ~250pt header band for content — the whole empty-state dashboard now
   fits on one screen without scrolling); the workout tile's ready-state numeral recolored from
   `paper` to `RithamColor.hot`, a narrow dated extension of the accent-color reservation
   (04-UI-SPEC.md's own revision note), not a general loosening.

**Verdict:** "this looks fine just continue" (round 7's build). Checkpoint discharged.

A tangential, out-of-scope concern raised during round 6 — that manual cardio/strength logging
requires the user to "practically go and stop it" themselves, versus other apps/devices that are
"more accurate" via automatic detection — was recorded as a new Deferred Idea in 04-CONTEXT.md
(same class of new data-ingestion scope as D-08's steps/calories deferral) rather than acted on;
it needs its own dedicated scoping discussion.

## Performance

- **Duration:** ~25 min (Tasks 1-2, prior session) + ~5.5hr (this session: Task 3's seven-round checkpoint iteration)
- **Started:** 2026-09-08 (Tasks 1-2); 2026-09-08/09 (Task 3's rounds)
- **Completed:** 2026-09-09 (all three tasks committed; checkpoint approved)
- **Tasks:** 3 of 3 completed and committed
- **Files modified:** 2 (Task 1) + 2 (Task 2) + 7 (Task 3: HomeHubView.swift, MomentumDashboardSection.swift, new SectionIconBadge.swift, project.pbxproj, 04-CONTEXT.md, 04-UI-SPEC.md, this SUMMARY)

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
3. **Task 3: seven-round checkpoint iteration** - `5b75823` (grid layout, tap-to-open cards, round 1
   of this session's own iteration — committed mid-session before the design panel ran), `154a757`
   (icon-strip layout, shell removal, flat header — the remaining five rounds), `9681ba2`
   (CONTEXT/UI-SPEC dated revision notes for the above)

This plan's own metadata/SUMMARY commit follows this file.

_Note: this session performed no TDD red/green cycle; Task 1's test-writing and negative-control verification had already happened in the prior, interrupted session before this session began. This session's Task 1 commit captures that already-completed, already-verified work._

## Files Created/Modified

- `RithamApp/RithamTests/Phase4CoverageTests.swift` - new suite, nested in `StepRegistryTouchingSuites`, 11 tests covering registry completeness, Momentum-directory non-vacuity, dashboard inline-section shape, Settings-route survival, and Home-directory no-sharing
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` repeatedly, once per new file added across Task 3's rounds
- `.planning/ROADMAP.md` - Phase 4 at 3/3 plans complete, all three plan lines ticked, Progress table updated, new dated round-1-shipped annotation added, existing annotations preserved verbatim
- `.planning/REQUIREMENTS.md` - `CROSSGEN-01` ticked and Complete; `HOUSEHOLD-01`/`CROSSGEN-04` still Pending
- `RithamApp/Ritham/Home/HomeHubView.swift` - rewritten across seven checkpoint rounds; see Checkpoint Iteration History above for the final shape
- `RithamApp/Ritham/Momentum/Components/MomentumDashboardSection.swift` - gained a heading (icon + "Momentum"), streak line promoted to `RithamType.display`
- `RithamApp/Ritham/Components/SectionIconBadge.swift` - new; a rounded-square (never circular) neutral glyph badge shared by every section heading and icon-strip tile
- `.planning/phases/04-household-home/04-CONTEXT.md` - new Deferred Idea recording the automatic/device-tracking concern raised in round 6
- `.planning/phases/04-household-home/04-UI-SPEC.md` - dated revision notes for the header-surface and accent-color-reservation changes

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

All three tasks are committed and verified: `Phase4CoverageTests` is a real, green, negative-control-proven structural gate; the entire automated surface (`RithamTests` full target, `RithamCore`, and the app build) is green; `ROADMAP.md`/`REQUIREMENTS.md` correctly record `CROSSGEN-01` as delivered by Phase 4 round 1 while `HOUSEHOLD-01`/`CROSSGEN-04` remain open — the Phase 4 top-level checkbox stays correctly unticked; and Task 3's checkpoint is discharged with an explicit product-owner approval after seven rounds of direct feedback and iteration (Checkpoint Iteration History above).

**Phase 4 round 1 is closed.** HOUSEHOLD-01 and CROSSGEN-04 remain open for a later Phase 4 round — a future `/gsd-progress` or `/gsd-plan-phase 4` should pick those up rather than treating Phase 4 as fully finished. The other still-open item from earlier sessions, Phase 3's own UAT sign-off (`03-UAT.md`), remains separately paused and is unaffected by this closure.

---
*Phase: 04-household-home*
*Completed: 2026-09-09 (all three tasks; Task 3 checkpoint approved)*

## Self-Check: PASSED

- FOUND: `RithamApp/RithamTests/Phase4CoverageTests.swift`
- FOUND: `.planning/phases/04-household-home/04-03-SUMMARY.md`
- FOUND: `RithamApp/Ritham/Components/SectionIconBadge.swift`
- FOUND commit `300a184` (Task 1)
- FOUND commit `080857b` (Task 2)
- FOUND commit `849258d` (prior SUMMARY revision, Tasks 1-2 only)
- FOUND commit `5b75823` (Task 3, round 1: grid layout, tap-to-open cards)
- FOUND commit `154a757` (Task 3, rounds 2-6: icon-strip layout, shell removal, flat header)
- FOUND commit `9681ba2` (Task 3: CONTEXT/UI-SPEC dated revision notes)
