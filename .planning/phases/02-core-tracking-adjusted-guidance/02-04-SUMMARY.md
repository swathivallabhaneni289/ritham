---
phase: 02-core-tracking-adjusted-guidance
plan: 04
subsystem: health-guidance
tags: [swift, spm, swift-testing, content-permission, workout-guidance, health-screening]

# Dependency graph
requires:
  - phase: 01-onboarding-safety-intake
    provides: ConditionTag (31-case vocabulary), ClearanceGate/GuidanceDomain/DomainGates, GateEscalation.baseGates/.escalate, ScreeningCopy.requiredBlockingMessage
provides:
  - ContentPermission (none/educationOnly/full, Comparable, mostRestrictive fold) — the content-layer axis GateEscalation's own comments name as missing from the three-level ClearanceGate
  - GuidanceCatalog.contentPermission(for:domain:) — exhaustive per-(ConditionTag, GuidanceDomain) lookup transcribed independently from docs/health-screening.md sections 2/3
  - GuidanceCatalog.resolvedPermission(for:domain:) — most-restrictive fold over a tag set, empty-set-to-none safe default
  - WorkoutGuidanceCatalog — section 2's adjustment/contraindicated/referral/streak-safety content, with the permission check enforced inside presentableAdjustment(for:) rather than at a view call site
affects: [02-07 (nutrition catalogs, depends on ContentPermission/GuidanceCatalog built here), 02-12 (views consuming presentableAdjustment), phase-3-momentum (reads neverTriggersStreakLoss)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Content-permission layer sits downstream of gate resolution: GuidanceCatalog reads ConditionTag directly and is transcribed independently from the rule tables' prose, never computed from ClearanceGate, so a required-blocking gate can still carry an educationOnly or none content permission depending on the row's own wording"
    - "Guidance-text catalogs enforce their own permission check internally (presentableAdjustment) rather than relying on every view call site to remember to check first — mirrors ClearanceGate's 'no averaging API' structural-safeguard discipline applied to content instead of gates"
    - "Unicode em/en dashes in transcribed clinical prose are rewritten to plain punctuation (period, comma, semicolon) at transcription time, following ScreeningCopy.swift's own precedent for this codebase's shipped strings — substance stays verbatim, house style is enforced"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift
    - RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift
    - RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift
  modified: []

key-decisions:
  - "ContentPermission.mostRestrictive folds via .min() (not .max()) since the enum's declaration order is ascending permissiveness (none < educationOnly < full), the inverse of ClearanceGate's ascending-restrictiveness order — the most restrictive permission is the smallest value here"
  - "Nutrition-domain 'recommended' gate rows are educationOnly only when the row's own prose forbids a personalized quantity (hypertension, heart disease, diabetes); rows that are 'recommended' for an unrelated reason — a standing allergy-verification flag, or deferring to an external clinician-prescribed plan — are declared full, since nothing in their prose blocks a quantity Ritham would compute"
  - "referralMessage aliases ScreeningCopy.requiredBlockingMessage rather than re-transcribing section 4.6, so the screening flow and the guidance catalog can never carry two diverging copies of the same required-blocking message"
  - "adjustment(for:)/contraindicated(for:) stay raw, undocumented-permission accessors for tests and for presentableAdjustment's own internal use; their doc comments direct every other caller to presentableAdjustment(for:), which is the only accessor that consults GuidanceCatalog.contentPermission before returning text"

patterns-established:
  - "Pattern: a content-permission enum independent from a clearance-gate enum, structurally prevented from being softened (Comparable + a fold-only API, no blend/average/upgrade), applied per (tag, domain) and folded most-restrictive across a tag set with an empty-set-to-none safe default"

requirements-completed: [HEALTH-03]

coverage:
  - id: D1
    description: "ContentPermission (none/educationOnly/full) exists as an independent axis from ClearanceGate, with a structural mostRestrictive fold and no averaging/blending/upgrading operation"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift#GuidanceCatalogTests (9 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "GuidanceCatalog.contentPermission(for:domain:) declares an exhaustive, independently-transcribed permission for every ConditionTag/GuidanceDomain pair, distinguishing zero-content tags (kidney disease, pregnancy-complicated, other-serious-condition) from education-permitted tags (under-18, hypertension-uncontrolled, postpartum-uncomplicated) at the same clearance-gate level"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift#under18MinorVersusKidneyDisease, #hypertensionUncontrolledIsEducationOnlyForNutrition"
        status: pass
    human_judgment: false
  - id: D3
    description: "resolvedPermission(for:domain:) folds a tag set to its most restrictive member and resolves an empty tag set to .none, treating no-screening-data as unscreened rather than cleared"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift#resolvedPermissionOfEmptySetIsNone, #resolvedPermissionFoldsToMostRestrictive"
        status: pass
    human_judgment: false
  - id: D4
    description: "WorkoutGuidanceCatalog carries section 2's adjustment, contraindicated, referral, and streak-safety content, with em-dash source cells resolving to nil and the presentable accessor enforcing the workout content permission before returning any personalized text"
    requirement: "HEALTH-03"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift#WorkoutGuidanceCatalogTests (7 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Transcribed clinical wording (substance) matches docs/health-screening.md section 2, with only Unicode dash characters rewritten to house style — a human/counsel-review judgment call this plan cannot itself finalize (LAUNCH-01 gates the substance review at Phase 5)"
    requirement: "HEALTH-03"
    verification: []
    human_judgment: true
    rationale: "62 permission classifications and 31 rows of transcribed clinical prose involve judgment calls about which rule-table sentences constitute an explicit content restriction vs. an unrelated caveat; automated tests confirm internal consistency and the specific behaviors the plan names, but a full line-by-line diff against the source table's substance benefits from a second human or LAUNCH-01 counsel pass before ship."

# Metrics
duration: 25min
completed: 2026-09-05
status: complete
---

# Phase 02 Plan 04: Content-Permission Layer and Workout Guidance Catalog Summary

**Added a content-permission axis (`ContentPermission`: none/educationOnly/full) independent from the existing three-level `ClearanceGate`, plus a 31-row workout guidance text catalog transcribed from `docs/health-screening.md` section 2, both gated by an internal permission check rather than a view-layer convention.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-09-05T09:25:54Z
- **Tasks:** 2 completed (both TDD)
- **Files modified:** 3 (2 created source, 1 created test)

## Accomplishments

- `ContentPermission` enum (`.none`, `.educationOnly`, `.full`) with `Comparable` ordering and a `mostRestrictive` fold, mirroring `ClearanceGate`'s "no averaging API" structural safeguard for the content layer.
- `GuidanceCatalog.contentPermission(for:domain:)` — an exhaustive, no-`default` switch over all 31 `ConditionTag` cases x 2 `GuidanceDomain` values, transcribed independently from section 2 (workout) and section 3 (nutrition) prose rather than computed from `ClearanceGate`. Confirmed distinguishing case: `under18Minor` and `hypertensionUncontrolledOrUnsure` are `.educationOnly` for nutrition while `kidneyDiseaseOrDialysis` is `.none`, all at the same `requiredBlocking` clearance-gate level.
- `GuidanceCatalog.resolvedPermission(for:domain:)` folds a tag set to its most restrictive member and resolves an empty tag set to `.none` (no screening data means unscreened, never cleared).
- `WorkoutGuidanceCatalog` — section 2's Workout Adjustment and Contraindicated/Avoid columns for all 31 tags, `referralMessage` (aliased to `ScreeningCopy.requiredBlockingMessage`), `neverTriggersStreakLoss(_:)` for the five HEALTH-03-named tags, and `presentableAdjustment(for:)` as the sole permission-checked accessor views should call.
- Full `RithamCore` package suite: 261/261 tests passing.

## Task Commits

Both tasks followed strict RED/GREEN TDD, verified by temporarily withholding the implementation source files so the RED commits are genuine compile failures, not just unrun assertions:

1. **Task 1: ContentPermission and the exhaustive per-tag, per-domain lookup**
   - `478b89d` (test) — RED: `GuidanceCatalogTests` fails to compile (`ContentPermission`/`GuidanceCatalog` do not exist)
   - `dcbe688` (feat) — GREEN: `ContentPermission.swift` implemented, 9/9 tests pass
2. **Task 2: Workout guidance text catalog**
   - `27e8f23` (test) — RED: `WorkoutGuidanceCatalogTests` fails to compile (`WorkoutGuidanceCatalog` does not exist)
   - `dec86e5` (feat) — GREEN: `WorkoutGuidanceCatalog.swift` implemented, 7/7 tests pass; full package suite 261/261

**Plan metadata:** (this commit, see below)

## Files Created/Modified

- `RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift` — `ContentPermission` enum, `mostRestrictive`, `GuidanceCatalog.contentPermission(for:domain:)`, `.resolvedPermission(for:domain:)`
- `RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift` — `adjustment(for:)`, `contraindicated(for:)`, `referralMessage`, `neverTriggersStreakLoss(_:)`, `presentableAdjustment(for:)`
- `RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift` — `GuidanceCatalogTests` (9 tests) and `WorkoutGuidanceCatalogTests` (7 tests) suites

## Decisions Made

- **`mostRestrictive` folds via `.min()`, not `.max()`.** `ContentPermission`'s declaration order is ascending *permissiveness* (`none < educationOnly < full`) — the inverse of `ClearanceGate`'s ascending *restrictiveness* order (`none < recommended < requiredBlocking`). The most restrictive permission is therefore the smallest value, and `permissions.min() ?? .none` naturally also satisfies the empty-input-returns-`.none` requirement.
- **Nutrition `recommended`-gate rows split on whether the row restricts a quantity.** Most `recommended` nutrition rows (hypertension, heart disease, diabetes) are `.educationOnly` because their own prose explicitly forbids a personalized number. Three rows — `eatingDisorderSelfReportedNegativeScreen` (numeric targets are opt-in, not forbidden), `severeFoodAllergy` (a standing verification flag, not a quantity restriction), and `clinicianPrescribedDietOrMealPlan` (defers to an external plan rather than restricting a Ritham-computed number) — are declared `.full` instead. This was caught and corrected during review before implementation; a blanket "`recommended` gate always means `educationOnly`" formula would have misclassified all three.
- **`referralMessage` aliases `ScreeningCopy.requiredBlockingMessage`** rather than re-transcribing section 4.6 into a second copy. One string, one place for LAUNCH-01 counsel review to read, no risk of the two copies drifting apart over future edits.
- **Unicode em/en dashes in transcribed clinical prose are rewritten to plain punctuation** (period, comma, "and"), following `ScreeningCopy.swift`'s own established precedent in this codebase for its shipped string set. No wording was added, removed, or reworded beyond that substitution — verified by comparing several transformed sentences against the source table.

## Deviations from Plan

None — plan executed as written. The nutrition-`recommended`-tier classification question above was resolved during implementation (not after discovering a bug), following the plan's own instruction to transcribe permissions independently from the rule tables' prose rather than compute them from the gate value; it is documented here as a decision rather than a deviation since no code was written incorrectly and then fixed.

## Known Stubs

None. Both catalogs are fully wired: `WorkoutGuidanceCatalog.presentableAdjustment(for:)` is a complete, permission-checked accessor with no placeholder branches, and every `ConditionTag` case is covered by both files' exhaustive switches (verified by table-driven tests iterating `ConditionTag.allCases`).

## Threat Flags

None beyond what this plan's own `<threat_model>` already names (T-02-01, T-02-12, T-02-13, T-02-14). No new network endpoints, auth paths, or schema changes were introduced — this plan added pure, Foundation-only, in-memory lookup logic and string catalogs.

## Issues Encountered

None. `RithamCore/Scripts/test-core.sh --filter <SuiteName>` worked as expected for both TDD cycles, and the full package suite (`./Scripts/test-core.sh` with no filter) confirmed no regression across the pre-existing 22 suites.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 02-07 (nutrition catalogs and dietary-pattern content) can now build directly on `ContentPermission` and `GuidanceCatalog`, which this plan completed as its explicit dependency.
- Plan 02-12's views should call `WorkoutGuidanceCatalog.presentableAdjustment(for:)` exclusively; the raw `adjustment(for:)`/`contraindicated(for:)` accessors are documented as test/internal-use-only and should not be wired to any view.
- Phase 3's Momentum feature can read `WorkoutGuidanceCatalog.neverTriggersStreakLoss(_:)` directly rather than re-deriving the five-tag list.
- `RithamCore/Sources/RithamCore/Screening/` was read but never modified (`git diff --stat` against Screening/ across this plan's commit range is empty), confirming Phase 1's gating logic stayed untouched as the plan required.
- The transcribed wording in `WorkoutGuidanceCatalog.swift`, like `ScreeningCopy.swift`, remains pending LAUNCH-01 counsel review before Phase 5 launch; this plan does not gate on that review per the roadmap's own sequencing.

## Self-Check: PASSED

- FOUND: RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift
- FOUND: RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift
- FOUND: RithamCore/Tests/RithamCoreTests/GuidanceCatalogTests.swift
- FOUND: commit 478b89d
- FOUND: commit dcbe688
- FOUND: commit 27e8f23
- FOUND: commit dec86e5

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-05*
