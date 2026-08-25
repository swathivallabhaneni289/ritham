---
phase: 01-onboarding-safety-intake
plan: 03
subsystem: ios-core
tags: [swift, swift-testing, domain-modeling, health-screening]

# Dependency graph
requires:
  - phase: 01-01
    provides: "RithamCore Swift package, toolchain-adaptive test-core.sh, copy catalogs"
provides:
  - "ConditionTag — 31-case enum covering every §2/§3 condition tag, with displayName and ageDerivedTags(forAge:)"
  - "ClearanceGate — none/recommended/requiredBlocking, Comparable-ordered, mostRestrictive(_:) selector, no averaging API"
  - "GuidanceDomain + DomainGates — pairs a gate with the workout/nutrition domain it governs"
  - "DietaryPattern — structurally isolated from the gate type graph, per DIET-01"
  - "ScreeningAnswers vocabulary — YesNo, YesNoUnsure (isCautiousBranch), and one closed enum per §1.4 follow-up's literal option list"
  - "ChecklistItem/ChecklistCategory/ChecklistSelection — the §1.3 condition checklist with the None-of-the-above exclusion enforced in the sole mutator"
  - "SCOFFResponses — yesCount/isPositiveScreen at the documented >=2 threshold, isTriggered(by:), no displayable score"
  - "ConditionTagValidity/TagValidity/ProfessionalClearance — the pure twelve-month validity rule (HEALTH-02), deterministic and SwiftData-free"
affects: [01-06, 01-07, 01-09, 01-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Screening domain vocabulary lives under Sources/RithamCore/Screening/ as pure Foundation types with no persistence or view dependency, so HEALTH-06's engine (plan 01-06) is pure rule transcription against a settled contract"
    - "Fixed Calendar(identifier: .gregorian) + explicit UTC TimeZone, dates built from DateComponents, for deterministic date-boundary tests independent of the host machine's locale/timezone"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Screening/ConditionTag.swift
    - RithamCore/Sources/RithamCore/Screening/ClearanceGate.swift
    - RithamCore/Sources/RithamCore/Screening/DietaryPattern.swift
    - RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift
    - RithamCore/Sources/RithamCore/Screening/SCOFF.swift
    - RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift
    - RithamCore/Tests/RithamCoreTests/ClearanceGateTests.swift
    - RithamCore/Tests/RithamCoreTests/ScreeningAnswersTests.swift
    - RithamCore/Tests/RithamCoreTests/ConditionTagExpiryTests.swift
  modified: []

key-decisions:
  - "Implemented expiry(from:calendar:) as the primitive (calendar.date(byAdding: .month, value: 12, to:)) instead of the plan's literal `validityWindow: TimeInterval` — a fixed-seconds TimeInterval cannot represent a twelve-month window without reintroducing the leap-year/DST drift the rule exists to avoid. This is the plan's own preferred fallback wording, and the acceptance criteria (byAdding grep) already anticipate it. (Rule 1)"
  - "Split §1.3's checklist into nine condition categories by treating Pregnancy and Postpartum as separate categories (not combined under one heading) — §1.4 branches on 'Currently pregnant' and 'Postpartum' independently, so this reading matches the functional consumer, and it's the only split that yields nine categories total as the plan's prose requires"
  - "Added a tenth ChecklistCategory case, `none`, as a documented sentinel for ChecklistItem.noneOfTheAbove, since it isn't one of the nine condition categories but the plan's `category: ChecklistCategory` property is non-optional and must still resolve for every case"
  - "ConditionTag.under18Minor is representable (transcribed from §2/§3) but has no producer yet in RithamCore — ageDerivedTags(forAge:) is deliberately scoped to the 65+ tag only, per the plan's own pinned test (ageDerivedTags(forAge: 13) == []). Documented on the case itself; tracked as an open gap for plan 01-06/01-07/01-11 to wire up (likely from Q0's raw age at the same call site that sets MINOR-01's 13+ floor, but as a separate boolean check, never through ageDerivedTags)"

patterns-established:
  - "Pattern: safety-critical enums that must never gain a value-loosening case (ClearanceGate's absent averaging API, TagValidity's absent expired-without-restriction case) enforce the invariant by omission — the missing operation/case is the safeguard, documented with a comment warning a future reader not to add it back"

requirements-completed: [HEALTH-01, HEALTH-02, DIET-01]

coverage:
  - id: D1
    description: "Every condition tag in docs/health-screening.md §2/§3's Condition Tag column is representable as a ConditionTag case, with a unique, non-empty user-facing displayName and an independent age-derived-tag lookup"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ClearanceGateTests.swift (10 tests: displayName non-empty/unique, ageDerivedTags boundaries)"
        status: pass
    human_judgment: false
  - id: D2
    description: "ClearanceGate is Comparable-ordered (none < recommended < requiredBlocking) with a mostRestrictive(_:) selector and no averaging/blending/downgrade API; DomainGates pairs a gate with its workout/nutrition domain; DietaryPattern is structurally unreferenced by the gate type graph"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ClearanceGateTests.swift (ordering, mostRestrictive, DomainGates subscript tests)"
        status: pass
      - kind: other
        ref: "grep -vE comment-stripped ClearanceGate.swift | grep -c DietaryPattern == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every questionnaire answer type is a closed enum with no free-text String payload (only enum RawValue identity); YesNoUnsure.isCautiousBranch expresses HEALTH-06's 'Not sure resolves to the more cautious branch' once; ChecklistSelection structurally enforces the None-of-the-above exclusion"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ScreeningAnswersTests.swift (13 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "SCOFF scores at the documented >=2-yes positive-screen threshold, gated by isTriggered(by:) on the eating-disorder-history checklist item, with no displayable score/label surface (no CustomStringConvertible, no display-name/summary property)"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ScreeningAnswersTests.swift (SCOFF threshold and trigger tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The twelve-month condition-tag validity boundary, the edit-resets-the-window rule, the non-blocking re-screen signal, and the professional-clearance re-prompt are pure, deterministic, and tested against explicit boundary dates with no SwiftData dependency; TagValidity has exactly two cases and no case drops the restriction"
    requirement: "HEALTH-02"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ConditionTagExpiryTests.swift (9 tests)"
        status: pass
      - kind: other
        ref: "cd RithamCore && ./Scripts/test-core.sh (full suite: 46 tests, 6 suites, green)"
        status: pass
    human_judgment: false
  - id: D6
    description: "DietaryPattern is representable with no path into gate resolution, per DIET-01"
    requirement: "DIET-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ClearanceGateTests.swift + isolation grep check"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-25
status: complete
---

# Phase 01 Plan 03: Screening Domain Vocabulary Summary

**The screening questionnaire's full type vocabulary — 31 condition tags, an orderable three-level clearance gate with no averaging API, every fixed-choice answer type, SCOFF scoring, and a leap-year-safe twelve-month tag validity rule, all unit-tested with no Xcode installed.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3
- **Files modified:** 9 (all created)

## Accomplishments
- Transcribed all 31 condition tags from `docs/health-screening.md` §2/§3 into `ConditionTag`, with a user-facing `displayName` (D-11/D-12) and an `ageDerivedTags(forAge:)` lookup kept independent of MINOR-01's 13+ eligibility floor
- Built `ClearanceGate` as a `Comparable`-ordered three-level enum with a `mostRestrictive(_:)` selector and — deliberately — no averaging, blending, or downgrade operation of any kind, so HEALTH-06's "most restrictive wins" rule is unimplementable to violate at the type level; paired it with `GuidanceDomain`/`DomainGates` so a gate is always scoped to workout or nutrition, never app access as a whole
- Isolated `DietaryPattern` in its own file, structurally unreferenced anywhere in the gate type graph, per DIET-01
- Modeled every §1.2/§1.4 fixed-choice answer as a closed enum (`YesNo`, `YesNoUnsure` with `isCautiousBranch`, `BloodPressureControl`, `RhythmControl`, `SurgicalClearance`, `PostpartumWeeks`) with zero free-text `String` payloads anywhere
- Built the §1.3 condition checklist (`ChecklistItem`/`ChecklistCategory`/`ChecklistSelection`) with the "None of the above clears everything else" rule enforced inside the selection's sole mutator, so no caller can construct a contradictory state
- Implemented `SCOFFResponses` at the documented ≥2-yes positive-screen threshold, gated to only the users who select the eating-disorder-history checklist item (D-10), with no `CustomStringConvertible` or display/summary property so a score can never leak to a view (§1.5)
- Implemented the twelve-month `ConditionTagValidity` rule as pure, deterministic date arithmetic — `TagValidity` has exactly two cases and no case that drops a restriction (D-08), the edit-resets-the-window rule (D-09/§1.6) is a separate `editedAt` parameter, `isReScreenDue` is documented as non-blocking only (D-07), and `ProfessionalClearance` models the "talked to a professional" toggle as a dated grant rather than a standing boolean

## Task Commits

Each task was committed atomically:

1. **Task 1: Condition tags and an orderable clearance gate** - `fd67fe8` (feat)
2. **Task 2: Fixed-choice answer types and SCOFF scoring** - `cab4cc4` (feat)
3. **Task 3: The twelve-month condition-tag validity rule** - `c7d9b6d` (feat)
4. **Follow-up: document under18Minor's missing producer** - `fa78053` (docs)

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Screening/ConditionTag.swift` - 31-case `ConditionTag` enum, `displayName`, `ageDerivedTags(forAge:)`
- `RithamCore/Sources/RithamCore/Screening/ClearanceGate.swift` - `ClearanceGate`, `mostRestrictive(_:)`, `GuidanceDomain`, `DomainGates`
- `RithamCore/Sources/RithamCore/Screening/DietaryPattern.swift` - `DietaryPattern`, isolated with DIET-01's rationale in the header
- `RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift` - `YesNo`, `YesNoUnsure`, per-follow-up enums, `ChecklistItem`/`ChecklistCategory`/`ChecklistSelection`, `ScreeningAnswers`
- `RithamCore/Sources/RithamCore/Screening/SCOFF.swift` - `SCOFFResponses`, `yesCount`, `isPositiveScreen`, `isTriggered(by:)`
- `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift` - `TagValidity`, `ConditionTagValidity`, `ProfessionalClearance`
- `RithamCore/Tests/RithamCoreTests/ClearanceGateTests.swift` - 10 tests
- `RithamCore/Tests/RithamCoreTests/ScreeningAnswersTests.swift` - 13 tests
- `RithamCore/Tests/RithamCoreTests/ConditionTagExpiryTests.swift` - 9 tests

## Decisions Made
- Derived `expiry(from:calendar:)` from a private months constant instead of the plan's literal `validityWindow: TimeInterval`, since a fixed-seconds `TimeInterval` cannot represent "twelve months" without the leap-year/DST drift the rule exists to prevent — see Deviations below
- Split the checklist into nine categories by treating Pregnancy and Postpartum separately, matching how §1.4 branches on them independently
- Added a tenth `ChecklistCategory.none` sentinel case for `noneOfTheAbove`, since `category` is a non-optional property and `noneOfTheAbove` isn't one of the nine real condition categories
- Left `ConditionTag.under18Minor` without a producer, per the plan's own pinned test (`ageDerivedTags(forAge: 13)` must return `[]`) — documented on the case as an open gap rather than silently wiring it in a way that would contradict the test

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `validityWindow: TimeInterval` replaced with a months-based primitive**
- **Found during:** Task 3
- **Issue:** The plan's literal signature, `public static let validityWindow: TimeInterval`, is a fixed-seconds count. A twelve-month window expressed that way silently drifts across leap years and DST transitions — exactly the failure mode the plan's own prose says to avoid ("computed via Calendar date arithmetic rather than a hardcoded seconds count").
- **Fix:** Implemented the plan's own stated fallback instead: a private `validityWindowMonths: Int = 12` constant, with `expiry(from:calendar:)` built on `calendar.date(byAdding: .month, value:to:)` as the sole primitive everything else derives from. No acceptance criterion greps for `validityWindow`; the `byAdding` criterion is satisfied.
- **Files modified:** RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift
- **Verification:** `ConditionTagExpiryTests` (9 tests, including exact-boundary and edit-reset cases) and the full suite (46 tests) pass.
- **Committed in:** c7d9b6d (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for correctness (leap-year/DST safety) — the plan's own prose anticipated and authorized this alternative. No scope creep.

## Issues Encountered
None. The advisor review before implementation caught the `validityWindow`/`byAdding` tension, the nine-categories/Pregnancy-Postpartum split ambiguity, and the `under18Minor` producer gap before any code was written, so no rework was needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `RithamCore`'s full Swift Testing suite is 46 tests across 6 suites, green via `./Scripts/test-core.sh`
- The screening domain vocabulary (`ConditionTag`, `ClearanceGate`/`DomainGates`, `ScreeningAnswers`, `SCOFFResponses`, `ConditionTagValidity`) is a settled contract for HEALTH-06's escalation engine (plan 01-06) to transcribe rules against
- Open gap for a future plan (01-06/01-07/01-11): `ConditionTag.under18Minor` has no producer yet — needs to be set from Q0's raw age (`age < 18`), as a plain boolean check parallel to, but never routed through, `ageDerivedTags(forAge:)` or MINOR-01's 13+ floor check
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-25*
