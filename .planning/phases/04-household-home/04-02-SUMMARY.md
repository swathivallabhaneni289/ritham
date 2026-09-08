---
phase: 04-household-home
plan: 02
subsystem: ui
tags: [swiftui, dashboard, refactor, home-screen, momentum, recommendations, diet-plan]

# Dependency graph
requires:
  - phase: 04-household-home (plan 01)
    provides: RecommendationsSectionContent, DietPlanSectionContent, DietPatternPicker/AllergenPicker -- the dashboard-embeddable content extractions this plan wires into HomeHubView
  - phase: 03-momentum-recovery
    provides: MomentumSummaryReader/MomentumSummary, MomentumProgressBlocks, ShieldRow, MomentumView.streakLine -- reused unchanged inside the re-parented MomentumDashboardSection
provides:
  - MomentumDashboardSection (Ritham/Momentum/Components/) -- the Momentum summary rendering, re-parented so Phase3CoverageTests' no-sharing directory walk covers it
  - HomeHubView rewritten as a six-section dashboard (Momentum, sleep, exercise, workout plan, diet plan, overflow) replacing the vertical CTA-list interim hub
  - Four new HomeHubTests pinning routingSteps' post-rewrite contents, the dashboard headline copy, and the exercise section's session-list data source
affects: [04-03-structural-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dashboard Section Card: a private sectionCard(_:) helper (VStack + padding + RithamColor.paper.opacity(0.06) + clipShape(RoundedRectangle)) wrapping every content section, per 04-UI-SPEC.md's Dashboard Section Card contract"
    - "Centralized nonisolated static let copy catalog on the view type itself (dashboardHeadline, three section headings) instead of scattering literals or adding to RithamCore's MomentumCopy -- keeps RithamCore untouched (a hard verification requirement of this plan) while still satisfying the UI-SPEC's 'centralized, not scattered' copy instruction"

key-files:
  created:
    - RithamApp/Ritham/Momentum/Components/MomentumDashboardSection.swift
  modified:
    - RithamApp/Ritham/Home/HomeHubView.swift
    - RithamApp/RithamTests/HomeHubTests.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Moved the no-sessions empty state out of MomentumDashboardSection (where Task 1's zero-behaviour-change extraction had placed it verbatim) into HomeHubView.exerciseSection in Task 2, per 04-UI-SPEC.md section 3's explicit assignment -- a deliberate departure from 04-PATTERNS.md's verbatim-extraction sketch, called out in both the plan text and this SUMMARY per the plan's own instruction."
  - "Sleep section repeats MomentumCopy.Sleep.headline as both the card's heading-weight Text and the SecondaryCTAButton's title, rather than inventing a second button label -- 04-UI-SPEC.md's Copywriting Contract names exactly one string for this whole section, and the section is carried over unchanged from the pre-existing button per D-03."
  - "Sleep section is a heading-plus-button card with no other content, which is a literal exception to this plan's own must_haves rule ('no section is a card whose only content is a heading plus a button'). This is spec-mandated, not an oversight: 04-UI-SPEC.md section 2 and Task 2's own action text both specify exactly this shape, and RECOVERY-01 invariant 3 forbids adding any other content (badge/dot/count/derived state) to this card. Recorded here so plan 04-03's structural gate does not flag the sleep card as a D-01 violation."
  - "recommendationsModel reuses the same HealthDataStore instance already constructed for the Momentum summary read inside onAppear, rather than constructing a second HealthDataStore(context: modelContext) -- both would be equivalent (same modelContext), so reusing the one already in scope avoids a redundant construction with no behavior change."

patterns-established:
  - "Every dashboard section is independently loaded/rendered per 04-CONTEXT.md D-08's 'no aggregate view model' rule -- recommendationsModel joins momentumSummary/momentumLoadFailed/isMovementSnapshotEnabled as its own plain @State, constructed once in the same existing onAppear block, never a shared dashboard view model."

requirements-completed: [CROSSGEN-01]

coverage:
  - id: D1
    description: "MomentumDashboardSection re-parents the Momentum summary rendering verbatim into Ritham/Momentum/Components/, closing Phase3CoverageTests' pre-existing directory-walk gap (Ritham/Home/ was never scanned) with zero test-file edits; HomeHubView.momentumSection becomes a one-line bridge, still owning and passing down momentumSummary/momentumLoadFailed"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/Phase3CoverageTests -- noMomentumSurfaceOffersASharingAffordance"
        status: pass
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/MovementSnapshotViewTests -- theSnapshotEntryIsNotAdjacentToTheMomentumSummary"
        status: pass
    human_judgment: false
  - id: D2
    description: "HomeHubView's body is rewritten as six ordered Dashboard Section Card entries (Momentum, sleep, exercise, workout plan, diet plan, overflow), replacing the vertical PrimaryCTAButton/SecondaryCTAButton list; the exercise section reads momentumSummary.recentSessions directly (never re-derived) and owns the Movement Snapshot entry two cards below Momentum; the workout-plan and diet-plan sections embed RecommendationsSectionContent/DietPlanSectionContent inline with no auto-fetch; placeholder headline/body copy is deleted; routingSteps no longer lists .recommendations"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/MovementSnapshotViewTests -only-testing:RithamTests/HomeHubTests"
        status: pass
      - kind: other
        ref: "Scripts/build-app.sh build"
        status: pass
    human_judgment: false
  - id: D3
    description: "Four new HomeHubTests assert the post-rewrite routing surface (no .recommendations, every tracking destination still present as a set), the dashboard headline's non-placeholder copy, and that the exercise section's session list comes from MomentumSummaryReader's own already-labelled recentSessions -- not a second derivation"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/HomeHubTests (16 tests, 12 existing + 4 new)"
        status: pass
      - kind: unit
        ref: "Scripts/build-app.sh test (full RithamTests target, 401 tests, 50 suites) and RithamCore/Scripts/test-core.sh (396 tests, 30 suites, no diff to RithamCore)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-08
status: complete
---

# Phase 4 Plan 02: HomeHubView Dashboard Rewrite Summary

**Replaced HomeHubView's vertical CTA-list body with a six-section scrollable dashboard (Momentum, sleep, exercise, workout plan, diet plan, overflow), re-parenting the Momentum summary into Ritham/Momentum/Components/ so the existing no-sharing structural gate actually covers it.**

## Performance

- **Duration:** 45 min
- **Started:** 2026-09-08T09:27:00Z
- **Completed:** 2026-09-08T10:12:00Z
- **Tasks:** 3
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments
- `MomentumDashboardSection` carries the Momentum summary rendering (progress blocks, streak line, shield row, "Momentum" CTA) verbatim out of `HomeHubView`, physically located under `Ritham/Momentum/Components/` so `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`'s directory walk now covers it -- a pre-existing coverage gap this plan closes with zero test-file edits
- `HomeHubView.body` is now one `VStack` of six ordered entries -- Momentum, sleep, exercise, workout plan, diet plan, and a compact Guidance/Settings overflow row -- each real content wrapped in the Dashboard Section Card treatment, replacing the rejected vertical `PrimaryCTAButton`/`SecondaryCTAButton` list
- The exercise section reads `momentumSummary?.recentSessions` directly (D-02, never re-derived), renders each row's title and verification label at the `RithamType.label` floor (no `.caption`/`.footnote` anywhere in the file), and owns the relocated no-sessions empty state and the Movement Snapshot opt-in entry, kept two cards below Momentum per the locked adjacency rule
- The workout-plan and diet-plan sections embed `RecommendationsSectionContent`/`DietPlanSectionContent` (04-01's extractions) inline -- no navigation away, no auto-fetch on appear, no food-allergy screening checkbox on the dashboard
- Four new `HomeHubTests` pin the post-rewrite `routingSteps` contents, the `dashboardHeadline` copy, and that the exercise section's session list is `MomentumSummaryReader`'s own already-labelled data, not a second derivation

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-parent the Momentum summary into Ritham/Momentum/Components/, body otherwise unchanged** - `d0de605` (feat)
2. **Task 2: Rewrite HomeHubView's body as the sectioned dashboard** - `78a3e2a` (feat)
3. **Task 3: Dashboard derivation tests in HomeHubTests** - `c8d90ff` (test)

## Files Created/Modified
- `RithamApp/Ritham/Momentum/Components/MomentumDashboardSection.swift` - New: the Momentum summary rendering, verbatim from the old `momentumSection`, minus the empty-state block relocated to `exerciseSection` in Task 2
- `RithamApp/Ritham/Home/HomeHubView.swift` - Rewritten: six-section dashboard body, new copy-catalog static constants, `momentumSection` reduced to a one-line bridge, `routingSteps` no longer lists `.recommendations`
- `RithamApp/RithamTests/HomeHubTests.swift` - Four new tests appended under `// MARK: - Plan 04-02: the dashboard's derivations`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after Task 1 added `MomentumDashboardSection.swift`; Tasks 2 and 3 added no new files, confirmed by a no-diff `xcodegen generate` re-run at plan close

## Decisions Made

**Final member order inside `HomeHubView`** (for a future editor to see the marker constraint at a glance): copy-catalog static constants -> `flow`/`@Environment`/`@State` properties -> `body` -> `sleepSection` -> `exerciseSection` -> `workoutPlanSection` -> `dietPlanSection` -> `overflowRow` -> `sectionCard(_:)` -> `MARK: - D-08's Momentum summary section` -> `momentumSection` (struct's last member) -> closing brace -> `extension HomeHubView { showsMovementSnapshotEntry, routingSteps }`.

**The no-sessions empty-state relocation** (Momentum card -> exercise card): Task 1's zero-behaviour-change extraction moved the empty-state block into `MomentumDashboardSection` verbatim, matching the old `momentumSection`'s exact behavior. Task 2 then deleted it there and added it to `exerciseSection`, per 04-UI-SPEC.md section 3's explicit assignment ("Below the list (or in place of it, when `recentSessions.isEmpty`)..."). This is a deliberate departure from 04-PATTERNS.md's verbatim-extraction sketch, which the plan's own action text calls out and asks to be logged: the approved UI contract governs. Verified it exists in exactly one place (`grep -rn noSessionsHeadline` across both files returns a single hit, in `HomeHubView.swift`).

**Chosen headline string:** `"Home"` (`HomeHubView.dashboardHeadline`). Plain, non-temporary, matches 04-UI-SPEC.md's example wording exactly.

**Section heading wording (Claude's Discretion, per the plan's `<output>` instruction):** `"This week's activity"` (exercise), `"Your workout plan"` (workout plan), `"Diet plan"` (diet plan) -- centralized as `nonisolated static let` constants on `HomeHubView` itself rather than a `RithamCore` copy catalog addition, since this plan's own verification requires `RithamCore` untouched (`RithamCore/Scripts/test-core.sh` must pass with no diff to that package). The sleep section deliberately has no separate heading constant -- see the exception noted below.

**Session row date (Claude's Discretion):** not shown. Each row renders only `session.title` and, when present, `session.verificationLabel` -- no `startedAt` timestamp is rendered, since 04-UI-SPEC.md's row description names only title and verification label and no test or spec line requires a date. A future plan can add one without touching this plan's structural contract.

**Sleep card is a spec-mandated exception to this plan's own must_haves rule.** The plan's `must_haves.truths` states "No section is a card whose only content is a heading plus a button" as "D-01's actual compliance test." The sleep section is exactly that shape -- a heading-weight `Text` plus one `SecondaryCTAButton`, nothing else -- because 04-UI-SPEC.md section 2, Task 2's own action text, and RECOVERY-01 invariant 3 (no badge/dot/count/derived state permitted on this card) all independently require it. This was implemented as specified; flagging it here explicitly so plan 04-03's structural gate does not misclassify the sleep card as a D-01 violation when it audits "heading + button only" cards.

## Deviations from Plan

None beyond the two decisions logged above that the plan's own `<output>` section explicitly asked to be recorded (the empty-state relocation and the sleep-card exception). No Rule 1/2/3 auto-fixes were needed -- Task 1 was a verified zero-behaviour-change move (full suite green before and after), and Tasks 2-3 followed 04-UI-SPEC.md and 04-PATTERNS.md directly.

## Issues Encountered
None. All three tasks' automated verification (scoped suite, then full `RithamTests` target, then `RithamCore/Scripts/test-core.sh`) passed on the first run with no flakes observed during this plan's execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 04-03 can build its structural gate (positive file-location assertion for `MomentumDashboardSection.swift`, plus whatever additional coverage it adds) against a dashboard that is already fully wired and test-verified.
- The sleep-card must_haves exception (recorded above) and the empty-state relocation are both load-bearing context for 04-03's own gate design -- read the "Decisions Made" section above before writing that gate.
- Full `RithamTests` target (401 tests, 50 suites) and `RithamCore/Scripts/test-core.sh` (396 tests, 30 suites, zero diff to `RithamCore`) both green at plan close.
- No blockers for 04-03.

## Self-Check: PASSED

All 2 created/modified-with-new-content files verified present on disk (`MomentumDashboardSection.swift` exists; `HomeHubView.swift` and `HomeHubTests.swift` contain the expected new content). All 3 task commit hashes (`d0de605`, `78a3e2a`, `c8d90ff`) verified present in `git log --oneline -3`.

---
*Phase: 04-household-home*
*Completed: 2026-09-08*
