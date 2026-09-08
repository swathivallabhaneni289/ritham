---
phase: 04-household-home
plan: 01
subsystem: ui
tags: [swiftui, refactor, content-extraction, xcodegen, swift-testing, diet-01, healthdatastore]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: RecommendationsView/RecommendationsModel (workout-plan screen and its state machine)
  - phase: 01-onboarding-safety-intake
    provides: DietPlanView, HealthDataStore.updateProfile/saveFoodAllergens (DIET-01-isolated persistence)
provides:
  - RecommendationsSectionContent — the workout-plan content, extracted with no screen chrome of its own
  - DietPatternPicker / AllergenPicker / DietPlanSectionContent — the DIET-01-isolated diet controls, extracted with no screen chrome and no screening write path
  - DietSectionIsolationTests — the first automated DIET-01 isolation gate (behavioural + structural)
affects: [04-02-dashboard-layout, 04-03-structural-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Content-extraction re-parenting: a RithamScreen-wrapped screen's meaningful body is pulled into a plain child View taking the same model/flow, so a second host (the dashboard) can embed it without nesting a second ScrollView/header/background"
    - "Custom-Binding-as-persistence-gate: a computed Binding whose setter both assigns @State and persists, used instead of .onChange(of:) so a hydration-time state write can never be mistaken for (and re-persist as) a genuine user commit"

key-files:
  created:
    - RithamApp/Ritham/Recommendations/Views/RecommendationsSectionContent.swift
    - RithamApp/Ritham/Settings/DietPlanSectionContent.swift
    - RithamApp/RithamTests/DietSectionIsolationTests.swift
  modified:
    - RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift
    - RithamApp/Ritham/Settings/DietPlanView.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Split DietPlanSectionContent into three structs (DietPatternPicker, AllergenPicker, DietPlanSectionContent) rather than 04-PATTERNS.md's single-struct sketch, so each picker owns its own hydration/persistence state independently and DietPlanView can host DietPatternPicker/AllergenPicker separately, preserving its exact existing on-screen order around the screening checkbox"
  - "Used a computed Binding (not .onChange(of:)) as the persistence trigger for both pickers, since .onChange fires on the render pass after hydration's own @State write, after hasHydrated has already flipped true -- an onChange-based guard cannot distinguish a hydration write from a genuine user tap, but a custom Binding's setter only runs on an actual commit through it, by construction"
  - "persistDiet/persistAllergens wrap their HealthDataStore call in do/catch and set showSaveError on failure, a small improvement on DietPlanView's original silent try?, required by 04-UI-SPEC.md's diet-section error state"

patterns-established:
  - "Every dashboard-embeddable extraction in this phase carries no RithamScreen/ScrollView/header/NavigationStack/dismiss() of its own -- the host screen owns all chrome"

requirements-completed: [CROSSGEN-01]

coverage:
  - id: D1
    description: "RecommendationsSectionContent renders the full idle/loading/plan/error state machine with no screen chrome; RecommendationsView is a thin RithamScreen wrapper around it; .recommendations stays registered"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/RecommendationsScreenTests"
        status: pass
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/StepRegistryTouchingSuites/Phase2CoverageTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "DietPatternPicker/AllergenPicker hydrate from the device store and persist only through updateProfile/saveFoodAllergens; DietPlanSectionContent stacks both for dashboard embedding; DietPlanView keeps the screening checkbox/severity/Done unchanged"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/EditAnswerFlowTests"
        status: pass
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/AlwaysFreeListTests -only-testing:RithamTests/WorkoutFrequencyTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "DietSectionIsolationTests proves DIET-01 isolation both behaviourally (a diet/allergen write leaves every condition tag byte-identical) and structurally (the extracted file cannot reach GateResolution/saveScreeningResult/ScreeningAnswers/checklist/ChecklistItem/dismiss), with the counterpart guard that DietPlanView still owns the screening question"
    requirement: "CROSSGEN-01"
    verification:
      - kind: unit
        ref: "Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/DietSectionIsolationTests"
        status: pass
      - kind: unit
        ref: "negative control: temporarily adding GateResolution.resolve + saveScreeningResult to DietPlanSectionContent.swift's persistDiet made theDietSectionContentReachesNoScreeningWritePath fail with 3 recorded issues; reverted to a byte-identical file (verified via git status)"
        status: pass
    human_judgment: false

duration: 37min
completed: 2026-09-08
status: complete
---

# Phase 4 Plan 01: Content-Extraction Refactor Summary

**Extracted RecommendationsView and DietPlanView's dashboard-embeddable content into three new plain child views, with a dedicated automated gate proving the diet extraction cannot reach the safety-screening write path.**

## Performance

- **Duration:** 37 min
- **Started:** 2026-09-08T14:35:00+05:30
- **Completed:** 2026-09-08T15:12:33+05:30
- **Tasks:** 3
- **Files modified:** 6 (3 created, 2 modified, 1 regenerated)

## Accomplishments
- `RecommendationsSectionContent` carries the workout-plan idle/loading/plan/error state machine verbatim, with no `RithamScreen`/`ScrollView`/header/dismiss of its own; `RecommendationsView` is now a thin wrapper around it and stays registered at `.recommendations`
- `DietPatternPicker`/`AllergenPicker`/`DietPlanSectionContent` carry the DIET-01-isolated diet controls, hydrated from the device store (not empty in-memory `OnboardingFlow` state) and persisted only through `HealthDataStore.updateProfile`/`.saveFoodAllergens`
- `DietPlanView` keeps the food-allergy screening checkbox, severity follow-up, `resolveAndSaveScreening`, and `dismiss()`/"Done" unchanged -- D-05's narrowing stays structural, not just documented
- `DietSectionIsolationTests` closes 04-RESEARCH.md's Wave 0 gap: the first automated DIET-01 isolation gate, proven both behaviourally and structurally, with a confirmed negative control

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract RecommendationsSectionContent and thin RecommendationsView to a wrapper** - `42c62cd` (feat)
2. **Task 2: Extract the DIET-01-isolated pickers into DietPlanSectionContent.swift** - `d3d76a5` (feat)
3. **Task 3: DietSectionIsolationTests — the DIET-01 isolation gate (Wave 0 gap)** - `2515207` (test)

## Files Created/Modified
- `RithamApp/Ritham/Recommendations/Views/RecommendationsSectionContent.swift` - New: the extracted idle/loading/plan/error content, parameterized by `RecommendationsModel`/`OnboardingFlow`
- `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` - Thinned to a `RithamScreen` wrapper delegating to `RecommendationsSectionContent`; header comment updated to record that nothing pushes to `.recommendations` any more, per Pitfall 4
- `RithamApp/Ritham/Settings/DietPlanSectionContent.swift` - New: `DietPatternPicker`, `AllergenPicker`, `DietPlanSectionContent` — the DIET-01-isolated pickers, each with its own hydration guard and custom-`Binding` persistence
- `RithamApp/Ritham/Settings/DietPlanView.swift` - Now hosts `DietPatternPicker`/`AllergenPicker` in place of its own duplicate state/persistence; screening checkbox, severity follow-up, `resolveAndSaveScreening`, `dismiss()`/"Done" all unchanged
- `RithamApp/RithamTests/DietSectionIsolationTests.swift` - New: 4 tests (2 behavioural, 2 structural) nested in `MomentumContainerTouchingSuites`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after each task that added a file; a clean re-run at plan close produces no further diff

## Decisions Made
- **Split into three structs, not one:** 04-PATTERNS.md sketched a single `DietPlanSectionContent` owning both pickers' state directly. Splitting into `DietPatternPicker`/`AllergenPicker`/`DietPlanSectionContent` lets `DietPlanView` host each picker independently, in its exact existing screen position around the screening checkbox and severity follow-up (allergen picker only renders inside the `if flow.answers.screening.checklist.items.contains(.foodAllergies)` branch, same as before) — a single combined struct couldn't be split across that conditional boundary without either duplicating logic or exposing internal state.
- **Custom `Binding` instead of `.onChange(of:)`:** the plan's action text called this out explicitly as safety-critical. `.onChange(of:)` fires on the render pass *after* a state write, by which point a hydration-time `hasHydrated` guard has already flipped `true` — an `onChange` handler cannot tell a hydration write apart from a genuine user tap and would either double-persist on hydration or need a second, more fragile guard. A computed `Binding`'s setter only runs when something actually commits a new value through it (i.e., the user tapped a chip), so persistence-on-user-input holds by construction. Hydration assigns the underlying `@State` directly, never through the binding.
- **`persistDiet`/`persistAllergens` gained a `do`/`catch` with `showSaveError`**, a small improvement on `DietPlanView`'s original silent `try?`, required by 04-UI-SPEC.md's diet-section error state (the dashboard section needs a visible failure state; a full-screen sheet with a "Done" button retrying via re-navigation did not).

## Deviations from Plan

None beyond the two decisions above, both of which the plan's own `<output>` section explicitly anticipated and asked to be logged with reasons (see Decisions Made). No Rule 1/2/3 auto-fixes were needed — the extraction was mechanical, exactly as 04-RESEARCH.md's "Don't Hand-Roll" section required.

## Negative Control (Task 3, required by acceptance criteria)

Ran by hand, then reverted:
1. Temporarily added `let negativeControlResult = GateResolution.resolve(answers: ScreeningAnswers(), ageDerivedTags: [])` followed by `try? store.saveScreeningResult(negativeControlResult, answers: ScreeningAnswers(), now: Date())` to the top of `DietPatternPicker.persistDiet` in `DietPlanSectionContent.swift`.
2. Ran `Scripts/build-app.sh test -only-testing:RithamTests/MomentumContainerTouchingSuites/DietSectionIsolationTests`.
3. `theDietSectionContentReachesNoScreeningWritePath` failed with 3 recorded issues, naming `GateResolution`, `saveScreeningResult`, and `ScreeningAnswers` as banned tokens found outside a comment. Every other test in the suite still passed.
4. Reverted `DietPlanSectionContent.swift` from a pre-sabotage backup copy (kept in the session scratchpad, not committed anywhere). `git status --short` on the file showed no changes afterward, confirming a byte-identical revert.
5. Re-ran the full suite: all 4 tests passed again.

This proves the structural gate would actually catch a future regression, not merely pass vacuously.

## Symbols Plan 04-02 Will Reference

`HomeHubView`'s dashboard rewrite embeds these exact symbols, unchanged from this plan:

- `RecommendationsSectionContent(model: RecommendationsModel, flow: OnboardingFlow)` — construct a `RecommendationsModel(store: HealthDataStore(context: modelContext))` in the dashboard's own `onAppear` (matching `RecommendationsView`'s existing construction, per D-08's "no dashboard-specific aggregate view model" rule — the dashboard owns its own `RecommendationsModel?` state, not a shared one).
- `DietPlanSectionContent(flow: OnboardingFlow)` — the single symbol for the dashboard's diet-plan section; no `modelContext` parameter needed (each internal picker reads `@Environment(\.modelContext)` itself).
- If 04-02 wants the two diet controls independently rather than stacked (not expected per 04-UI-SPEC.md's Dashboard Section Card layout, but available): `DietPatternPicker(flow: OnboardingFlow)` and `AllergenPicker(flow: OnboardingFlow)` are both public-enough (internal, same module) to construct directly.
- `RecommendationsView`/`DietPlanView` themselves are untouched integration points — `RecommendationsView` stays registered at `.recommendations` (Pitfall 4) and `DietPlanView` stays reachable from Settings (Pitfall 3's narrowed scope) — neither needs any change from plan 04-02.

## Issues Encountered
- Two transient Simulator flakes (`Mach error -308 (ipc/mig) server died` on one `xcodebuild test` invocation) during verification, unrelated to this plan's changes — both resolved on retry with no code change. Not logged as a deviation since no source was touched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 04-02 can now embed `RecommendationsSectionContent` and `DietPlanSectionContent` directly inside the new dashboard's `RithamScreen` content closure, with zero further extraction work needed on these two screens.
- `RecommendationsModel`, `WorkoutPlanClient`, and every `HealthDataStore` accessor this plan touches were reused byte-for-byte — no domain-logic risk carries into 04-02.
- Full `RithamTests` target (397 tests, 50 suites) and `RithamCore/Scripts/test-core.sh` (396 tests, 30 suites) both green at plan close; no new failures introduced anywhere outside this plan's own new suite.
- No blockers for 04-02.

## Self-Check: PASSED

All 3 created files verified present on disk; all 3 task commit hashes (`42c62cd`, `d3d76a5`, `2515207`) verified present in git log.

---
*Phase: 04-household-home*
*Completed: 2026-09-08*
