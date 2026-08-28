---
phase: 01-onboarding-safety-intake
plan: 17
subsystem: ui
tags: [swiftui, health-screening, disclaimers, swiftdata, settings, swift-testing]

# Dependency graph
requires:
  - phase: 01-16
    provides: "The seven registered screening screens (GateSectionView, ConditionChecklistView, SeverityFollowUpView, EatingPatternFollowUpView, ...) EditAnswerFlow re-presents per section, and the centralized ScreeningCopy this plan's disclaimer surfaces render verbatim"
  - phase: 01-11
    provides: "HealthDataStore facade (loadProfile/updateProfile/saveScreeningResult/activeConditionTags/isReScreenDue/invalidateSection/recordProfessionalClearance/clearancesNeedingReConfirmation) this plan's health profile and Settings screens read/write through"
  - phase: 01-06
    provides: "GateResolutionResult/GateEscalation/ClearanceGate/DomainGates -- the engine this plan's disclaimer tag and health profile screen render"
  - phase: 01-09
    provides: "OnboardingFlow/StepRegistry/OnboardingStepPresenting -- the screen-reuse mechanism EditAnswerFlow builds on"
provides:
  - "ConditionDisclaimerTag/RequiredBlockingMessageView/StandingFooterDisclaimer -- the three remaining HEALTH-05 disclaimer surfaces, working components with a real home on HealthProfileView, ready for Phase 2's HEALTH-03/HEALTH-04 suggestion surfaces to reuse"
  - "HealthProfileView -- store-driven (not OnboardingFlow-driven), reachable from Settings at any time; empty state, per-tag validity display (D-08 overdue-still-applying), per-domain gate display, professional-clearance control"
  - "SettingsView/EditAnswerFlow/ReScreenBanner -- EXPLAIN-01/DIET-01 in-place editing with zero gate/tag effect, D-09 section-scoped screening-answer editing reusing plan 01-16's screens via a sheet, and the D-07/D-08 non-blocking re-screen reminder"
  - "HealthDataStore.conditionTagStatuses(now:)/ConditionTagStatus -- per-tag validity accessor (Rule 2 addition)"
  - "Glossary entries for Condition tag / Clearance gate / Professional clearance (Rule 2 addition)"
affects: [01-18, phase-2-suggestion-surfaces]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A screen that must outlive the transient in-memory OnboardingFlow (HealthProfileView) is store-driven: it reconstructs a GateResolutionResult from HealthDataStore.conditionTagStatuses(now:) via GateEscalation.escalate(tags:answers:) with an empty ScreeningAnswers, rather than depending on OnboardingFlow at all"
    - "Reusing an OnboardingStepPresenting screen outside the linear onboarding flow (EditAnswerFlow): capture flow.path's count before presenting, observe .onChange(of: flow.path) for the wrapped screen's own flow.advance call, and pop the path straight back to the captured count before treating the section as answered -- avoids a second NavigationStack (CROSSGEN-05 reserves the one container for OnboardingRootView) and avoids forking/duplicating the screen"
    - "GlossaryTerm gracefully renders plain text with no affordance when no Glossary entry exists for a term -- wrapping a term in it without adding the entry is a no-op that only looks like compliance; entries were added for the specific terms this plan's screen needed"

key-files:
  created:
    - RithamApp/Ritham/Disclaimers/ConditionDisclaimerTag.swift
    - RithamApp/Ritham/Disclaimers/RequiredBlockingMessageView.swift
    - RithamApp/Ritham/Disclaimers/StandingFooterDisclaimer.swift
    - RithamApp/Ritham/HealthProfile/HealthProfileView.swift
    - RithamApp/Ritham/Settings/SettingsView.swift
    - RithamApp/Ritham/Settings/EditAnswerFlow.swift
    - RithamApp/Ritham/Settings/ReScreenBanner.swift
    - RithamApp/RithamTests/DisclaimerTagTests.swift
    - RithamApp/RithamTests/EditAnswerFlowTests.swift
  modified:
    - RithamApp/Ritham/Persistence/HealthDataStore.swift
    - RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "HealthProfileView is deliberately store-driven, not OnboardingFlow-driven -- it must be reachable from Settings long after the transient in-memory OnboardingFlow object (scoped to one onboarding pass) is gone, so its GateResolutionResult is reconstructed from persisted tags at read time rather than carried from onboarding session state"
  - "Added HealthDataStore.conditionTagStatuses(now:) (Rule 2): no existing accessor exposed per-tag validity, and D-08's must-have truth (an overdue tag shown as still applying, never as inactive) is not renderable without knowing which validity state each individual tag is in -- activeConditionTags collapses that distinction away by design"
  - "EditAnswerFlow reuses plan 01-16's already-registered screening screens via StepRegistry.view(for:flow:) rather than re-implementing any question, neutralizing their flow.advance(from:) side effect (which would otherwise push this edit session into an unrelated onboarding step on the shared path OnboardingRootView's single NavigationStack observes) by capturing flow.path's count and popping it back after each edit"
  - "EditAnswerFlow requires the same-session, populated OnboardingFlow it is handed -- reversing 01-11's deliberate 'derived tags only, no raw ScreeningAnswers' storage decision to fix this durably is out of this plan's scope (Rule 4, architectural), so the limitation is documented in the file's header comment, deferred-items.md, and pinned by two explicit tests rather than silently left undiscovered"
  - "Added three Glossary entries (Condition tag, Clearance gate, Professional clearance) rather than wrapping terms in GlossaryTerm with no backing entry, which would render plain text and only look like EXPLAIN-01 compliance"

patterns-established:
  - "Pattern: a screen intended to be reachable independently of a session-scoped in-memory object reconstructs its state from the durable store at read time, never by depending on that object's lifetime"

requirements-completed: [HEALTH-02, HEALTH-05, HEALTH-06, EXPLAIN-01, DIET-01]

coverage:
  - id: D1
    description: "ConditionDisclaimerTag renders every matched condition (D-12) via disclaimerConditionNames, expands to the full disclaimer at a >=44x44pt tap target, and never renders below the label-role size floor"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/DisclaimerTagTests.swift -- twoTagResultNamesBothConditions, singleTagResultNamesOneCondition, disclaimerConditionNamesIsStableAcrossRepeatedCalls, expandedDisclaimerContainsConditionsAndNotADiagnosisPhrasing"
        status: pass
      - kind: other
        ref: "grep -c 'disclaimerConditionNames'/'minimumTapTarget' ConditionDisclaimerTag.swift >= 1 each; comment-stripped grep for RithamType.footnote/.caption/.font(.footnote/.caption across Disclaimers/ == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "RequiredBlockingMessageView replaces a suggestion within one domain with no full-screen cover, modal, or navigation guard; StandingFooterDisclaimer renders the standing disclaimer at the label-role floor"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/DisclaimerTagTests.swift -- blocksPersonalizationTrueBlocksAppAccessFalse"
        status: pass
      - kind: other
        ref: "grep -c 'fullScreenCover'/'NavigationStack' RequiredBlockingMessageView.swift == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "HealthProfileView shows the locked empty-state copy when no screening data exists, lists condition tags with overdue tags shown as due for re-screen (never inactive/removed, D-08), shows a per-domain gate with RequiredBlockingMessageView swapped in for a required-blocking domain while the rest of the screen stays usable, attaches ConditionDisclaimerTag wherever adjusted state shows, and surfaces clearancesNeedingReConfirmation without ever removing a tag"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
      - kind: other
        ref: "grep -c 'OnboardingCopy.HealthProfile' >= 3, 'ConditionDisclaimerTag' >= 1, 'StandingFooterDisclaimer' >= 1, 'RequiredBlockingMessageView' >= 1, 'clearancesNeedingReConfirmation' >= 1, all in HealthProfileView.swift"
        status: pass
    human_judgment: true
    rationale: "The empty/complete-state branching, gate-display, and disclaimer-attachment logic is proven by grep and BUILD SUCCEEDED, but actual on-screen rendering (layout, readability of the overdue-tag wording, whether the professional-clearance control reads clearly) has not been visually confirmed in the Simulator/device -- deferred to 01-18's manual verification checkpoint, matching the pattern prior UI-heavy plans in this phase established."
  - id: D4
    description: "SettingsView edits the explanation register and dietary pattern in place with immediate effect, calling only HealthDataStore.updateProfile -- never GateResolution or invalidateSection -- and offers per-section entry points to EditAnswerFlow for the four screening sections plus an entry point to the health profile"
    requirement: "EXPLAIN-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/EditAnswerFlowTests.swift -- editingDietaryPatternLeavesTagsAndGatesUnchanged, editingRegisterLeavesTagsAndGatesUnchanged"
        status: pass
      - kind: other
        ref: "comment-stripped grep for GateResolution/invalidateSection in the register/diet .onChange handlers of SettingsView.swift == 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "EditAnswerFlow implements D-09: presents only one section's screening screen (reused from plan 01-16, never re-implemented), neutralizes its flow.advance side effect, then always re-resolves through GateResolution.resolve over the full merged answers (never a partial update) before saving"
    requirement: "DIET-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/EditAnswerFlowTests.swift -- invalidatingConditionChecklistLeavesGateSectionTagsIntact, reResolutionLowersThenRaisesGateAfterFullMergeReResolve, reResolutionAgainstAPopulatedSameSessionFlowPreservesOtherSections"
        status: pass
      - kind: other
        ref: "grep -c 'EditableSection' >= 2, 'invalidateSection' >= 1, 'GateResolution.resolve' >= 1, all in EditAnswerFlow.swift"
        status: pass
    human_judgment: false
  - id: D6
    description: "ReScreenBanner shows a non-blocking, session-dismissible reminder when isReScreenDue (caller-computed) is true, with a clear action to start the re-screen, and D-08's tags keep applying while it is outstanding"
    requirement: "HEALTH-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/EditAnswerFlowTests.swift -- overdueTagIsStillActiveWhileReScreenIsDue, dismissingBannerNeverMutatesReScreenDueState"
        status: pass
      - kind: other
        ref: "grep -c 'isReScreenDue' ReScreenBanner.swift >= 1; grep -c 'fullScreenCover'/'NavigationStack'/'.sheet' ReScreenBanner.swift == 0"
        status: pass
    human_judgment: false

duration: ~50min
completed: 2026-08-28
status: complete
---

# Phase 01 Plan 17: Disclaimer Surfaces, Health Profile, and Settings/Re-Screen Summary

**The three remaining HEALTH-05 disclaimer components (persistent compact tag, required-blocking message, standing footer) given a real home on a store-driven `HealthProfileView`, plus `SettingsView`/`EditAnswerFlow`/`ReScreenBanner` implementing EXPLAIN-01/DIET-01 in-place editing and D-09's section-scoped screening-answer re-check by reusing plan 01-16's own screens.**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3
- **Files modified:** 12 (9 created, 3 modified)

## Accomplishments
- `ConditionDisclaimerTag` renders `ScreeningCopy.compactDisclaimerTag(conditions:)` from a `GateResolutionResult`'s full `disclaimerConditionNames` (D-12: every matched condition, never only the governing one), expands in place to the full disclaimer at a >=44x44pt tap target, and holds the `label`-role floor via `fineprint()` throughout
- `RequiredBlockingMessageView` and `StandingFooterDisclaimer` render §4.6/§4.7 verbatim with no full-screen cover, modal, or smaller text style anywhere in the `Disclaimers/` directory
- `HealthProfileView` is deliberately store-driven rather than `OnboardingFlow`-driven, so it works as a real, reachable-anytime screen: empty state per the locked copy, per-tag validity from a new `HealthDataStore.conditionTagStatuses(now:)` accessor (overdue tags shown as due for re-screen, never inactive -- D-08), per-domain gate display with `RequiredBlockingMessageView` swapped in for a required-blocking domain while the rest of the screen stays usable, `ConditionDisclaimerTag`/`StandingFooterDisclaimer` reused (not rebuilt) exactly as Phase 2's suggestion surfaces should reuse them, and a professional-clearance control that surfaces `clearancesNeedingReConfirmation` and never removes a tag
- `SettingsView` edits the explanation register and dietary pattern in place, immediately, through `HealthDataStore.updateProfile` alone -- never `GateResolution`, never `invalidateSection` -- keeping DIET-01's isolation rule structurally true; offers an entry point to the health profile and one per-section entry point per screening section
- `EditAnswerFlow` implements D-09 by reusing plan 01-16's own registered screens (`GateSectionView`/`ConditionChecklistView`/`SeverityFollowUpView`/`EatingPatternFollowUpView`) through `StepRegistry`, neutralizing their `flow.advance` side effect (captured path count, popped back on change) rather than forking a second copy of any question, then always re-resolves via `GateResolution.resolve` over the fully merged answers before saving
- `ReScreenBanner` is non-blocking, dismissible for the session, and never gates access -- `isReScreenDue` is caller-computed and named literally on the type
- Added `HealthDataStore.conditionTagStatuses(now:)`/`ConditionTagStatus` (Rule 2) and three `Glossary` entries -- Condition tag, Clearance gate, Professional clearance (Rule 2) -- both closing gaps this plan's own must-have truths exposed
- Full `RithamTests` suite: 92 tests, 12 suites, green; full `RithamCore` suite: 154 tests, 11 suites, green

## Task Commits

Each task was committed atomically:

1. **Task 1: The persistent disclaimer tag, expanded form, and standing footer** - `b8e8818` (feat)
2. **Task 2: The health profile screen** - `2bb66e0` (feat)
3. **Task 3: Settings, section-scoped editing, and the re-screen banner** - `7c223d1` (feat)

## Files Created/Modified
- `RithamApp/Ritham/Disclaimers/ConditionDisclaimerTag.swift` - compact tag + expand, D-12 all-matched-conditions
- `RithamApp/Ritham/Disclaimers/RequiredBlockingMessageView.swift` - off-white card, non-covering
- `RithamApp/Ritham/Disclaimers/StandingFooterDisclaimer.swift` - label-role standing disclaimer
- `RithamApp/Ritham/HealthProfile/HealthProfileView.swift` - store-driven profile screen
- `RithamApp/Ritham/Settings/SettingsView.swift` - register/diet in-place edit, per-section entry points
- `RithamApp/Ritham/Settings/EditAnswerFlow.swift` - section-scoped re-check via reused screens
- `RithamApp/Ritham/Settings/ReScreenBanner.swift` - non-blocking twelve-month reminder
- `RithamApp/RithamTests/DisclaimerTagTests.swift` - 6 tests against `GateResolutionResult`/`ScreeningCopy`
- `RithamApp/RithamTests/EditAnswerFlowTests.swift` - 8 tests, including two pinning the known same-session-flow limitation
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` - added `conditionTagStatuses(now:)`/`ConditionTagStatus`
- `RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift` - added three `Glossary` entries
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each task

## Decisions Made
- `HealthProfileView` is store-driven, not `OnboardingFlow`-driven -- see key-decisions for full rationale
- Added `HealthDataStore.conditionTagStatuses(now:)` (Rule 2) since no existing accessor exposed per-tag validity
- `EditAnswerFlow` reuses plan 01-16's screens via `StepRegistry`, neutralizing the `flow.advance` side effect rather than forking a second implementation
- `EditAnswerFlow`'s same-session-flow requirement is documented, not fixed (would require reversing 01-11's storage decision -- Rule 4, out of scope)
- Added three `Glossary` entries rather than wrapping terms with no backing entry

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] No accessor exposed per-tag condition validity**
- **Found during:** Task 2, before writing `HealthProfileView` -- D-08's must-have truth (an overdue tag shown as still applying, never as inactive or removed) is not renderable from `activeConditionTags`, which already collapses `.active`/`.expiredStillApplied` into one undifferentiated list
- **Fix:** Added `HealthDataStore.conditionTagStatuses(now:)` returning `[ConditionTagStatus]` (tag + validity + professional-clearance date), mirroring `activeConditionTags`'s existing shape and delegating to the same `ConditionTagRecord.validity(now:calendar:)`
- **Files modified:** `RithamApp/Ritham/Persistence/HealthDataStore.swift`
- **Verification:** `./Scripts/build-app.sh test` (92 tests, 12 suites, pass)
- **Committed in:** `2bb66e0` (Task 2 commit)

**2. [Rule 2 - Missing Critical Functionality] No `Glossary` entries existed for this screen's technical terms**
- **Found during:** Task 2, before wrapping terms in `GlossaryTerm` per the plan's own instruction
- **Issue:** `GlossaryTerm` renders plain text with no affordance when no entry exists for its term -- wrapping "Condition tag"/"Clearance gate" with no backing definition would satisfy the letter of "wrap technical terms in GlossaryTerm" while EXPLAIN-01's actual tap-to-expand behavior did nothing
- **Fix:** Added `Condition tag`, `Clearance gate`, and `Professional clearance` entries to `RithamCore`'s `Glossary`, each written in both registers, matching the non-diagnostic framing every other screening surface holds to
- **Files modified:** `RithamCore/Sources/RithamCore/Onboarding/ExplanationRegister.swift`
- **Verification:** `cd RithamCore && ./Scripts/test-core.sh` (154 tests, 11 suites, pass)
- **Committed in:** `2bb66e0` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 2 -- missing critical functionality this plan's own must-have truths required)
**Impact on plan:** Both additions were necessary for the plan's own stated requirements (D-08's overdue-tag display; EXPLAIN-01's tap-to-expand actually revealing something) to be true, not scope creep. Neither touches gate resolution, persistence schema shape beyond the additive accessor, or any existing behavior.

## Issues Encountered
None beyond the deviations above -- no simulator flakiness this run. Three deeper architectural gaps were discovered during design (documented, not fixed, per advisor guidance and Rule 4): §5 Rule 1 (G2/G3 raw answers) cannot be reconstructed from persisted tags alone; `GateResolutionResult.gates` itself is never persisted; and `EditAnswerFlow` requires a same-session, populated `OnboardingFlow`. All three are logged in `deferred-items.md` with full detail. A fourth, pre-existing gap was also confirmed and logged: `.screeningComplete`/`.home` will still be unregistered when 01-18 runs, since neither this plan nor 01-18's own registrar list covers them, despite 01-16-SUMMARY.md's note that 01-17 "owns" `.screeningComplete`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All seven HEALTH-05 copy blocks now appear at every touchpoint this phase contains; `ConditionDisclaimerTag`/`RequiredBlockingMessageView`/`StandingFooterDisclaimer` are ready for Phase 2's HEALTH-03/HEALTH-04 suggestion surfaces to reuse directly
- `HealthProfileView`/`SettingsView`/`EditAnswerFlow`/`ReScreenBanner` are working components with a real surface, per this plan's objective -- none is yet wired into `StepRegistry` or any app-shell navigation (no `OnboardingStep` case exists for any of them), matching the plan's own scope
- **For 01-18:** `StepRegistry.unregisteredSteps` will NOT be empty as currently scoped -- `.screeningComplete` and `.home` have no registrar anywhere in the phase. `PhaseCoverageTests`'s `unregisteredSteps`-is-empty assertion will trip; resolving this (likely a small additional screen + registrar call) is 01-18's own Rule 3 fix, not this plan's scope. See `deferred-items.md`.
- **For Phase 2:** `GateResolutionResult.gates` needs a durable home before HEALTH-03/HEALTH-04 can read "what is this user's current gate" reliably; and closing the §5 Rule 1 (G2/G3) persistence gap would make `HealthProfileView`'s re-derived gates fully accurate. See `deferred-items.md` for both.
- No blockers for Wave 9 (01-18) beyond the `.screeningComplete`/`.home` registration gap flagged above.

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-28*

## Self-Check: PASSED

All 9 created files and 3 modified files (12 total, including this SUMMARY.md) verified present
on disk; all 3 task commit hashes (b8e8818, 2bb66e0, 7c223d1) verified in git log.
