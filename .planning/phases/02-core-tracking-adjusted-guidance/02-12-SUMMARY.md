---
phase: 02-core-tracking-adjusted-guidance
plan: 12
subsystem: ui
tags: [swiftui, swiftdata, health-screening, condition-tags, disclaimer-reuse]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "GuidanceCatalog/ContentPermission (02-04), WorkoutGuidanceCatalog/NutritionGuidanceCatalog/DietarySwapCatalog (02-07), CardioSessionView (02-10), StrengthSessionView (02-11)"
provides:
  - "GuidanceContext: the shared store-driven loader every adjusted-guidance surface reads (matched tags, per-domain ContentPermission, deterministic governing tag)"
  - "AdjustedGuidanceBanner: the reusable embedded card wrapping catalog presentable accessors plus the three reused Phase 1 disclaimer components"
  - "GuidanceView + NutritionGuidanceSection: the real .guidance screen (workout section, nutrition section with reference figures, DIET-02 swaps, DIET-03 education)"
  - "Inline workout guidance embedded in CardioSessionView and StrengthSessionView"
affects: [phase-3-momentum, settings-diet-plan, health-profile]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Store-driven GateResolutionResult reconstruction (HealthProfileView's pattern) reused for a second consumer via a shared GuidanceContext type"
    - "Deterministic 'governing tag' selection (min by ContentPermission, tie-broken by displayName) for rendering a single tag's text when multiple condition tags apply to one domain"
    - "Two independent view branches with no shared enclosing condition for a gate-conditional feature (DIET-02 swaps) and a gate-blind feature (DIET-03 education)"

key-files:
  created:
    - RithamApp/Ritham/Guidance/GuidanceContext.swift
    - RithamApp/Ritham/Guidance/Views/AdjustedGuidanceBanner.swift
    - RithamApp/Ritham/Guidance/Views/GuidanceView.swift
    - RithamApp/Ritham/Guidance/Views/NutritionGuidanceSection.swift
  modified:
    - RithamApp/Ritham/Guidance/GuidanceRegistration.swift
    - RithamApp/Ritham/Cardio/Views/CardioSessionView.swift
    - RithamApp/Ritham/Strength/Views/StrengthSessionView.swift
    - RithamApp/RithamTests/GuidanceViewTests.swift

key-decisions:
  - "AdjustedGuidanceBanner surfaces WorkoutGuidanceCatalog.neverTriggersStreakLoss independently of the permission branch, since heartDiseaseRecentEventOrSymptomatic (one of the five never-triggers-streak-loss tags) carries a zero-content workout permission and would otherwise lose that framing entirely behind the referral message"
  - "NutritionGuidanceSection treats a nil stored dietaryPattern (never visited DietPlanView) as 'show neither swaps nor education,' distinct from an explicitly-chosen DietaryPattern.none (omnivore), which does show baseline swap examples"
  - "GuidanceContext.governingTag(for:) is the single most-restrictive tag per domain (ties broken by displayName) -- both AdjustedGuidanceBanner and NutritionGuidanceSection select text through this one function rather than each re-deriving which tag to render"

requirements-completed: [HEALTH-03, HEALTH-04, DIET-02, DIET-03]

coverage:
  - id: D1
    description: "GuidanceContext reconstructs the gate result from stored condition tags (never re-deriving an age-based tag) and exposes resolved per-domain ContentPermission"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamTests/GuidanceViewTests.swift#GuidanceContextTests (6 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AdjustedGuidanceBanner renders permission-checked catalog text, the contraindicated list, and the never-triggers-streak-loss note, reusing ConditionDisclaimerTag/RequiredBlockingMessageView/StandingFooterDisclaimer verbatim as an embedded (never modal) card"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "grep-verified acceptance criteria (component reuse count, no fullScreenCover/.sheet, presentableAdjustment usage) -- see Task 1 acceptance criteria in 02-12-PLAN.md"
        status: pass
    human_judgment: true
    rationale: "Visual card layout, spacing, and disclaimer-tag expand/collapse interaction were not rendered on-device or in a simulator screenshot this session -- a human visual pass is warranted before considering the surface UI-complete."
  - id: D3
    description: "Both session-logging screens show inline workout guidance while remaining fully usable (logging, timing, saving) under a zero-content workout permission, with neither screen calling a guidance catalog accessor directly"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamTests/GuidanceViewTests.swift#InlineGuidanceTests (4 tests)"
        status: pass
      - kind: unit
        ref: "RithamTests/CardioViewTests.swift#CardioSessionScreenTests (re-verified individually, unaffected)"
        status: pass
      - kind: unit
        ref: "RithamTests/StrengthLoggingTests.swift#SupersetBuilderTests (re-verified individually, unaffected)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The dedicated guidance screen (GuidanceView) shows a workout section and a nutrition section with attributed published reference figures, DIET-02 dietary-pattern-matched food swaps (gate-conditional), and DIET-03 nutrient education (gate-blind, byte-identical under a blocking tag), plus stored food allergens and the severe-allergen verification notice"
    requirement: "HEALTH-04, DIET-02, DIET-03"
    verification:
      - kind: unit
        ref: "RithamTests/GuidanceViewTests.swift#NutritionGuidanceTests (7 tests)"
        status: pass
      - kind: unit
        ref: "xcodebuild build (full target) -- BUILD SUCCEEDED"
        status: pass
    human_judgment: true
    rationale: "The screen's on-device visual layout (workout/nutrition section ordering, reference-figure and education-block readability) was not rendered or screenshotted this session; data-level tests prove the gating logic but not the rendered presentation."

# Metrics
duration: 25min
completed: 2026-09-05
status: complete
---

# Phase 2 Plan 12: Condition-Adjusted Guidance Surfaces Summary

**Shared GuidanceContext + AdjustedGuidanceBanner reused across two session-logging screens and a new dedicated guidance screen, all reconstructing GateResolutionResult from stored tags and rendering only through catalog presentable accessors**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-05T22:10:00+05:30 (approx.)
- **Completed:** 2026-09-05T22:35:06+05:30
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments
- `GuidanceContext` gives every adjusted-guidance surface one shared, store-driven reconstruction of the user's condition tags and per-domain content permission, copying `HealthProfileView`'s own `GateEscalation.escalate` reconstruction rather than inventing a second one
- `AdjustedGuidanceBanner` is a single reusable embedded card that both session screens and the new nutrition section compose, rendering only through `presentableAdjustment`/`presentableGuidance` and reusing `ConditionDisclaimerTag`/`RequiredBlockingMessageView`/`StandingFooterDisclaimer` verbatim
- `CardioSessionView` and `StrengthSessionView` now show workout guidance inline at the moment of logging, with neither screen calling a guidance catalog accessor directly and no control gated on guidance state
- The `.guidance` step resolves to a real screen (`GuidanceView` + `NutritionGuidanceSection`) instead of the Phase 2 placeholder, with DIET-02 food swaps and DIET-03 nutrient education kept in two structurally independent view branches
- 17 new tests across three suites (`GuidanceContextTests`, `InlineGuidanceTests`, `NutritionGuidanceTests`), all passing individually; Wave 3's `CardioSessionScreenTests`/`SupersetBuilderTests` re-verified unaffected; full `xcodebuild build` succeeds

## Task Commits

1. **Task 1: Shared guidance context and the reusable inline banner** - `a26cdfb` (feat)
2. **Task 2: Inline guidance at logging time in both session screens** - `36b3b3c` (feat)
3. **Task 3: Dedicated guidance screen with nutrition, swaps and education blocks** - `f2387bb` (feat)

**Plan metadata:** (this commit)

_Note: tests and implementation were written and verified together per task rather than as separate RED/GREEN commits -- see "Deviations from Plan" below._

## Files Created/Modified
- `RithamApp/Ritham/Guidance/GuidanceContext.swift` - Store-driven `GateResolutionResult` reconstruction, per-domain `ContentPermission`, deterministic governing-tag selection
- `RithamApp/Ritham/Guidance/Views/AdjustedGuidanceBanner.swift` - Reusable embedded card: permission-checked catalog text, contraindicated list, streak-safety note, three reused disclaimer components
- `RithamApp/Ritham/Guidance/Views/GuidanceView.swift` - The real `.guidance` step screen, workout + nutrition sections
- `RithamApp/Ritham/Guidance/Views/NutritionGuidanceSection.swift` - Reference figures, DIET-02 swaps, DIET-03 education, food allergens, allergen-verification notice
- `RithamApp/Ritham/Guidance/GuidanceRegistration.swift` - Rewritten in place to register `GuidanceView` instead of the placeholder
- `RithamApp/Ritham/Cardio/Views/CardioSessionView.swift` - Embeds `AdjustedGuidanceBanner` for the workout domain above the session controls
- `RithamApp/Ritham/Strength/Views/StrengthSessionView.swift` - Embeds the same banner above every logging control
- `RithamApp/RithamTests/GuidanceViewTests.swift` - `GuidanceContextTests`/`InlineGuidanceTests`/`NutritionGuidanceTests` (17 tests total)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after adding `Guidance/Views/`

## Decisions Made
- `AdjustedGuidanceBanner` surfaces the never-triggers-streak-loss note independent of the permission branch (not nested inside the "content allowed" branch), since one of the five flagged tags (`heartDiseaseRecentEventOrSymptomatic`) has a zero-content workout permission and would otherwise lose that framing behind the referral message entirely
- `NutritionGuidanceSection` treats a `nil` stored `dietaryPattern` (profile never visited `DietPlanView`) as the one input that suppresses both the swap section and the education block, distinct from an explicitly-chosen `DietaryPattern.none` (omnivore), which still shows baseline swap examples once set
- `GuidanceContext.governingTag(for:)` centralizes "which tag's text should this domain show" (most restrictive `ContentPermission`, ties broken by `displayName`) so both the banner and the nutrition section select consistently without duplicating the logic

## Deviations from Plan

### Process deviation (documented, not a Rule 1-4 fix)

**TDD gate sequence not followed strictly per task.** Each task's tests and implementation were written together and verified passing in one pass, rather than a separate failing `test(...)` commit followed by a `feat(...)` commit. All three task commits are `feat(...)` commits that include both the implementation and its test suite, already passing at commit time. This diverges from this project's established RED/GREEN commit-split precedent (e.g. plan 02-13). No functional impact: every acceptance criterion and behavior assertion in the plan was verified via `xcodebuild test` before each commit.

### Auto-fixed Issues

None - no Rule 1/2/3 auto-fixes were needed; every behavior in the plan's task list was achievable via the read-first files' existing accessors.

---

**Total deviations:** 1 process deviation (TDD gate sequencing), 0 auto-fixed code issues.
**Impact on plan:** No scope creep, no correctness gap. The TDD gate deviation is documented for traceability only.

## Issues Encountered
None - all three `xcodebuild test -only-testing:` runs succeeded on the first attempt after each task's implementation, and the full `xcodebuild build` succeeded after Task 3.

## TDD Gate Compliance

Per-task RED (`test(...)`) / GREEN (`feat(...)`) commit split was not followed -- see "Deviations from Plan" above. All 17 new tests pass; TDD *coverage* was achieved (behavior list fully asserted), but the RED phase was not committed separately for any of the three tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- HEALTH-03, HEALTH-04, DIET-02, and DIET-03 all have a real, working, tested UI surface, closing out Phase 2's guidance-surfacing work (plans 02-04 through 02-07 built the data layer; this plan is its first UI consumer)
- `GuidanceContext`/`AdjustedGuidanceBanner` are now the reusable primitives any future adjusted-guidance surface (e.g. a Phase 3 Momentum screen that needs to explain a recovery-week adjustment) should compose, rather than re-deriving a gate result independently
- Two `human_judgment: true` coverage items remain for a future interactive/visual UAT pass (on-device rendering of the banner and the guidance screen were not screenshotted this session) -- flagged in the `coverage:` block above, not blocking, consistent with the project's existing no-touch-injection-tool constraint noted in `STATE.md`
- No blockers introduced; `StepBootstrap.swift`, `HealthDataStore.swift`, and `RithamModelContainer.swift` remain untouched by this plan, matching its own verification constraint

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*

## Self-Check: PASSED

All 8 created/modified source files and the SUMMARY.md itself verified present on disk; all
4 commits (`a26cdfb`, `36b3b3c`, `f2387bb`, `7339b02`) verified present in `git log`.
