---
phase: 01-onboarding-safety-intake
plan: 07
subsystem: ios-core
tags: [swift, swift-testing, onboarding, routing, domain-modeling]

# Dependency graph
requires:
  - phase: 01-03
    provides: "ConditionTag, ScreeningAnswers/ChecklistSelection/ChecklistItem, SCOFFResponses, DietaryPattern"
  - phase: 01-05
    provides: "CalibrationBaseline, CalibrationProgress, CalibrationCompletion"
provides:
  - "OnboardingStep — the single 18-case step vocabulary every user's flow is built from (no age-based fork)"
  - "ExplanationRegister (plainLanguage/technical) + optionLabel, GlossaryEntry/Glossary — EXPLAIN-01's register and tap-to-expand glossary contract"
  - "OnboardingAnswers — the single answer aggregate (isAgeEligible/ageDerivedTags/isSCOFFTriggered), CalibrationOutcome, EditableSection + invalidate(section:)"
  - "OnboardingRouter.nextStep(after:answers:) / .isReachable(_:answers:) — the single branching authority, one fork on age, nothing downstream of dietaryPattern branches on age"
affects: [01-09, 01-12, 01-13, 01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure routing function (OnboardingRouter.nextStep) over one shared step enum, with the entire per-request branching state living in one Codable answer aggregate — no view holds wizard-answer local state, so back-navigation and cross-step branching both stay consistent by construction"
    - "Reachability computed generically by walking nextStep from .welcome with a visited-set loop guard, rather than each step re-deriving its own reachability"

key-files:
  created:
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift
    - RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingAnswers.swift
    - RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift
  modified:
    - RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift
    - RithamCore/Sources/RithamCore/Screening/SCOFF.swift
    - RithamCore/Sources/RithamCore/Screening/DietaryPattern.swift
    - RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift

key-decisions:
  - "Rule 3 deviation: added Codable conformance to ScreeningAnswers and its full closed-enum/struct vocabulary (YesNo, YesNoUnsure, BloodPressureControl, RhythmControl, SurgicalClearance, PostpartumWeeks, ChecklistCategory, ChecklistItem, ChecklistSelection), SCOFFResponses, DietaryPattern, and CalibrationBaseline (PaceZone, BaselineSource) — all previously Equatable/Sendable only. OnboardingAnswers' own required Codable conformance (so an interrupted flow can resume) is structurally impossible without every nested type also conforming; verified empirically before writing OnboardingAnswers that Swift's synthesized Codable works unmodified for each shape present (case-only enums, String-raw enums, and structs with custom inits), then applied additively with no signature or behavior changes to any existing member."
  - "Reworded the plan's own header-comment instructions ('note there is no parentalConsent case…') to avoid literally spelling the retired ConsentTier/ConsentState/ConsentGate/parentalConsent/teenPartialGateNotice identifiers in source comments, since the plan's own acceptance criteria grep those exact strings and expect zero matches — the constraint is documented by describing what doesn't exist rather than naming the removed types."
  - "needsSeverityFollowUps treats eating-disorder-history as a category 'needing follow-ups' (its follow-up is the SCOFF screen, reached via severityFollowUps -> scoffFollowUp) so a user who selects only that item still reaches severityFollowUps and then scoffFollowUp per D-10 — the alternative reading (SCOFF as no follow-up need) would make SCOFF unreachable for an eating-disorder-only selection, contradicting the plan's own must-haves truth that the SCOFF step is reachable whenever that item is selected."
  - "Implemented §1.4's one documented severityFollowUps exception (Metabolic's M-1/M-2 do not apply when 'Prediabetes' is the only metabolic item selected) inside OnboardingRouter's private needsSeverityFollowUps helper, matching docs/health-screening.md's literal text rather than treating every non-empty checklist selection as uniformly needing follow-ups."
  - "A skipped calibration routes from calibrationIntro directly to the step after calibrationComplete (screeningOpeningDisclaimer), bypassing both calibrationSession and calibrationComplete entirely — read literally from the plan's own wording and pinned by a dedicated test asserting neither step is visited when calibrationOutcome is .skipped."

patterns-established:
  - "Pattern: a wizard's entire branching surface is one pure function (nextStep) over one Codable answer struct and one shared step enum — verified before any view exists via a traversal-walking test helper that also serves as the reachability implementation's semantic twin"

requirements-completed: [CROSSGEN-05, MINOR-01, EXPLAIN-01, DIET-01, CROSSGEN-03, HEALTH-01]

coverage:
  - id: D1
    description: "One shared OnboardingStep enum (18 cases) covers every screen for every user, with no parallel minor-specific/senior-specific step type and no case for a parental-consent or partial-gate step of any kind"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#eligibleAgesTraverseIdentically"
        status: pass
      - kind: other
        ref: "grep -c 'parentalConsent\\|teenPartialGateNotice\\|ConsentTier\\|ConsentState\\|ConsentGate' OnboardingStep.swift == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ages 15, 40, and 70 traverse a byte-for-byte identical step sequence; only age 8 diverges, stopping at ageIneligible — the strongest form of the no-fork guarantee"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#eligibleAgesTraverseIdentically, #onlyIneligibleAgeDiverges"
        status: pass
    human_judgment: false
  - id: D3
    description: "An under-13 age never advances past ageIneligible across repeated nextStep calls with the age unchanged; correcting the age to 13+ on a subsequent call routes straight to dietaryPattern like any other user, with nothing persisted for the rejected attempt"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#under13NeverAdvancesPastAgeIneligible, #correctedAgeRoutesForwardLikeAnyOtherUser"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every user 13+ reaches the complete safety screening (gateSection, conditionChecklist, and on to screeningComplete/home) with zero divergence by age above the floor; dietaryPattern immediately follows age for every eligible age"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#everyEligibleAgeReachesTheFullScreening, #dietaryPatternImmediatelyFollowsAgeForEligibleAges"
        status: pass
    human_judgment: false
  - id: D5
    description: "ExplanationRegister (plainLanguage/technical) is user-selected, never derived from age or any profile attribute, with optionLabel sourced from the locked OnboardingCopy catalog; the Glossary provides both-register definitions for at least 7 technical terms with no diagnostic framing"
    requirement: "EXPLAIN-01"
    verification:
      - kind: unit
        ref: "RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift (7 GlossaryEntry values, each with non-empty plainLanguageDefinition and technicalDefinition)"
        status: pass
      - kind: other
        ref: "cd RithamCore && swift build"
        status: pass
    human_judgment: false
  - id: D6
    description: "scoffFollowUp is reachable only when the eating-disorder-history checklist item was selected, per D-10 — skipped when it isn't, visited when it is"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#scoffFollowUpSkippedWhenNotSelected, #scoffFollowUpVisitedWhenSelected"
        status: pass
    human_judgment: false
  - id: D7
    description: "OnboardingRouter.nextStep is the sole branching authority (no capability-gate type consulted anywhere), deterministic across repeated calls, and DIET-01's dietary pattern step follows age directly and unconditionally for every user who clears the floor"
    requirement: "DIET-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#nextStepIsDeterministic, #dietaryPatternImmediatelyFollowsAgeForEligibleAges"
        status: pass
      - kind: other
        ref: "cd RithamCore && ./Scripts/test-core.sh (full suite: 153 tests, 11 suites)"
        status: pass
    human_judgment: false
  - id: D8
    description: "An unanswered age never falls through to the screening flow — isReachable(.gateSection/.dietaryPattern, answers: <no age set>) is false, matching the threat model's 'reaching the gate section is equivalent to being permitted to submit health data' boundary"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift#unansweredAgeNeverFallsThroughToScreening"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-25
status: complete
---

# Phase 01 Plan 07: Onboarding Flow State & Routing Summary

**A pure `OnboardingRouter.nextStep(after:answers:)` routing function over one shared 18-case `OnboardingStep` enum and one `Codable` `OnboardingAnswers` aggregate, proving CROSSGEN-05's no-fork guarantee (identical traversal for ages 15/40/70) and MINOR-01's 13+ floor at the routing level, before any view exists.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3 (plus one pre-finalization fix)
- **Files modified:** 9 (5 created, 4 modified)

## Accomplishments
- `OnboardingStep` — the single 18-case step vocabulary covering every screen every user's flow renders, in flow order from `welcome` through `home`, with `ageIneligible` present as an ordinary (routing-outcome-unreachable, not structurally-absent) case and no parental-consent or partial-gate case of any kind, per D-14
- `ExplanationRegister` (`plainLanguage`/`technical`) with `optionLabel` sourced from the locked `OnboardingCopy.Register` catalog, plus `GlossaryEntry`/`Glossary` giving EXPLAIN-01's tap-to-expand behavior both-register, non-diagnostic definitions for 7 technical terms (grade-adjusted pace, one-rep max, HRV, RPE, the talk test, working set, pace zone)
- `OnboardingAnswers` — the single `Codable` home for every branching-relevant answer, with `isAgeEligible`/`ageDerivedTags`/`isSCOFFTriggered` computed once so the router and future views never re-derive them; `CalibrationOutcome.skipped` is a first-class outcome per D-03; `EditableSection`/`invalidate(section:)` supports D-09's section-scoped re-check
- `OnboardingRouter.nextStep(after:answers:)` — the one place branching lives, reading `answers.isAgeEligible` exactly once at exactly one fork; every user 13+ takes the identical path from `dietaryPattern` onward through the complete safety screening (gate section, condition checklist, SCOFF), with zero parental involvement, per D-15; an unanswered age holds at `.age` rather than defaulting into the screening flow
- `OnboardingFlowStateTests` (14 tests): the four-age traversal (8/15/40/70) proving byte-for-byte identical sequences for every eligible age and divergence only at `ageIneligible` for age 8; repeated-call and age-correction tests for the 13+ floor; an unanswered-age test; SCOFF reachability in both directions; a skipped-calibration test; and a determinism test pinned to an actual expected value
- Full `RithamCore` suite: 153 tests across 11 suites, green

## Task Commits

Each task was committed atomically:

1. **Task 1: The shared step vocabulary and the explanation register** - `fde0f49` (feat)
2. **Task 2: The onboarding answer aggregate** - `45f9545` (feat)
3. **Task 3: The routing function and its no-fork guarantee** - `45fad7d` (feat)
4. **Follow-up (advisor review before finalizing): unanswered age must not fall through to screening** - `63d6644` (fix)

## Files Created/Modified
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift` - the 18-case `OnboardingStep` enum
- `RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift` - `ExplanationRegister`, `optionLabel`, `GlossaryEntry`, `Glossary`
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingAnswers.swift` - `OnboardingAnswers`, `CalibrationOutcome`, `EditableSection`, `invalidate(section:)`
- `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift` - `OnboardingRouter.nextStep(after:answers:)`, `.isReachable(_:answers:)`
- `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift` - 14 tests covering the no-fork guarantee, the 13+ floor (including the unanswered-age case), SCOFF reachability, skipped calibration, and determinism
- `RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift` - added `Codable` to `YesNo`, `YesNoUnsure`, `BloodPressureControl`, `RhythmControl`, `SurgicalClearance`, `PostpartumWeeks`, `ChecklistCategory`, `ChecklistItem`, `ChecklistSelection`, `ScreeningAnswers`
- `RithamCore/Sources/RithamCore/Screening/SCOFF.swift` - added `Codable` to `SCOFFResponses`
- `RithamCore/Sources/RithamCore/Screening/DietaryPattern.swift` - added `Codable` to `DietaryPattern`
- `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift` - added `Codable` to `PaceZone`, `BaselineSource`, `CalibrationBaseline`

## Decisions Made
- Reworded header comments to describe retired consent-flow concepts without literally spelling their identifiers, since the plan's own acceptance criteria grep for those exact strings and require zero matches — see Deviations
- Treated eating-disorder-history as a "needs follow-ups" category so a user selecting only that item still reaches `severityFollowUps` then `scoffFollowUp`, matching the plan's must-have that SCOFF is reachable whenever the item is selected
- Implemented the Metabolic/Prediabetes-alone follow-up exception from `docs/health-screening.md` §1.4 literally, rather than treating any non-empty checklist as uniformly needing follow-ups
- A skipped calibration bypasses both `calibrationSession` and `calibrationComplete` entirely, landing on `screeningOpeningDisclaimer` — read literally from the plan's "route ... to the step after calibrationComplete" wording and pinned by a dedicated test

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Codable conformance to ScreeningAnswers/SCOFFResponses/DietaryPattern/CalibrationBaseline and their nested types**
- **Found during:** Task 2 (Onboarding answer aggregate)
- **Issue:** The plan requires `OnboardingAnswers: Sendable, Equatable, Codable`, but `OnboardingAnswers` embeds `screening: ScreeningAnswers`, `dietaryPattern: DietaryPattern?`, and (via `CalibrationOutcome.completed`) `CalibrationBaseline` — none of which conformed to `Codable` as committed in plans 01-03/01-05. `OnboardingAnswers` could not be made `Codable` without every nested type also conforming.
- **Fix:** Added `Codable` to `YesNo`, `YesNoUnsure`, `BloodPressureControl`, `RhythmControl`, `SurgicalClearance`, `PostpartumWeeks`, `ChecklistCategory`, `ChecklistItem`, `ChecklistSelection`, `ScreeningAnswers` (`Screening/ScreeningAnswers.swift`); `SCOFFResponses` (`Screening/SCOFF.swift`); `DietaryPattern` (`Screening/DietaryPattern.swift`); and `PaceZone`, `BaselineSource`, `CalibrationBaseline` (`Calibration/CalibrationBaseline.swift`). Verified empirically before writing any `OnboardingAnswers` code that Swift's compiler-synthesized `Codable` works unmodified for each shape present in this codebase (case-only enums with no raw value, `String`-raw-value enums, and structs with custom non-memberwise initializers) — all additive, no existing member's signature or behavior changed.
- **Files modified:** `RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift`, `RithamCore/Sources/RithamCore/Screening/SCOFF.swift`, `RithamCore/Sources/RithamCore/Screening/DietaryPattern.swift`, `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift`
- **Verification:** `cd RithamCore && swift build` (exits 0), full test suite unaffected (152 tests, 11 suites, all pass, including every pre-existing suite touching these types)
- **Committed in:** `45f9545` (Task 2 commit)

**2. [Rule 1 - Bug] Reworded forbidden-term header comments to satisfy the plan's own literal grep**
- **Found during:** Task 1, immediately after drafting `OnboardingStep.swift`/`ExplanationRegister.swift`
- **Issue:** The plan's `<action>` text explicitly instructs writing a header comment naming the retired concepts (e.g. "note that... there is no `parentalConsent` case and no `teenPartialGateNotice` case"), but the plan's own acceptance criteria run `grep -c 'parentalConsent\|teenPartialGateNotice\|ConsentTier\|ConsentState\|ConsentGate' <file>` and require the count to be `0` — a literal comment following the action text's exact wording would fail its own acceptance check.
- **Fix:** Kept the documented constraint (no age-based fork, no tiered-consent case exists) but described it without literally spelling the retired identifiers — e.g. "no case for a parent-approval step and no case for a partial-access notice shown between the floor and adulthood" instead of naming `parentalConsent`/`teenPartialGateNotice` outright.
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift`, `RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift`
- **Verification:** `grep -c '...' OnboardingStep.swift` and the same for `OnboardingRouter.swift`/`OnboardingAnswers.swift`/`ExplanationRegister.swift`/`OnboardingFlowStateTests.swift` all return `0`
- **Committed in:** `fde0f49` (Task 1 commit)

**3. [Rule 2 - Missing Critical Functionality] An unanswered age fell through to the screening flow**
- **Found during:** Advisor review, immediately before finalizing this plan (after all three tasks were committed and the full suite was green)
- **Issue:** `nextStep`'s `.age`/`.ageIneligible` branch was `answers.isAgeEligible == false ? .ageIneligible : .dietaryPattern` — so `isAgeEligible == nil` (no age answered at all) fell into the `else` branch exactly like `true` does. `OnboardingRouter.isReachable(.gateSection, answers: OnboardingAnswers())` (a default, un-aged answers value) returned `true`. Per this plan's own threat model, "reaching the gate section is equivalent to being permitted to submit health data" — a view consulting `isReachable` for a user who has not yet answered Q0 would get a green light into the health screening, which MINOR-01's floor is supposed to gate on a confirmed age, not an absent one.
- **Fix:** Unified the `.age`/`.ageIneligible` cases into one `guard let isEligible = answers.isAgeEligible else { return .age }` — a `nil` age now holds at `.age` (the entry step) instead of defaulting forward; only a confirmed `true` routes to `.dietaryPattern`, and a confirmed `false` still routes to `.ageIneligible`, unchanged from before.
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/OnboardingRouter.swift`, `RithamCore/Tests/RithamCoreTests/OnboardingFlowStateTests.swift`
- **Verification:** New test `unansweredAgeNeverFallsThroughToScreening` asserts `nextStep(after: .age, answers: OnboardingAnswers()) == .age` and `!isReachable(.dietaryPattern/.gateSection, answers: OnboardingAnswers())`; full suite green (153 tests, 11 suites); none of the 13 pre-existing `OnboardingFlowStateTests` (all of which set an explicit age) changed behavior.
- **Committed in:** `63d6644` (follow-up fix commit)

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 bug, 1 missing critical functionality)
**Impact on plan:** All three were necessary for the plan's own literal requirements and its own threat model to hold simultaneously (Codable conformance for resumability; the acceptance criteria's zero-match grep; MINOR-01's floor actually gating on a confirmed age rather than an absent one). No scope creep, no architectural change — the Codable additions are purely additive conformances on already-committed types, the comment rewording preserves the exact documented constraint, and the age-fallthrough fix only changes the `nil` branch's destination.

## Issues Encountered
None beyond the deviations above. The Metabolic/Prediabetes-alone `severityFollowUps` exception and the eating-disorder-alone SCOFF-reachability reading were both resolved by close re-reading of `docs/health-screening.md` §1.4 and the plan's own must-haves before writing `OnboardingRouter`, so no rework was needed after tests were written.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `RithamCore`'s full Swift Testing suite is 153 tests across 11 suites, green via `./Scripts/test-core.sh`
- `OnboardingRouter.nextStep(after:answers:)`/`.isReachable(_:answers:)` and `OnboardingAnswers` are the settled contract plan 01-12's app-side `@Observable` wrapper must delegate to rather than reimplement — no branching logic may exist on the app side
- `Glossary`/`GlossaryEntry` are ready for the app-side tap-to-expand glossary UI (later wave) to consume by term lookup
- Flag for 01-16/01-12's severity-follow-ups view: an eating-disorder-history-only checklist selection routes through `.severityFollowUps` with zero applicable §1.4 category questions before reaching `.scoffFollowUp` — the view for that step needs to render as a pass-through (or skip its own screen) rather than show an empty follow-up form, mirroring how 01-06 flagged `otherHeartOrCirculatoryCondition` for this plan
- This is the last plan in Wave 3 (per the phase's wave sequence); Wave 4 (01-09) stands up the Xcode project/app target next, now that full Xcode is available on this machine
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-25*

## Self-Check: PASSED

All 9 created/modified source and test files verified present on disk; all 4 commit
hashes (fde0f49, 45f9545, 45fad7d, 63d6644) verified in git log.
