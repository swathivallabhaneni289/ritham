---
phase: 03-momentum-recovery
plan: 08
subsystem: ui
tags: [swiftui, swift-testing, recommendations, sleep-checkin, recovery, ritham-core]

# Dependency graph
requires:
  - phase: 03-momentum-recovery
    provides: "03-05's SleepCheckIn/SleepAdjustment (RithamCore) and HealthDataStore.loadSleepCheckIn/saveSleepCheckIn; 03-06's OnboardingStep.momentum/StepRegistry precedent; 03-07's HomeHubView Momentum summary section and flow.open(.momentum) wiring"
provides:
  - "OnboardingStep.sleepCheckIn plus SleepCheckInView -- a single-purpose, fully skippable Great/OK/Poor + optional-note screen reachable from a state-free HomeHubView CTA"
  - "RecommendationsModel's post-fetch RECOVERY-01 adjustment: original/adjusted WorkoutPlan pair, isDisplayingAdjustedPlan flag, toggleDisplayedPlan(), one plan-level banner, one equal-weight toggle -- WorkoutPlanClient/WorkoutPlanRequest untouched"
  - "RecoveryAdjustmentTests -- one named test per RECOVERY-01/D-05 invariant, plus two wire/volume gates"
affects: [03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UI-layer wrapper-type-over-domain-enum for ChoiceQuestionView's Hashable & Identifiable requirement (SleepQualityOption), matching WeeklyFrequencyOption/MomentumTargetOption's own precedent rather than a retroactive cross-module Hashable conformance"
    - "Client-side post-fetch adjustment held as a side-channel plan pair (originalPlan/adjustedPlan/isDisplayingAdjustedPlan) on the existing @Observable model rather than widening the RecommendationsState enum case -- keeps every pre-existing .plan(WorkoutPlan) call site and test unchanged"
    - "Comment-filtered own-source-file scan (URL(fileURLWithPath: #filePath) relative lookup) as the 'this screen's rendered strings never mention X' test technique, reusing MomentumViewTests.noMomentumControlUsesTheDestructiveColor's exact form since no ViewInspector-style rendering tool exists in this codebase"

key-files:
  created:
    - RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift
    - RithamApp/RithamTests/RecoveryAdjustmentTests.swift
  modified:
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift
    - RithamApp/Ritham/Momentum/MomentumRegistration.swift
    - RithamApp/Ritham/Home/HomeHubView.swift
    - RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Rule 3 deviation: updated OnboardingRouter.nextStep's exhaustive switch and OnboardingFlowStateTests' hardcoded OnboardingStep.allCases.count (25 -> 26) for the new .sleepCheckIn case -- the identical compile-time/test-gate necessity 03-06-SUMMARY.md recorded for .momentum, not called out in this plan's own file list"
  - "SleepQualityOption wraps SleepQuality with a manual == / hash(into:) over rawValue rather than retroactively conforming SleepQuality to Hashable across module boundaries -- matches WeeklyFrequencyOption/MomentumTargetOption's own documented rationale"
  - "RecommendationsModel exposes the adjustment as three side-channel private(set) properties (originalPlan/adjustedPlan/isDisplayingAdjustedPlan) rather than changing RecommendationsState.plan's associated type -- every pre-existing test asserting case .plan(let plan) / plan.sessions / plan.frequencyPerWeek needed zero changes"
  - "The equal-weight toggle (RECOVERY-01 invariant 2) is one SecondaryCTAButton whose title alternates between MomentumCopy.Plan's two catalog strings, not two separate buttons -- satisfies 'never one primary and one secondary' by construction rather than by two components matching"
  - "RecommendationsModel/RecommendationsView modified in place inside RecommendationsView.swift, confirming 03-RESEARCH.md/03-PATTERNS.md's assumed separate RecommendationsModel.swift does not exist in this repo"

requirements-completed: [RECOVERY-01]

coverage:
  - id: D1
    description: "A single-purpose, fully skippable daily sleep check-in screen (Great/OK/Poor + optional note) exists, is registered, and mentions no shield/streak/milestone/Recovery Week anywhere"
    requirement: "RECOVERY-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecoveryAdjustmentTests.swift (sleepCheckInResolvesAndRegistryIsComplete, theSleepScreenMentionsNoMomentumState, dismissingWithoutSelectionWritesNoRow)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A Poor check-in shifts every session in the displayed plan uniformly lighter via one plan-level banner and an equal-weight toggle back to the original, with WorkoutPlanClient/WorkoutPlanRequest untouched"
    requirement: "RECOVERY-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecoveryAdjustmentTests.swift (aLighterSuggestedSessionThatMeetsTheBarFullyQualifies, decliningTheLighterSuggestionIsAlwaysAvailableAndFullyQualifies, noMessagingDifferentiatesTrainingHarderThanSuggested, theWorkoutPlanRequestStillCarriesExactlyThreeFields, theLighterAdjustmentNeverIncreasesPrescribedVolume)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Each of RECOVERY-01/D-05's seven invariants (qualification bar unchanged, lighter session fully qualifies, declining fully qualifies, skipping has zero effect, never consumes a shield, never triggers a Recovery Week, no differentiating messaging) has its own named, passing test"
    requirement: "RECOVERY-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/RecoveryAdjustmentTests.swift (all 12 tests in the RecoveryAdjustmentTests suite)"
        status: pass
    human_judgment: false

duration: 50min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 08: Sleep Check-In and Recovery-Aware Plan Adjustment Summary

**A single-purpose, fully skippable sleep check-in screen and a client-side post-fetch adjustment on `RecommendationsModel` that shifts a Poor night's whole displayed workout plan lighter -- with a dedicated 12-test suite proving all seven of D-05's RECOVERY-01 invariants hold, and the Go service's three-field request boundary provably untouched.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-09-06T11:15:00Z
- **Completed:** 2026-09-06T12:01:00Z
- **Tasks:** 3
- **Files modified:** 8 (2 new, 6 modified)

## Accomplishments
- `SleepCheckInView` -- a `DecorativeSurface.flat` screen with a `ChoiceQuestionView` over Great/OK/Poor plus an optional note field, saving through `HealthDataStore.saveSleepCheckIn` and returning to the hub -- registered as `OnboardingStep.sleepCheckIn` in `MomentumRegistration.registerAll()`. Fully skippable: nothing persists until the primary CTA is tapped, and `pendingCheckIn(selection:note:day:)` is a `nonisolated static func` exercised directly by a dedicated test proving a bare dismissal writes nothing.
- `HomeHubView` gained one `SecondaryCTAButton` routing to `.sleepCheckIn`, placed outside the Momentum summary section (never inside it) so the sleep and Momentum systems share zero UI surface beyond the one plan-level banner (invariant 7), with a label that is a plain string constant carrying no dependency on stored check-in state (invariant 3).
- `RecommendationsModel` (declared inside `RecommendationsView.swift` -- the real, single declaration site; 03-RESEARCH.md/03-PATTERNS.md both incorrectly assumed a separate `RecommendationsModel.swift`) now reads today's sleep check-in and computes `SleepAdjustment.shift` entirely after the plan client returns, holding `originalPlan`/`adjustedPlan`/`isDisplayingAdjustedPlan` as side-channel properties rather than widening `RecommendationsState`. `WorkoutPlanClient`/`WorkoutPlanRequest` are byte-for-byte untouched (`git diff --stat` confirms zero changes across all three task commits).
- `RecommendationsView` renders exactly one plain-text banner and one equal-weight toggle button (title alternates between `MomentumCopy.Plan`'s two catalog strings) when an adjustment applies -- the individual session rows render through unchanged code regardless of which plan is displayed, with the row-rendering code's own header comment stating that constraint.
- `RecoveryAdjustmentTests` (nested under `StepRegistryTouchingSuites`) grew to 12 tests across the plan's three tasks: 3 registration/skippability tests (Task 1) plus 9 invariant/gate tests (Task 3) -- one clearly named test per D-05 invariant, plus `theWorkoutPlanRequestStillCarriesExactlyThreeFields` and `theLighterAdjustmentNeverIncreasesPrescribedVolume`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Daily sleep check-in screen and its step registration** - `a72dd5b` (feat)
2. **Task 2: Client-side lighter-plan adjustment over the returned workout plan** - `0861593` (feat)
3. **Task 3: One named test per RECOVERY-01 invariant** - `5e67ec1` (test)

**Plan metadata:** (this commit, `docs(03-08): complete plan`)

## Files Created/Modified
- `RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift` - the sleep check-in screen, `SleepQualityOption` wrapper, and the pure `pendingCheckIn` derivation
- `RithamApp/RithamTests/RecoveryAdjustmentTests.swift` - the 12-test RECOVERY-01 invariant suite (registration, skippability, and D-05's seven invariants plus two gates)
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift` - added the `sleepCheckIn` case
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` - added `.sleepCheckIn` to the terminal-steps switch case (Rule 3)
- `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift` - updated the hardcoded `OnboardingStep.allCases.count` (25 -> 26) (Rule 3)
- `RithamApp/Ritham/Momentum/MomentumRegistration.swift` - registered `SleepCheckInView.self`
- `RithamApp/Ritham/Home/HomeHubView.swift` - added the state-free sleep check-in CTA
- `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` - the post-fetch adjustment, banner, and toggle
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` for the new source/test files (Task 1 only)

## Decisions Made
- `SleepQualityOption` wraps `SleepQuality` with a manual `==`/`hash(into:)` over `rawValue`, matching `WeeklyFrequencyOption`/`MomentumTargetOption`'s established "wrapper type rather than a retroactive conformance" pattern.
- `RecommendationsModel` exposes the adjustment as three side-channel `private(set) var` properties rather than changing `RecommendationsState.plan`'s associated type, so every pre-existing test and call site needed zero changes.
- The equal-weight toggle is one `SecondaryCTAButton` whose title alternates, not two separate buttons -- satisfies invariant 2 by construction.
- Reused the hub's Sleep headline copy (`MomentumCopy.Sleep.headline`, "How did you sleep?") as the hub CTA's own label rather than drafting a second string, since 03-UI-SPEC.md's Copywriting Contract has no dedicated hub-CTA row and the existing string already names the feature plainly and non-comparatively.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated `OnboardingRouter.nextStep`'s exhaustive switch and `OnboardingFlowStateTests`' hardcoded step count for the new `.sleepCheckIn` case**
- **Found during:** Task 1, immediately after adding the case to `OnboardingStep`
- **Issue:** `OnboardingStep` is an exhaustive `CaseIterable` enum; `OnboardingRouter.nextStep`'s switch over it is exhaustive by the compiler's own enforcement, so adding a case without adding it to the router's terminal-steps branch is a build error. Separately, `OnboardingFlowStateTests.phase2StepsRoundTripThroughRawValue` asserts `OnboardingStep.allCases.count == 25` by literal value, which the new case trips. Neither file is in this plan's stated file list, but plan 03-06's own summary recorded the identical necessity when it added `.momentum`, and the plan's own verification line ("`RithamCore/Scripts/test-core.sh` still passes after the second step-enum case is added") implies it without naming the files.
- **Fix:** Added `.sleepCheckIn` alongside `.momentum` in `OnboardingRouter.nextStep`'s terminal-steps case (both are entered only via `flow.open(_:)`, never routed into), and updated the hardcoded count from 25 to 26.
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift`, `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift`
- **Verification:** `RithamCore/Scripts/test-core.sh` passes (394 tests, 30 suites).
- **Committed in:** `a72dd5b` (Task 1 commit)

### Noted acceptance-criteria interpretation (not a fix -- a documented literal-reading gap)

**`grep -c "dayIndex" RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` is 2, not unchanged at 1.** Task 2's acceptance criteria asked for this count to stay "unchanged... except in the existing row-label expression." The adjusted-plan reconstruction (`applyingLighterShift`) necessarily copies each session's `dayIndex` forward verbatim when building the new `WorkoutPlanSession` (`WorkoutPlanSession(dayIndex: session.dayIndex, ...)`), which is a second line containing the token. The criterion's own stated intent -- "no comparison of a day index against a calendar weekday is introduced" -- holds exactly: the ordinal is only ever copied forward identically for every session (D-11's uniform-across-the-plan requirement), never read, compared, or branched on. Considered and rejected a JSON-round-trip reconstruction that would have kept the literal grep count at 1 without ever spelling the token: rejected because its `guard ... else { return session }` failure paths could make the lighter adjustment silently not apply in a health-adjacent feature, and because it is alien to this codebase's plain, explicit style. The natural, direct reconstruction is safer and clearer; the literal grep-count criterion is treated as satisfied in substance, not in exact digit.

---

**Total deviations:** 1 auto-fixed (1 blocking), plus 1 documented literal-acceptance-criteria interpretation.
**Impact on plan:** The Rule 3 fix was a required compile/test-gate necessity, not scope creep. The `dayIndex` interpretation trades a literal grep count for correctness and code clarity in a way fully consistent with the criterion's own stated purpose.

## Issues Encountered
None blocking. One transient simulator infrastructure error (`Mach error -308 (ipc/mig) server died`) occurred on the first `Scripts/build-app.sh test` invocation for Task 1; a `xcrun simctl shutdown all` followed by a retry succeeded immediately. Unrelated to any code change in this plan.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `OnboardingStep.sleepCheckIn` and `SleepCheckInView` are registered and reachable from `HomeHubView`; plan 03-09 (sharing `OnboardingStep.swift`/`HomeHubView.swift` with this plan, per the orchestrator's deliberate sequential serialization) can extend either file without needing to re-discover this plan's additions.
- `RecommendationsModel.originalPlan`/`.adjustedPlan`/`.isDisplayingAdjustedPlan`/`.toggleDisplayedPlan()` are `private(set)`/internal, reachable from `RecommendationsView`'s own file and from `@testable import Ritham` test code, for any future plan that needs to read or extend the adjustment state.
- Known, pre-existing, documented race class (not introduced or fixed by this plan): `RecoveryAdjustmentTests` and `RecommendationsTests.swift`'s `WorkoutPlanClientTests`/`RecommendationsScreenTests` all mutate `StubURLProtocol`'s shared static state, but only `RecoveryAdjustmentTests` is nested under `StepRegistryTouchingSuites`. A full-target run that schedules these suites concurrently could still interleave on that shared state. Flagged in `RecoveryAdjustmentTests.swift`'s own `init()` comment; fixing it would require editing `RecommendationsTests.swift`'s suite declarations, which is out of this plan's file scope.
- `Scripts/build-app.sh build`, `RithamCore/Scripts/test-core.sh`, and every named verification suite in this plan (`RecoveryAdjustmentTests`, `PhaseCoverageTests`, `HomeHubTests`, `WorkoutPlanClientTests`, `PreAssessmentTests`, `RecommendationsScreenTests`, `MomentumSummaryTests`) all pass.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED

All 2 created files verified present on disk; all 3 task commits (a72dd5b, 0861593, 5e67ec1)
verified present in `git log --oneline --all`.
