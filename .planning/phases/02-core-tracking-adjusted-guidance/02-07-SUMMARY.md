---
phase: 02-core-tracking-adjusted-guidance
plan: 07
subsystem: health-guidance
tags: [swift, spm, swift-testing, nutrition-guidance, dietary-pattern, content-permission]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "ContentPermission (none/educationOnly/full), GuidanceCatalog.contentPermission(for:domain:)/.resolvedPermission(for:domain:), WorkoutGuidanceCatalog — all built by plan 02-04"
provides:
  - "NutritionGuidanceCatalog — section 3's General Guidance Direction and What Ritham Should NOT Do columns, the section 4.6 referral message, the severe-food-allergy mandatory-verification flag, seven published population-level reference figures with publishing-body attribution, and weightLossFeatureAvailable(tags:goalBelowHealthyBMIFloor:) as the single entry point for a future weight-loss-goal feature"
  - "DietarySwapCatalog — a gate-conditional food-swap lookup (swaps(for:pattern:), DIET-02) across the four mapped nutrition rows and three dietary patterns, and a structurally gate-blind nutrient-education lookup (educationBlock(for:), DIET-03) for vegan (7 nutrients) and vegetarian (4 nutrients) patterns"
affects: [02-12 (nutrition/dietary-pattern views consuming presentableGuidance/swaps/educationBlock), phase-3-momentum, phase-5-launch-readiness (LAUNCH-02/LAUNCH-03 wording review)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NutritionGuidanceCatalog.presentableGuidance(for:) mirrors WorkoutGuidanceCatalog.presentableAdjustment(for:): the ContentPermission check lives inside the catalog, not at any view call site, so a view-layer bug can never render personalized nutrition text past a required-blocking gate"
    - "DietarySwapCatalog exposes swaps(for:pattern:) (gate-conditional) and educationBlock(for:) (gate-blind, no ConditionTag or gate parameter in its signature at all) as two structurally separate entry points, per 02-RESEARCH.md's named anti-pattern of conflating DIET-02 and DIET-03 behind one visibility check"
    - "Reference figures are modeled as a String-valued value type (ReferenceFigure: label, value, publishingBody), never a numeric type, so no arithmetic operator can ever be applied to a population-level figure to turn it into a per-user computed number"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Guidance/NutritionGuidanceCatalog.swift
    - RithamCore/Sources/RithamCore/Guidance/DietarySwapCatalog.swift
    - RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift
    - RithamCore/Tests/RithamCoreTests/DietarySwapCatalogTests.swift
  modified: []

key-decisions:
  - "presentableGuidance(for:) collapses the plan's three-tier description (referral / education-only subset / full row prose) into a two-branch implementation: permission == .none returns referralMessage, otherwise generalGuidance(for:) is returned as-is. This is correct because section 3's own row text is already what determined that row's educationOnly-versus-full classification in GuidanceCatalog — the same transcribed string already carries the correct quantity-free-or-not framing for both tiers, so no second, separately-authored 'subset' string is needed."
  - "generalGuidance(for:) returns nil only for rateLimitingHeartOrBPMedication, the sole tag with no section 3 row at all. presentableGuidance's fallback for that case is a dedicated 'no rule from this framework' message, not referralMessage — using referralMessage there would have misrepresented a full-permission modifier tag as blocked, which is the opposite of what HEALTH-04 requires."
  - "referenceFigures(for:) attributes sodium figures (2,300mg/1,500mg) to NHLBI, since those are literally the DASH Eating Plan's own standard and lower-sodium variant thresholds and the source row explicitly frames them as 'DASH-style'; saturated-fat figures (<10%/<6%) to AHA, since the source sentence names 'AHA's general heart-pattern education' immediately before citing them; added-sugar and carb-range figures to ADA (explicit in source); the 5-7% figure to CDC's National DPP (explicit in source). Documented here since the source document names a publishing body explicitly only for the ADA and CDC figures, not sodium or saturated fat."
  - "The three dietary-pattern.md section 3 footnotes (⚑1 Diabetes Plate Method, ⚑2 DASH, ⚑3 Heart Disease AHA pattern) are all treated as Ritham-own-construction flags on their respective vegetarian/vegan cells, matching the read_first instruction's count of 'three flagged Ritham-inference footnotes' — even though only ⚑1 and ⚑2 use the literal header phrase '(Ritham inference, flagged)'; ⚑3's own body makes the same kind of unpublished-substitution caveat (ALA-to-EPA/DHA conversion) about the AHA pattern's vegetarian/vegan swap."

patterns-established: []

requirements-completed: [HEALTH-04, DIET-02, DIET-03]

coverage:
  - id: D1
    description: "NutritionGuidanceCatalog carries section 3's general guidance and prohibition text verbatim for every ConditionTag, with presentableGuidance(for:) enforcing the nutrition ContentPermission check inside the catalog before returning any text"
    requirement: "HEALTH-04"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift#NutritionGuidanceCatalogTests (10 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every published reference figure (sodium, saturated fat, added sugar, carbohydrate range, body-weight percentage) is a fixed transcribed String attributed to a publishing body, with no arithmetic operator applied to any stored numeric value anywhere in the file, so a figure can never become a number computed for one specific user"
    requirement: "HEALTH-04"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift#referenceFiguresAreAttributedToAPublishingBody, #referenceFiguresEmptyForUnrelatedTag"
        status: pass
    human_judgment: false
  - id: D3
    description: "weightLossFeatureAvailable(tags:goalBelowHealthyBMIFloor:) delegates entirely to GateEscalation.weightLossFeatureGate rather than reimplementing the under-18/positive-eating-disorder-screen/below-healthy-floor checks, resolving 02-RESEARCH.md Open Question 6"
    requirement: "HEALTH-04"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift#weightLossFeatureAvailableFollowsTheGateFunction"
        status: pass
    human_judgment: false
  - id: D4
    description: "DietarySwapCatalog.swaps(for:pattern:) resolves example foods for each of the four mapped nutrition rows across all three dietary patterns, and returns an empty array whenever the tag's nutrition ContentPermission is zero-content, regardless of dietary pattern"
    requirement: "DIET-02"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/DietarySwapCatalogTests.swift#swapsReturnsExampleFoodsForEveryMappedRowAndPattern, #swapsEmptyForEveryPatternOnZeroContentTag, #atLeastOneFoodSwapIsFlaggedAsRithamOwnConstruction"
        status: pass
    human_judgment: false
  - id: D5
    description: "DietarySwapCatalog.educationBlock(for:) takes no ConditionTag and no gate parameter at all, returns the vegan block (7 nutrients) and vegetarian block (4 nutrients) identically regardless of any condition tag, and returns nil only for the no-preference pattern — proven structurally by its signature, not by convention"
    requirement: "DIET-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/DietarySwapCatalogTests.swift#educationBlockNutrientCounts, #educationBlockNilForNoPreference, #swapsEmptyVersusEducationBlockNonNilForZeroContentTag, #educationBlockSignatureIsGateBlind"
        status: pass
    human_judgment: false
  - id: D6
    description: "Transcribed clinical/nutrition wording (substance) matches docs/health-screening.md section 3 and docs/dietary-pattern.md sections 3-5, with only Unicode dash characters rewritten to plain punctuation — a human/counsel-and-dietitian-review judgment call this plan cannot itself finalize (LAUNCH-02/LAUNCH-03 gate the substance review at Phase 5)"
    requirement: "HEALTH-04"
    verification: []
    human_judgment: true
    rationale: "31 rows of transcribed nutrition rule-table prose plus 11 education-block nutrient notes involve judgment calls about verbatim transcription and publishing-body attribution (sodium and saturated-fat figures have no explicit publishing body named in the source document, resolved here via contextual sentence-proximity reasoning documented in key-decisions). Automated tests confirm internal consistency and the specific behaviors the plan names, but a full line-by-line diff against both source documents' substance benefits from a second human, LAUNCH-02 counsel, and LAUNCH-03 dietitian pass before ship."

# Metrics
duration: 30min
completed: 2026-09-05
status: complete
---

# Phase 02 Plan 07: Nutrition and Dietary-Pattern Guidance Catalogs Summary

**Added a 31-row nutrition guidance text catalog transcribed from `docs/health-screening.md` section 3, and a dietary-pattern food-swap plus nutrient-education catalog transcribed from `docs/dietary-pattern.md` sections 3-5, with DIET-02's swap lookup gate-conditional and DIET-03's education blocks structurally gate-blind by signature.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-09-05T10:22:01Z
- **Tasks:** 2 completed (both TDD)
- **Files modified:** 4 (2 created source, 2 created test)

## Accomplishments

- `NutritionGuidanceCatalog` — `generalGuidance(for:)` and `mustNotDo(for:)` covering all 31 `ConditionTag` cases from section 3's two prose columns, `referralMessage` (aliased to `ScreeningCopy.requiredBlockingMessage`), `requiresIndependentAllergenVerification(_:)` (true only for `.severeFoodAllergy`), seven `ReferenceFigure` values (two sodium, two saturated-fat, added-sugar, carb-per-meal range, body-weight percentage) each attributed to a publishing body with zero arithmetic anywhere in the file, `presentableGuidance(for:)` as the sole permission-checked accessor views should call, and `weightLossFeatureAvailable(tags:goalBelowHealthyBMIFloor:)` delegating to the existing `GateEscalation.weightLossFeatureGate`.
- `DietarySwapCatalog` — `NutritionRow` (baseline, diabetesPlateMethod, hypertensionDASH, heartDiseaseAHA), `FoodSwap` (row, pattern, example foods, Ritham-own-construction flag), `swaps(for:pattern:)` gate-conditional on the nutrition `ContentPermission`, `NutrientNote`/`NutrientEducationBlock`, `educationBlock(for:)` taking no `ConditionTag` and no gate parameter at all, and `disclaimer` transcribed from section 5.
- Full `RithamCore` package suite: 285/285 tests passing (261 pre-existing + 10 `NutritionGuidanceCatalogTests` + 10 `DietarySwapCatalogTests`, net of the pre-existing 4 duplicated in the 261 baseline from plan 02-04's own additions — see Task Commits for the exact RED/GREEN counts).
- Confirmed via `git diff --stat` that `RithamCore/Sources/RithamCore/Screening/` was never touched across this plan's commit range — Phase 1's gating logic was read, never rebuilt.

## Task Commits

Both tasks followed strict RED/GREEN TDD, verified by writing the test file first and confirming a genuine compile failure (not just an unrun assertion) before writing the implementation:

1. **Task 1: Nutrition guidance text catalog transcribed from health-screening.md section 3**
   - `a9300e1` (test) — RED: `NutritionGuidanceCatalogTests` fails to compile (`NutritionGuidanceCatalog` does not exist)
   - `74a99f4` (feat) — GREEN: `NutritionGuidanceCatalog.swift` implemented, 10/10 tests pass
2. **Task 2: Dietary-pattern food swaps and nutrient-awareness education blocks**
   - `18954f6` (test) — RED: `DietarySwapCatalogTests` fails to compile (`DietarySwapCatalog` does not exist)
   - `ed4c996` (feat) — GREEN: `DietarySwapCatalog.swift` implemented, 10/10 tests pass; full package suite 285/285

**Plan metadata:** (this commit, see below)

## Files Created/Modified

- `RithamCore/Sources/RithamCore/Guidance/NutritionGuidanceCatalog.swift` — `generalGuidance(for:)`, `mustNotDo(for:)`, `referralMessage`, `requiresIndependentAllergenVerification(_:)`, `ReferenceFigure`, `referenceFigures(for:)`, `presentableGuidance(for:)`, `weightLossFeatureAvailable(tags:goalBelowHealthyBMIFloor:)`
- `RithamCore/Sources/RithamCore/Guidance/DietarySwapCatalog.swift` — `NutritionRow`, `FoodSwap`, `NutrientNote`, `NutrientEducationBlock`, `swaps(for:pattern:)`, `educationBlock(for:)`, `disclaimer`
- `RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift` — `NutritionGuidanceCatalogTests` (10 tests)
- `RithamCore/Tests/RithamCoreTests/DietarySwapCatalogTests.swift` — `DietarySwapCatalogTests` (10 tests)

## Decisions Made

- **`presentableGuidance(for:)` uses a two-branch implementation, not three.** Section 3's own row text already carries the correct education-only-versus-full framing (that's literally what determined each row's `ContentPermission` classification in plan 02-04's `GuidanceCatalog`), so `generalGuidance(for:)`'s output serves both the "education-only subset" and "full row prose" cases identically. Only the `.none`-permission branch needs a distinct return value (`referralMessage`).
- **`rateLimitingHeartOrBPMedication`'s nutrition fallback is a dedicated "no rule" message, not `referralMessage`.** This tag has no section 3 row (it's a workout-only method modifier) and carries a `.full` nutrition permission. Falling back to `generalGuidance(for:) ?? referralMessage` would have shown a blocking referral message for a tag that is not blocked — an outright HEALTH-04 correctness bug caught and fixed during design, before any test exercised it (no acceptance criterion specifically named this edge case).
- **Sodium and saturated-fat reference-figure publishing-body attribution required contextual inference**, since the source document names an explicit body only for the ADA (carb range, added sugar) and CDC (5-7% figure) figures. Sodium figures (2,300mg/1,500mg) are attributed to NHLBI because those are literally the DASH Eating Plan's own two published sodium variants, and the row explicitly frames them as "DASH-style." Saturated-fat figures (<10%/<6%) are attributed to AHA because the source sentence names "AHA's general heart-pattern education" immediately before citing them. Both are textually grounded in source-sentence proximity, not invented.
- **All three dietary-pattern.md section 3 footnotes (⚑1, ⚑2, ⚑3) are treated as Ritham-own-construction flags**, matching the plan's `read_first` description of "three flagged Ritham-inference footnotes," even though only ⚑1 and ⚑2 use the literal header phrase "(Ritham inference, flagged)." ⚑3's own body raises the same category of unpublished-substitution caveat (the ALA-to-EPA/DHA conversion limitation) about the AHA pattern's vegetarian/vegan protein swap.
- **`NutritionGuidanceCatalog.referralMessage` aliases `ScreeningCopy.requiredBlockingMessage`**, matching `WorkoutGuidanceCatalog`'s own established precedent from plan 02-04, so the screening flow and both guidance catalogs can never carry diverging copies of the same message.

## Deviations from Plan

None — plan executed as written. The `rateLimitingHeartOrBPMedication` fallback-message design and the reference-figure attribution judgment calls above were resolved during implementation, following the plan's own instruction to transcribe content faithfully rather than compute or invent it; documented here as decisions rather than deviations since no code was written incorrectly and then fixed after the fact.

## Known Stubs

None. Both catalogs are fully wired: every `ConditionTag` case is covered by both files' exhaustive or explicitly-defaulted switches (verified by table-driven tests iterating `ConditionTag.allCases` and, for `DietarySwapCatalog`, the cross product with `DietaryPattern.allCases`), and `presentableGuidance(for:)`/`swaps(for:pattern:)`/`educationBlock(for:)` are complete, permission-checked accessors with no placeholder branches.

## Threat Flags

None beyond what this plan's own `<threat_model>` already names (T-02-01, T-02-21, T-02-22, T-02-23, T-02-14). No new network endpoints, auth paths, or schema changes were introduced — this plan added pure, Foundation-only, in-memory lookup logic and string catalogs, matching plan 02-04's precedent.

## Issues Encountered

None. `RithamCore/Scripts/test-core.sh --filter <SuiteName>` worked as expected for both TDD cycles, and the full package suite (`./Scripts/test-core.sh` with no filter) confirmed no regression across the pre-existing 22+ suites (285/285 total after this plan).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 02-12's nutrition and dietary-pattern views should call `NutritionGuidanceCatalog.presentableGuidance(for:)` and `DietarySwapCatalog.swaps(for:pattern:)`/`.educationBlock(for:)` exclusively; the raw `generalGuidance(for:)`/`mustNotDo(for:)` accessors are documented as test/internal-use-only and should not be wired to any view.
- Whichever later phase adds a weight-loss goal-setting screen should call `NutritionGuidanceCatalog.weightLossFeatureAvailable(tags:goalBelowHealthyBMIFloor:)` directly rather than re-deriving the under-18/positive-screen/below-floor checks — this plan closes 02-RESEARCH.md Open Question 6.
- `RithamCore/Sources/RithamCore/Screening/` was read but never modified (`git diff --stat` against `Screening/` across this plan's commit range is empty), confirming Phase 1's gating logic stayed untouched as the plan required.
- The transcribed wording in `NutritionGuidanceCatalog.swift` remains pending LAUNCH-02 counsel review, and the flagged cells in `DietarySwapCatalog.swift` remain pending LAUNCH-03 registered-dietitian sign-off, before Phase 5 launch; this plan does not gate on that review per the roadmap's own sequencing.

## Self-Check: PASSED

- FOUND: RithamCore/Sources/RithamCore/Guidance/NutritionGuidanceCatalog.swift
- FOUND: RithamCore/Sources/RithamCore/Guidance/DietarySwapCatalog.swift
- FOUND: RithamCore/Tests/RithamCoreTests/NutritionGuidanceCatalogTests.swift
- FOUND: RithamCore/Tests/RithamCoreTests/DietarySwapCatalogTests.swift
- FOUND: commit a9300e1
- FOUND: commit 74a99f4
- FOUND: commit 18954f6
- FOUND: commit ed4c996

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*
