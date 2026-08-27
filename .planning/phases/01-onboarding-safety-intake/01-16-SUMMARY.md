---
phase: 01-onboarding-safety-intake
plan: 16
subsystem: ui
tags: [swiftui, health-screening, par-q, scoff, gate-resolution, swift-testing]

# Dependency graph
requires:
  - phase: 01-12
    provides: "RithamScreen, PrimaryCTAButton/SecondaryCTAButton, ChoiceQuestionView/ChoiceChip -- the shared fixed-choice components every screen in this plan composes"
  - phase: 01-11
    provides: "HealthDataStore.saveScreeningResult/activeConditionTags -- the persistence facade the final screening step writes through"
  - phase: 01-01
    provides: "ScreeningCopy -- the verbatim disclaimer/framing/SCOFF-intro copy this plan renders, extended here with the individual question prompts"
  - phase: 01-06
    provides: "GateResolution.resolve/GateEscalation.showsEmergencyLine -- the tested escalation engine this plan's questionnaire flow feeds and reads from"
  - phase: 01-09
    provides: "OnboardingStepPresenting/StepRegistry/OnboardingRouter -- the routing contract every screen in this plan registers into"
provides:
  - "ScreeningOpeningDisclaimerView, GateSectionView, ClearanceInterstitialView, ConditionChecklistView, SeverityFollowUpView, EatingPatternFollowUpView, UniversalFollowUpView -- the seven screening screens, all registered"
  - "ScreeningCopy.emergencyLine/.Gate/.FollowUp/.EatingPattern/.universalFollowUp -- the individual §1.2/§1.4 question prompts and option labels, centralized in RithamCore for LAUNCH-01/LAUNCH-02 counsel/clinician review"
  - "ChecklistItem.displayName -- the §1.3 checkbox labels, mirroring ConditionTag.displayName"
  - "ScreeningRegistration.registerAll() -- registers all seven screens, not called from the app entry point (01-18 owns that)"
affects: [01-17, 01-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SeverityFollowUpView.questionsByCategory: a [ChecklistCategory: [SeverityQuestion]] dictionary built via a private generic severityQuestion(...) helper, so the category-to-follow-up mapping is one data structure rather than eight hand-built view bodies -- a new follow-up is a data addition, not a new view"
    - "SeverityQuestion.makeView is typed @MainActor (OnboardingFlow) -> AnyView: ChoiceQuestionView's initializer is main-actor-isolated by View conformance, and a plain top-level generic helper building it needs the closure's type to carry that isolation explicitly under Swift 6 strict concurrency, plus an Option: Sendable constraint on the generic and @Sendable on the optionTitle closure parameter"
    - "Retroactive Identifiable conformances for YesNo/YesNoUnsure (GateSectionView.swift) and BloodPressureControl/RhythmControl/SurgicalClearance/PostpartumWeeks (SeverityFollowUpView.swift) declared once each, at first consumer -- module-wide visibility means no other file in this plan redeclares them"

key-files:
  created:
    - RithamApp/Ritham/Screening/Views/ScreeningOpeningDisclaimerView.swift
    - RithamApp/Ritham/Screening/Views/GateSectionView.swift
    - RithamApp/Ritham/Screening/Views/ClearanceInterstitialView.swift
    - RithamApp/Ritham/Screening/Views/ConditionChecklistView.swift
    - RithamApp/Ritham/Screening/Views/SeverityFollowUpView.swift
    - RithamApp/Ritham/Screening/Views/EatingPatternFollowUpView.swift
    - RithamApp/Ritham/Screening/Views/UniversalFollowUpView.swift
    - RithamApp/Ritham/Screening/ScreeningRegistration.swift
    - RithamApp/RithamTests/ScreeningFlowTests.swift
  modified:
    - RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift
    - RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift
    - RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Centralized every §1.2/§1.4 question prompt and option label (previously absent from ScreeningCopy, which plan 01-01 scoped to only disclaimer/framing copy) into new ScreeningCopy.Gate/.FollowUp/.EatingPattern namespaces plus a standalone .universalFollowUp constant, rather than hardcoding them inline across seven view files -- per advisor review: G1-G7 is the PAR-Q+-style wording LAUNCH-01 counsel must review and ED-1..5 is the SCOFF wording LAUNCH-02 clinical review must confirm, and one file is the reviewable surface those reviews need"
  - "ChecklistItem.displayName added to RithamCore (ScreeningAnswers.swift), mirroring ConditionTag.displayName's existing pattern, as the single source for §1.3 checkbox labels"
  - "The standalone gate-section emergency line (ScreeningCopy.emergencyLine) is extracted verbatim from urgentClearanceInterstitial's own bolded first sentence (§4.3), not invented -- §5 names the urgent interstitial as where the line is 'repeated,' implying the gate section is where it is shown first, and this keeps both render sites saying the identical thing without one needing markdown parsing and the other not"
  - "'Shown once' for the opening disclaimer is tracked via OnboardingAnswers.completedSteps (an existing but previously-unused field designed for exactly this) rather than a new persisted UserProfile column -- the linear onboarding router only reaches this step once per pass regardless, and a durable flag would anticipate plan 01-17's edit-answer re-entry routing, which this plan does not own"
  - "The gate-pass affirmation (ScreeningCopy.gatePassAffirmation) renders via a SwiftUI .alert triggered by GateResolution.resolve's own interstitial == .none result, rather than a dedicated OnboardingStep -- no such step exists in the shared step vocabulary, and the affirmation is a screen-local acknowledgement, not a distinct destination"
  - "LocalizedStringKey markdown rendering (Text(.init(...))) is scoped to only the two clearance-interstitial copy blocks, the only screening copy containing literal ** markers -- every other copy constant in this plan renders as plain Text so a stray asterisk elsewhere can never be misparsed as emphasis"

patterns-established:
  - "Pattern: a plan-wide vocabulary gap (question prompts sourced from a design doc but never yet added to the shared copy catalog) is closed once, centrally, in the catalog file -- not scattered inline per consuming view -- when the content is itself a pending-legal/clinical-review surface"

requirements-completed: [HEALTH-01, HEALTH-05, HEALTH-06, MINOR-01]

coverage:
  - id: D1
    description: "ScreeningOpeningDisclaimerView renders ScreeningCopy.openingDisclaimer in full, once, on a flat charcoal surface with no truncation or fixed-height container"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
      - kind: other
        ref: "grep -c 'ScreeningCopy.openingDisclaimer' ScreeningOpeningDisclaimerView.swift >= 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "GateSectionView renders G1-G7 and the two immediate MED-1/MED-2 follow-ups (revealed inline on G5=Yes, cleared on G5 reverting to No), an unconditional emergency line via GateEscalation.showsEmergencyLine, and the gate framing copy exactly as written with no added heading"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/ScreeningFlowTests.swift -- allGateAnswersNoReachesConditionChecklistWithoutInterstitial, g1YesPassesThroughRoutineInterstitialAndReachesChecklist, g2YesResolvesUrgentVariant"
        status: pass
      - kind: other
        ref: "grep -c 'DecorativeSurface.flat'/'showsEmergencyLine'/'ScreeningCopy.gateSectionFraming' GateSectionView.swift >= 1 each; cd RithamCore && ./Scripts/test-core.sh --filter ScreeningCopyTests exits 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "ClearanceInterstitialView renders the routine/urgent variant from GateResolution.resolve's own interstitial value, the urgent variant visually distinct via a leading SF Symbol and coral card border (never destructive red), neither variant offering a skip past the checklist"
    requirement: "HEALTH-06"
    verification:
      - kind: other
        ref: "grep -c 'urgentClearanceInterstitial' ClearanceInterstitialView.swift >= 1; grep -c 'RithamColor.destructive' across Screening/Views == 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "ConditionChecklistView renders all nine §1.3 categories plus 'None of the above' with the exclusive-option rule delegated to ChecklistSelection.toggle, and both rationale lines (pregnancy/postpartum, eating-disorder-history) at the label role"
    requirement: "HEALTH-01"
    verification:
      - kind: other
        ref: "grep -c 'ChecklistSelection'/'pregnancyRationale'/'eatingDisorderRationale' ConditionChecklistView.swift >= 1 each"
        status: pass
    human_judgment: false
  - id: D5
    description: "SeverityFollowUpView is one data-driven screen (questionsByCategory keyed by ChecklistCategory) covering all eight applicable category groups, honoring §1.4's nested conditions exactly (CV-2/CV-2b/MSK-2 gated on specific checklist items, M-1/M-2 skipped when Prediabetes is the only metabolic item)"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh test -only-testing:RithamTests (78 tests, 10 suites, pass)"
        status: pass
      - kind: other
        ref: "grep -c 'ChecklistCategory' SeverityFollowUpView.swift >= 1"
        status: pass
    human_judgment: false
  - id: D6
    description: "EatingPatternFollowUpView collects the five SCOFF questions with no score, threshold, or diagnostic label ever displayed -- yesCount/isPositiveScreen never referenced"
    requirement: "HEALTH-01"
    verification:
      - kind: other
        ref: "grep -c 'ScreeningCopy.scoffIntro' >= 1; comment-stripped grep -c 'yesCount' == 0; comment-stripped grep -c 'isPositiveScreen' == 0"
        status: pass
    human_judgment: false
  - id: D7
    description: "UniversalFollowUpView renders U-1 unconditionally (no checklist guard) and persists the resolved screening result via HealthDataStore.saveScreeningResult, surfacing standard error copy on failure rather than crashing"
    requirement: "HEALTH-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/ScreeningFlowTests.swift#activeConditionTagsMatchesResolvedResult"
        status: pass
    human_judgment: false
  - id: D8
    description: "All seven screening steps register with StepRegistry (ScreeningRegistration.registerAll) and resolve to real views rather than the unimplemented-step fallback; this whole sequence runs identically for every 13+ user with no parental consent step and no partial gate"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/ScreeningFlowTests.swift#registerAllResolvesRealViewsAndShrinksUnregisteredSteps"
        status: pass
      - kind: other
        ref: "grep -c 'StepRegistry.register' ScreeningRegistration.swift == 7"
        status: pass
    human_judgment: false

duration: 90min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 16: Screening Questionnaire -- Gate, Checklist, Follow-Ups, and SCOFF Summary

**Seven registered screening screens (opening disclaimer, PAR-Q-style gate section with MED-1/MED-2, routine/urgent clearance interstitials, nine-category condition checklist, one data-driven severity follow-up screen across eight category groups, the five-question SCOFF eating-pattern screen with no score ever surfaced, and the universal U-1 follow-up that persists the resolved result) composed entirely from plan 01-12's shared components and plan 01-06's tested escalation engine.**

## Performance

- **Duration:** ~90 min
- **Tasks:** 3
- **Files modified:** 13 (9 created, 4 modified -- 3 RithamCore copy/vocabulary files plus the regenerated `.xcodeproj`)

## Accomplishments
- `ScreeningOpeningDisclaimerView` renders §1.0/§4.1's full disclaimer once, flat charcoal, with no truncation and no fixed-height container, tracking "shown" via `OnboardingAnswers.completedSteps`
- `GateSectionView` renders G1-G7 with MED-1/MED-2 revealed inline on G5=Yes and cleared the instant G5 reverts to No (T-01-95), the unconditional emergency line via `GateEscalation.showsEmergencyLine(for: .gate)`, and the gate-pass affirmation as an alert gated on the resolver's own `interstitial == .none` result
- `ClearanceInterstitialView` takes the resolver's `ClearanceInterstitial` value directly, renders the routine/urgent copy with markdown-bold parsing scoped to just those two blocks, and makes the urgent variant visually distinct with a leading SF Symbol and a coral card border -- the destructive red never appears anywhere under `Screening/`
- `ConditionChecklistView` renders all nine §1.3 categories (pregnancy/postpartum combined under one heading matching the doc's own grouping) plus a standalone "None of the above", every selection routed through `ChecklistSelection.toggle` via `ChoiceQuestionView`'s dedicated initializer -- no second exclusive-option implementation exists to drift (T-01-99)
- `SeverityFollowUpView` is one data-driven screen: a `[ChecklistCategory: [SeverityQuestion]]` dictionary built from a generic `severityQuestion(...)` helper, covering all 14 follow-up questions across the eight applicable category groups with §1.4's nested conditions honored exactly (CV-2 only on "High blood pressure", CV-2b only on "Irregular heartbeat", MSK-2 only on "prior injury or surgery", M-1/M-2 skipped when Prediabetes is the only metabolic item selected)
- `EatingPatternFollowUpView` collects ED-1 through ED-5 as fixed choices; `yesCount`/`isPositiveScreen` are never referenced anywhere in the file, and the five raw answers are never persisted -- only `UniversalFollowUpView`'s later `saveScreeningResult` call writes the resolved outcome
- `UniversalFollowUpView` shows U-1 with no guard on the checklist selection, then calls `GateResolution.resolve` and `HealthDataStore.saveScreeningResult`, surfacing `OnboardingCopy.Errors.savingFailed` on a save failure instead of crashing
- `ScreeningRegistration.registerAll()` registers all seven screens; `ScreeningFlowTests` (8 tests) asserts routing/data-level behavior for every must-have branch, including a positive/negative-control pair for SCOFF reachability per D-10
- Extended `ScreeningCopy` (RithamCore) with every §1.2/§1.4 question prompt and option label this plan needed but that didn't yet exist anywhere (`Gate`, `FollowUp`, `EatingPattern` namespaces, `universalFollowUp`, `emergencyLine`), and added `ChecklistItem.displayName` mirroring `ConditionTag.displayName` -- centralized per advisor review, since this is exactly the wording LAUNCH-01/LAUNCH-02 review needs to find in one place
- Full `RithamTests` suite: 78 tests, 10 suites, green; full `RithamCore` suite: 154 tests, 11 suites, green

## Task Commits

Each task was committed atomically:

1. **Task 1: Opening disclaimer, gate section, and clearance interstitials** - `53b55ad` (feat)
2. **Task 2: Condition checklist, severity follow-ups, and the universal follow-up** - `cb00f3c` (feat)
3. **Task 3: Eating-pattern follow-up and step registration** - `37d2639` (feat)

## Files Created/Modified
- `RithamApp/Ritham/Screening/Views/ScreeningOpeningDisclaimerView.swift` - §1.0/§4.1 disclaimer, shown once
- `RithamApp/Ritham/Screening/Views/GateSectionView.swift` - G1-G7, MED-1/MED-2, emergency line, gate-pass affirmation
- `RithamApp/Ritham/Screening/Views/ClearanceInterstitialView.swift` - routine/urgent clearance interstitial
- `RithamApp/Ritham/Screening/Views/ConditionChecklistView.swift` - nine-category checklist + rationale lines
- `RithamApp/Ritham/Screening/Views/SeverityFollowUpView.swift` - data-driven §1.4 follow-ups, `SeverityQuestion`
- `RithamApp/Ritham/Screening/Views/EatingPatternFollowUpView.swift` - SCOFF (ED-1 through ED-5), no score ever shown
- `RithamApp/Ritham/Screening/Views/UniversalFollowUpView.swift` - U-1 + `saveScreeningResult`
- `RithamApp/Ritham/Screening/ScreeningRegistration.swift` - `registerAll()`, seven `StepRegistry.register` calls
- `RithamApp/RithamTests/ScreeningFlowTests.swift` - 8 Swift Testing tests, routing/data-level
- `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift` - `emergencyLine`, `Gate`, `FollowUp`, `EatingPattern`, `universalFollowUp`
- `RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift` - `ChecklistItem.displayName`
- `RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift` - `emergencyLineContains911` test
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each task, per the established 01-09 through 01-15 pattern

## Decisions Made
- Centralized every question-prompt/option-label string this plan needed into `ScreeningCopy` (RithamCore) rather than hardcoding them inline across seven view files -- see key-decisions for the full rationale
- `ChecklistItem.displayName` added to RithamCore, mirroring `ConditionTag.displayName`
- `ScreeningCopy.emergencyLine` extracted verbatim from `urgentClearanceInterstitial`'s own bolded first sentence (§4.3), not invented
- "Shown once" for the opening disclaimer tracked via the existing `OnboardingAnswers.completedSteps` field, not a new persisted column
- Gate-pass affirmation shown via `.alert`, gated on the resolver's own interstitial value, since no dedicated `OnboardingStep` case exists for it
- `LocalizedStringKey` markdown rendering scoped to only the two clearance-interstitial copy blocks

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] No copy source existed for the individual §1.2/§1.4 question prompts, option labels, or the gate section's standalone emergency line**
- **Found during:** Task 1, before writing `GateSectionView` -- `ScreeningCopy` (plan 01-01) covered only disclaimer/framing/intro copy, never the individual question text every screen in this plan needs to render
- **Issue:** Without addressable copy, either every view would need to hardcode doc-sourced strings inline (scattering LAUNCH-01/LAUNCH-02-reviewable wording across seven files) or the screens couldn't be built as specified
- **Fix:** Added `ScreeningCopy.emergencyLine`, `.Gate` (G1-G7, MED-1/MED-2), `.FollowUp` (all fourteen §1.4 follow-up prompts and their non-Yes/No option labels), `.EatingPattern` (ED-1 through ED-5), and `.universalFollowUp` (U-1) to `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift`; added `ChecklistItem.displayName` to `ScreeningAnswers.swift` for the §1.3 checkbox labels
- **Files modified:** `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift`, `RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift`, `RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift` (added `emergencyLineContains911`)
- **Verification:** `cd RithamCore && ./Scripts/test-core.sh` (154 tests, 11 suites, pass); confirmed via advisor consultation before implementation
- **Committed in:** `53b55ad` (Task 1 commit) -- all three tasks' copy needs were added together in Task 1 as one cohesive catalog extension, since splitting a single-file addition across three task commits by hunk would be artificial

**2. [Rule 3 - Blocking] `SeverityQuestion.makeView`'s generic closure triggered Swift 6 strict-concurrency "sending risks a data race" errors**
- **Found during:** Task 2, first build after writing `SeverityFollowUpView`'s data-driven question table
- **Issue:** `ChoiceQuestionView`'s initializer is main-actor-isolated (by `View` conformance); a plain top-level generic helper function (`severityQuestion`) building one inside a closure, with an unconstrained `Option` generic and a non-`@Sendable` `optionTitle` closure, made the compiler unable to prove the captured values were safe to send across the actor boundary
- **Fix:** Typed `SeverityQuestion.makeView` as `@MainActor (OnboardingFlow) -> AnyView`, marked `severityQuestion` itself `@MainActor`, constrained `Option: Hashable & Identifiable & Sendable`, and marked `optionTitle` `@escaping @Sendable`
- **Files modified:** `RithamApp/Ritham/Screening/Views/SeverityFollowUpView.swift`
- **Verification:** `./Scripts/build-app.sh build` (BUILD SUCCEEDED)
- **Committed in:** `cb00f3c` (Task 2 commit) -- caught and fixed before committing, not a follow-up

---

**Total deviations:** 2 auto-fixed (1 missing critical functionality, 1 blocking Swift 6 concurrency fix)
**Impact on plan:** The copy-catalog extension is necessary infrastructure this plan's own instructions require (every screen's `<read_first>` cites the exact doc sections whose prompts needed rendering); centralizing rather than inlining was confirmed via advisor review against the LAUNCH-01/LAUNCH-02 review-surface concern. The concurrency fix is a correctness requirement for the code to compile at all under this project's `SWIFT_STRICT_CONCURRENCY: complete` setting; no behavior change, no scope creep.

## Issues Encountered
None beyond the deviations above -- no simulator flakiness this run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All seven screening screens are registered and reachable through `StepRegistry`; the whole gate section, condition checklist, and SCOFF follow-up run identically for every confirmed 13+ user with no parental consent step and no partial gate anywhere in the flow
- `StepRegistry.unregisteredSteps` now excludes every screening step; only `.screeningComplete` (owned by plan 01-17, per `OnboardingRouter.nextStep(after: .universalFollowUp)`) and Wave 8's remaining screens are still unregistered
- `ScreeningCopy.Gate`/`.FollowUp`/`.EatingPattern` are ready for plan 01-17's edit-answer flow to reuse against the same question prompts, and for LAUNCH-01/LAUNCH-02 counsel/clinician review to find every PAR-Q+-style and SCOFF string in one file
- No blockers for Wave 8 (01-17: disclaimer surfaces, health profile, settings/re-screen) or Wave 9 (01-18: final phase verification)

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 9 created files and 4 modified files (13 total, including this SUMMARY.md) verified present
on disk; all 3 task commit hashes (53b55ad, cb00f3c, 37d2639) verified in git log.
