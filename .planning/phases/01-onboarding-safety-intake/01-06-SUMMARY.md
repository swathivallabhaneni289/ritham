---
phase: 01-onboarding-safety-intake
plan: 06
subsystem: ios-core
tags: [swift, swift-testing, health-screening, gate-resolution, domain-logic]

# Dependency graph
requires:
  - phase: 01-03
    provides: "ConditionTag, ClearanceGate/DomainGates, ScreeningAnswers, SCOFFResponses, ConditionTagValidity — the screening domain vocabulary"
provides:
  - "TagDerivation.deriveTags(from:ageDerivedTags:) — §1.3/§1.4 checklist + follow-ups to ConditionTag set, including the under18Minor producer"
  - "GateEscalation.baseGates(for:)/.escalate(tags:answers:) — per-tag §2/§3 Clearance Gate columns plus the sixteen §5 escalation rules as one-way mostRestrictive folds"
  - "GateEscalation.weightLossFeatureGate(tags:goalBelowHealthyBMIFloor:)/.requiresIndependentAllergenVerification(tags:) — §5 rules 14/15/16"
  - "GateEscalation.neverGeneratesMedicationDosingGuidance/.showsEmergencyLine(for:) — the two always-on prohibitions"
  - "GateResolution.resolve(answers:ageDerivedTags:) — the single entry point producing matched tags, per-domain gates, and clearance interstitial"
  - "GateResolutionResult — matchedTags, gates, interstitial, disclaimerConditionNames, blocksPersonalization(in:), blocksAppAccess (always false)"
affects: [01-07, 01-09, 01-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-stage safety-critical composition: TagDerivation (answers -> tags) -> GateEscalation (tags -> per-domain gates) -> GateResolution (composes both + interstitial branching). Each stage is independently testable and the composition itself has its own end-to-end test, so a gap between stages (like under18Minor's original missing producer) can't hide behind two green but disconnected test suites."
    - "Escalation rules expressed as private raiseWorkout/raiseNutrition/raiseBoth helpers that always fold through ClearanceGate.mostRestrictive, making every one of the sixteen §5 rules structurally one-way (can only raise a gate, never lower it) rather than relying on each call site to remember the direction."

key-files:
  created:
    - RithamCore/Sources/RithamCore/Screening/TagDerivation.swift
    - RithamCore/Sources/RithamCore/Screening/GateEscalation.swift
    - RithamCore/Sources/RithamCore/Screening/GateResolution.swift
    - RithamCore/Tests/RithamCoreTests/TagDerivationTests.swift
    - RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift
  modified: []

key-decisions:
  - "Rule 2 deviation: added the ConditionTag.under18Minor producer (ScreeningAnswers.age < 18) inside TagDerivation.deriveTags, closing the gap 01-03-SUMMARY.md explicitly flagged for this plan. Without it, §3's Under-18 nutrition required-blocking row could never fire for any minor, silently under-restricting a protected population — exactly the failure mode this plan's objective names. ConditionTag.ageDerivedTags(forAge:) was deliberately NOT touched (01-03's pinned ageDerivedTags(forAge: 13) == [] test still holds); this is a separate producer, and the eventual 01-07/01-11 call-site boolean unions into the same set idempotently. Verified end-to-end: age 15 with no other answers resolves to nutrition requiredBlocking, workout none."
  - "Where §5's rule prose (3, 6, 12) carries a scope qualifier narrower than the §2/§3 Clearance Gate column value (e.g. rule 6's \"required-blocking for vigorous/resistance specifically\" against a table row of `recommended`), the table's Clearance Gate column value is what's encoded as the gate. The narrower scope is contraindication content the three-level gate can't separately express, not a softer gate level — every such site has an inline comment recording which source the level was taken from."
  - "noneOfTheAboveBaseline is computed from checklist-derived tags only, before ageDerivedTags/U-1/under18Minor are unioned in — so a 65-plus user who selected only \"None of the above\" holds both noneOfTheAboveBaseline and age65PlusOrDeconditioned simultaneously. Pinned by a dedicated test; §1.1's precedence rule is additive-only, and a baseline-plus-65 user is a real, common case this reading has to represent."
  - "The checklist item otherHeartOrCirculatoryCondition, selected alone with no accompanying heartDisease selection and CV-1 = No, derives no ConditionTag — the plan's literal instruction (\"a heart-disease selection yields heartDiseaseStable\") only names the heartDisease checklist item, and no ConditionTag exists for a generic \"other circulatory condition\" outside CV-1's recent-event branch. Flagging for 01-07's checklist UI: not every cardiovascular checkbox is guaranteed to produce a tag on its own."

patterns-established:
  - "Pattern: every §5 escalation rule is implemented as an explicit, individually-testable fold (raiseWorkout/raiseNutrition/raiseBoth) even where the outcome is already implied by a tag's base gate — this is deliberate defense-in-depth so a future edit to §2/§3's base table can't silently unblock a rule that was previously only true by coincidence."

requirements-completed: [HEALTH-01, HEALTH-06, DIET-01]

coverage:
  - id: D1
    description: "TagDerivation.deriveTags maps every §1.3 checklist selection and §1.4 severity follow-up onto the §2/§3 Condition Tag vocabulary, with \"Not sure\" resolving to the cautious branch at all three places it appears, and DietaryPattern structurally absent from the file"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/TagDerivationTests.swift (40 tests)"
        status: pass
      - kind: other
        ref: "grep -vE comment-stripped TagDerivation.swift | grep -c DietaryPattern == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "\"Not sure\" resolves to the more cautious branch on every clearance-relevant follow-up (T-01-26)"
    requirement: "HEALTH-06"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift#testNotSureResolvesCautious"
        status: pass
    human_judgment: false
  - id: D3
    description: "2+ red-flag tags resolve to the single most restrictive gate across all of them, never averaged, blended, or softened (T-01-25)"
    requirement: "HEALTH-06"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift#testMultiTagMostRestrictiveWins"
        status: pass
    human_judgment: false
  - id: D4
    description: "SCOFF contributes to resolution only when the eating-disorder checklist item was selected; score >= 2 produces a positive screen with nutrition required-blocking, score below 2 produces a negative screen with nutrition recommended (T-01-28)"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift#testSCOFFTrigger"
        status: pass
    human_judgment: false
  - id: D5
    description: "All sixteen numbered §5 escalation rules are transcribed as one-way (never-lowering) gate folds, plus the two always-on prohibitions expressed as standing facts rather than clearable gate states"
    requirement: "HEALTH-06"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift (testRule01 through testRule16, plus the always-on-prohibition tests)"
        status: pass
    human_judgment: false
  - id: D6
    description: "GateResolution.resolve composes tag derivation and gate escalation with §1.2's interstitial branching (urgent on G2/G3, routine on any other G1-G7 yes, none otherwise) into one pure, offline, deterministic entry point; matchedTags/disclaimerConditionNames report every matched condition even when a single gate binds (D-12), and blocksAppAccess is always false (§5's third governing principle)"
    requirement: "HEALTH-06"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift (Task 3 section: 10 tests covering interstitial branching, per-domain blocking, disclaimer listing, and determinism)"
        status: pass
      - kind: other
        ref: "cd RithamCore && ./Scripts/test-core.sh (full suite: 139 tests, 10 suites)"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-25
status: complete
---

# Phase 01 Plan 06: Red-Flag Escalation & Gate Resolution Engine Summary

**The safety-critical `GateResolution.resolve(answers:ageDerivedTags:)` — a pure, offline Swift module transcribing docs/health-screening.md §5's sixteen escalation rules and three governing principles into a tested condition-tag-to-clearance-gate pipeline, closing the under18Minor producer gap 01-03 flagged.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3
- **Files modified:** 5 (all created)

## Accomplishments
- `TagDerivation.deriveTags(from:ageDerivedTags:)` maps every §1.3 checklist selection and §1.4 severity follow-up onto the full §2/§3 Condition Tag vocabulary, with "Not sure" landing on the cautious branch at all three places it appears (hypertension CV-2, arrhythmia CV-2b, and every `isCautiousBranch`-gated follow-up) — 40 unit tests, one per documented mapping plus the pinned edge cases
- Closed 01-03's explicitly flagged open gap: added the `ConditionTag.under18Minor` producer (from `ScreeningAnswers.age < 18`) so §3's Under-18 nutrition required-blocking row can actually fire — verified end-to-end that a 15-year-old resolves to nutrition `requiredBlocking`, workout `none`, without touching `ageDerivedTags(forAge:)`'s pinned 65+-only contract
- `GateEscalation.baseGates(for:)` sources workout and nutrition Clearance Gate columns independently per tag from §2 and §3 — 10 of the 31 tags genuinely diverge between domains, and every divergence is commented with which table row it came from
- `GateEscalation.escalate(tags:answers:)` folds the base most-restrictive-across-tags gate with all sixteen §5 numbered triggers via a one-way `mostRestrictive` operation, so no code path can produce a laxer gate than any single contributing tag or rule would alone — plus `weightLossFeatureGate` (rules 14/15), `requiresIndependentAllergenVerification` (rule 16), and the two always-on prohibitions
- `GateResolution.resolve(answers:ageDerivedTags:)` composes both stages with §1.2's clearance-interstitial branching into the one pure, offline, deterministic function the rest of the product calls — `matchedTags`/`disclaimerConditionNames` report every matched condition even when only one gate binds (D-12), and `blocksAppAccess` is a stored `false` recording that a domain block never becomes an app-access block
- Full `RithamCore` suite: 139 tests across 10 suites, green

## Task Commits

Each task was committed atomically:

1. **Task 1: Derive condition tags from checklist and severity follow-ups** - `671bace` (feat)
2. **Task 2: The sixteen escalation rules and the always-on prohibitions** - `9d6f713` (feat)
3. **Task 3: The single resolution entry point** - `27864fe` (feat)

**Follow-up (self-review, pre-summary):** `04aa3f7` (test) — strengthened two Task 3 assertions that compared a value to its own derivation instead of pinning the expected result, and added an explicit end-to-end test proving the under18Minor Rule 2 deviation actually closes the gap through `GateResolution.resolve` (not just in isolation at each stage).

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Screening/TagDerivation.swift` - `TagDerivation.deriveTags(from:ageDerivedTags:)`, the checklist+follow-up-to-tag mapping, including the under18Minor producer
- `RithamCore/Sources/RithamCore/Screening/GateEscalation.swift` - `GateEscalation.baseGates(for:)`, `.escalate(tags:answers:)`, `.weightLossFeatureGate(tags:goalBelowHealthyBMIFloor:)`, `.requiresIndependentAllergenVerification(tags:)`, `.neverGeneratesMedicationDosingGuidance`, `.showsEmergencyLine(for:)`, `ScreeningSection`
- `RithamCore/Sources/RithamCore/Screening/GateResolution.swift` - `ClearanceInterstitial`, `GateResolutionResult`, `GateResolution.resolve(answers:ageDerivedTags:)`
- `RithamCore/Tests/RithamCoreTests/TagDerivationTests.swift` - 40 tests, one per documented checklist/follow-up mapping plus pinned edge cases
- `RithamCore/Tests/RithamCoreTests/GateResolutionTests.swift` - 33 tests: the three named suites (`testNotSureResolvesCautious`, `testMultiTagMostRestrictiveWins`, `testSCOFFTrigger`), one test per numbered §5 rule (`testRule01`-`testRule16`), the two always-on-prohibition tests, `baseGates` divergence, and the Task 3 `GateResolution.resolve` section (interstitial branching, per-domain blocking, D-12 disclaimer listing, determinism, and the under18Minor end-to-end case)

## Decisions Made
- Added the `under18Minor` producer as a Rule 2 deviation (see key-decisions above for full rationale) — this was the plan's own flagged open gap from 01-03, not new scope
- Where §5's rule prose carries a scope qualifier narrower than the §2/§3 table's Clearance Gate column (rules 3, 6, 12), the table's column value is what's encoded as the gate; the narrower scope is content-layer, not gate-level
- `noneOfTheAboveBaseline` is computed from checklist-derived tags only, so it coexists with age-derived/U-1 tags rather than being suppressed by them — pinned by a dedicated test
- `otherHeartOrCirculatoryCondition` selected alone (no `heartDisease`, CV-1 = No) derives no tag, following the plan's literal instruction — flagged for 01-07's checklist UI

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added the ConditionTag.under18Minor producer**
- **Found during:** Task 1, before writing any code — flagged in the prompt's `<files_to_read>` context and confirmed via advisor consultation before implementation
- **Issue:** `ConditionTag.under18Minor` was representable in the type (01-03) but had no producer anywhere in `RithamCore`. Without one, `TagDerivation.deriveTags` could never emit it, so `GateEscalation.baseGates(for: .under18Minor)`'s nutrition `requiredBlocking` value (§3's AAP-guidance-based Under-18 row) could never actually apply to any minor's resolved gates — a silent under-restriction of a protected population, exactly the failure mode this plan's objective calls out.
- **Fix:** Added `if let age = answers.age, age < 18 { result.insert(.under18Minor) }` inside `TagDerivation.deriveTags`, reading `ScreeningAnswers.age` (Q0, already on the struct from 01-03) directly. Did not touch `ConditionTag.ageDerivedTags(forAge:)`, which 01-03 pinned to the 65+ tag only via an explicit `forAge: 13 == []` test.
- **Files modified:** RithamCore/Sources/RithamCore/Screening/TagDerivation.swift
- **Verification:** `TagDerivationTests` (age-under-18/age-18 pair) plus `GateResolutionTests#resolveUnder18MinorEndToEnd`, proving the composition through `GateResolution.resolve` end-to-end (age 15 -> nutrition `requiredBlocking`, workout `none`).
- **Committed in:** 671bace (Task 1 commit); end-to-end test added in 04aa3f7 (follow-up)

---

**Total deviations:** 1 auto-fixed (1 missing critical functionality)
**Impact on plan:** Necessary for correctness — this was the plan's own explicitly flagged open gap from 01-03-SUMMARY.md, not scope creep. No architectural change; the producer is a single conditional insert inside an existing pure function.

## Issues Encountered
None. An advisor consultation before implementation surfaced the under18Minor gap, the specific §2/§3 rows where workout and nutrition base gates diverge, three places where §5's rule prose could be misread as a gate-level downgrade (rules 3, 6, 12), and the "Not sure resolves to the more cautious branch" test needing per-follow-up strict-vs-equal splitting rather than one uniform loop — all incorporated before writing tests, so no rework was needed. A second advisor consultation after implementation caught two Task 3 test assertions that restated their own implementation instead of pinning expected values, and an untested composition gap (under18Minor tested at each stage in isolation, never end-to-end) — both fixed in a follow-up commit before this summary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `RithamCore`'s full Swift Testing suite is 139 tests across 10 suites, green via `./Scripts/test-core.sh`
- `GateResolution.resolve(answers:ageDerivedTags:)` is the settled single entry point for "what is this user cleared for?" — plans 01-07 (onboarding flow state), 01-09+ (app-side screening UI), and 01-11 (SwiftData persistence) can call it directly rather than reimplementing any part of the escalation logic
- Flag for 01-07's condition-checklist UI: `otherHeartOrCirculatoryCondition` selected alone produces no `ConditionTag` on its own (see Decisions Made) — worth confirming this checklist item's copy doesn't imply a distinct outcome from `heartDisease`
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-25*
