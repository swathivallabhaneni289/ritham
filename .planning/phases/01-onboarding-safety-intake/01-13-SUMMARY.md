---
phase: 01-onboarding-safety-intake
plan: 13
subsystem: ui
tags: [swiftui, onboarding, age-floor, dietary-pattern, explanation-register, swiftdata]

# Dependency graph
requires:
  - phase: 01-12
    provides: "RithamScreen, PrimaryCTAButton/SecondaryCTAButton, ChoiceQuestionView/ChoiceChip, GlossaryTerm, RegisterEnvironment (explanationRegister environment key)"
  - phase: 01-09
    provides: "OnboardingStepPresenting protocol, StepRegistry, OnboardingFlow, OnboardingRootView's single NavigationStack"
  - phase: 01-11
    provides: "HealthDataStore/UserProfileDraft/UserProfile persistence facade"
  - phase: 01-01
    provides: "OnboardingCopy.Welcome/.Register/.Age/.Diet/.AgeGate/.Privacy locked screen copy"
provides:
  - "WelcomeStepView, ExplanationRegisterStepView, AgeStepView, AgeIneligibleStepView, DietaryPatternStepView, PrivacyExplainerStepView -- the six screens opening onboarding"
  - "AgeStepView.AgeValidator/.AgeValidationError -- Q0's bounded 1-120 numeric validation, independent of the 13+ floor"
  - "AboutYouRegistration.registerAll() -- registers all six screens with StepRegistry, not called from the app entry point (01-18 owns that call)"
  - "OnboardingRootView now injects .explanationRegister(_:) at the root, reading flow.answers.register first, then the stored profile, then .plainLanguage"
affects: [01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deferred-persist pattern for a screen that runs before a profile can exist: ExplanationRegisterStepView writes through HealthDataStore only when loadProfile() already succeeds; on the very first pass the choice lives in flow.answers.register only, and AgeStepView folds it into its own first-ever updateProfile call at profile-creation time"
    - "A view-owned numeric validator (AgeValidator.validate(_:) -> Result<Int, AgeValidationError>) is the one sanctioned exception to ChoiceQuestionView's fixed-choice-only rule -- Q0's age field is the questionnaire's single free numeric entry"
    - "Retroactive Identifiable conformance added per-consumer-file (ExplanationRegister in ExplanationRegisterStepView.swift, DietaryPattern in DietaryPatternStepView.swift) for ChoiceQuestionView's generic ForEach -- both types were already Hashable via Swift's automatic raw-value-enum synthesis, only Identifiable was missing"

key-files:
  created:
    - RithamApp/Ritham/Onboarding/Steps/WelcomeStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/ExplanationRegisterStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/AgeStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/AgeIneligibleStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/DietaryPatternStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/PrivacyExplainerStepView.swift
    - RithamApp/Ritham/Onboarding/Steps/AboutYouRegistration.swift
    - RithamApp/RithamTests/AgeValidationTests.swift
    - RithamApp/RithamTests/AboutYouStepTests.swift
  modified:
    - RithamApp/Ritham/App/OnboardingRootView.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "ExplanationRegisterStepView persists through HealthDataStore only when a profile already exists, instead of unconditionally as the plan's literal text describes -- UserProfileDraft.age is required/non-optional and no profile can exist before Age runs (HealthDataStore.updateProfile's own doc comment names the age step as 'the very first write'), so an unconditional call would either need a fabricated placeholder age or throw on every first-time user. AgeStepView folds the in-memory flow.answers.register into its own first-ever updateProfile call instead, so the choice is durably persisted no later than the moment the profile is created."
  - "ChoiceQuestionView's prompt (not RithamScreen's separate headline slot) carries the screen-level question text for ExplanationRegisterStepView/DietaryPatternStepView -- avoids rendering the same headline copy twice through two different components, since the plan gave no distinct prompt string beyond the headline for either screen"
  - "DietaryPatternStepView's CTA reuses OnboardingCopy.Age.cta ('Continue') -- OnboardingCopy.Diet has no dedicated cta constant (01-UI-SPEC.md's Copywriting Contract lists no CTA row for Q0b), and inventing new unreviewed copy would breach the 'shipped string set, not a tone guide' constraint"
  - "AgeIneligibleStepView uses DecorativeSurface.flat for its header (not a distinct surface value) -- DecorativeSurface.swift's own header comment enumerates 'Age blocking (under 13)' as the third of nine flat-only screens; the 'off-white card' distinction 01-UI-SPEC.md describes is body-content styling (a RoundedRectangle card wrapping the blocking message), not a different DecorativeSurface"

patterns-established:
  - "Pattern: a screen that must run before a durable record can exist attempts a best-effort write guarded by 'does a record already exist,' and the screen that actually creates the record folds in whatever was chosen upstream, in memory, into its own first-ever write -- this keeps a facade's required-field constructor (UserProfileDraft.age) honest without inventing a placeholder value"

requirements-completed: [ONBOARD-01, EXPLAIN-01, MINOR-01, DIET-01, CROSSGEN-03, CROSSGEN-05]

coverage:
  - id: D1
    description: "WelcomeStepView (full decorative surface, Momo reserved as an optional bounded card) and ExplanationRegisterStepView (bounded-header surface, single-select over ExplanationRegister.allCases) both render every visible string through OnboardingCopy, declare no NavigationStack of their own, and advance solely through flow.advance"
    requirement: "ONBOARD-01"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
      - kind: other
        ref: "grep -c 'OnboardingCopy.Welcome' WelcomeStepView.swift == 3; grep -c 'DecorativeSurface.welcome' WelcomeStepView.swift == 2; grep -c 'boundedHeaderOnly' ExplanationRegisterStepView.swift == 1; grep -c 'updateProfile' ExplanationRegisterStepView.swift == 3"
        status: pass
    human_judgment: false
  - id: D2
    description: "EXPLAIN-01's register choice: ExplanationRegisterStepView writes to UserProfile when a profile exists and always sets flow.answers.register; AgeStepView folds that value into its own first-ever updateProfile call; OnboardingRootView injects .explanationRegister(_:) at the root reading flow.answers.register first, then the stored profile, then .plainLanguage; the control is never disabled after selection"
    requirement: "EXPLAIN-01"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh test -only-testing:RithamTests (57 tests, 8 suites, pass)"
        status: pass
      - kind: other
        ref: "grep -c 'explanationRegister' OnboardingRootView.swift >= 1; ExplanationRegisterStepView has no .disabled( call"
        status: pass
    human_judgment: false
  - id: D3
    description: "MINOR-01's 13+ floor: AgeStepView's AgeValidator bounds input to 1-120 with no opinion on 13; the view hands the raw value to flow.advance without branching itself; the persist call to HealthDataStore.updateProfile is gated on age >= 13, so a rejected (under-13) value never reaches durable storage; AgeIneligibleStepView is a single-step-back loop via flow.goBack() with no forward advance of its own"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/AgeValidationTests.swift -- 6/6 tests pass (boundaries 1/120, out-of-bounds 0/121, no-opinion-on-13 across 8/12/13/40, 7 malformed input shapes, overflow safety, locked-error-copy coverage)"
        status: pass
      - kind: unit
        ref: "RithamApp/RithamTests/AboutYouStepTests.swift#routerWalkUnderThirteenReachesAgeIneligibleAndGoesNoFurther -- confirms the .ageIneligible self-loop and an unchanged age answer"
        status: pass
      - kind: other
        ref: "grep -c 'ConsentTier\\|ConsentState\\|ConsentGate' AgeStepView.swift AgeIneligibleStepView.swift == 0 (both files); AgeStepView's persist call is inside 'if age >= 13'"
        status: pass
    human_judgment: false
  - id: D4
    description: "DIET-01: DietaryPatternStepView collects Q0b directly after age (verified by the router-walk test), persists to the profile only, and never calls GateResolution, reads a ConditionTag, or passes the pattern to anything that does"
    requirement: "DIET-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/AboutYouStepTests.swift#routerWalkVisitsFirstFiveStepsInOrder -- dietary pattern immediately follows age"
        status: pass
      - kind: other
        ref: "grep -vE comment-stripped DietaryPatternStepView.swift | grep -c GateResolution == 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "CROSSGEN-03: PrivacyExplainerStepView explains privacy on one screen, in plain language, before anything is requested -- presents the three locked bullets and an acknowledgement only, with no toggle, permission prompt, or sync call anywhere in the file"
    requirement: "CROSSGEN-03"
    verification:
      - kind: other
        ref: "grep -c 'OnboardingCopy.Privacy' PrivacyExplainerStepView.swift == 5; grep -vE comment-stripped PrivacyExplainerStepView.swift | grep -ciE 'Toggle|requestAuthorization|requestWhenInUse' == 0"
        status: pass
    human_judgment: false
  - id: D6
    description: "CROSSGEN-05: all six screens register through OnboardingStepPresenting/StepRegistry from one file (AboutYouRegistration.swift, six literal StepRegistry.register calls) rather than editing OnboardingRootView or StepRegistry's lookup; StepRegistry.unregisteredSteps shrinks by exactly the six steps after registerAll(); no view in this plan declares a NavigationStack of its own"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/AboutYouStepTests.swift#registerAllResolvesRealViewsAndShrinksUnregisteredSteps"
        status: pass
      - kind: other
        ref: "grep -c 'StepRegistry.register' AboutYouRegistration.swift == 6; grep -rl NavigationStack RithamApp/Ritham/Onboarding/Steps/ returns nothing"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 13: About You -- Welcome, Register, Age, Age-Ineligible, Dietary Pattern, Privacy Summary

**Six onboarding screens (welcome, explanation-register choice, age with bounded numeric validation, the under-13 block screen, dietary pattern, and the privacy explainer) composed from plan 01-12's shared components, with the 13+ age floor and DIET-01's gate-isolation kept structurally rather than by review.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3
- **Files modified:** 11 (9 created, 2 modified -- `OnboardingRootView.swift` and the regenerated `.xcodeproj`)

## Accomplishments
- `WelcomeStepView` carries the full decorative treatment (`DecorativeSurface.welcome`) with Momo reserved as an optional bounded inset card (`MomoHeroCard`) that renders nothing when no asset is supplied -- the mascot go/no-go decision stays open per `01-CONTEXT.md`, and no artwork was commissioned or invented
- `ExplanationRegisterStepView` resolves a real architectural tension between this plan's literal instruction ("persist immediately") and plan 01-11's already-built `HealthDataStore` API (`UserProfileDraft.age` is required, and no profile can exist before Age runs): it writes through `HealthDataStore` only when a profile already exists, always sets `flow.answers.register` in memory, and `AgeStepView` folds that in-memory choice into its own first-ever `updateProfile` call -- the register reaches durable storage no later than the moment the 13+ floor clears
- `AgeStepView`'s `AgeValidator.validate(_:) -> Result<Int, AgeValidationError>` bounds Q0 to whole numbers 1-120 with no opinion on the number 13 -- the floor is purely a routing outcome `OnboardingRouter` resolves; the view hands the raw value to `flow.advance` without ever branching on eligibility itself, and its persist call to `HealthDataStore.updateProfile` sits inside `if age >= 13`, so a rejected value never reaches durable storage
- `AgeIneligibleStepView` is a single-step-back loop (`flow.goBack()`), not a dead end, rendered in a flat-charcoal-plus-off-white-card treatment matching the Required-blocking message row's pattern; it has no forward `flow.advance` call of its own
- `DietaryPatternStepView` collects Q0b directly after age (confirmed by a router-walk test), persists to the profile only, and never touches `GateResolution` or a `ConditionTag`
- `PrivacyExplainerStepView` presents CROSSGEN-03's three locked bullets and an acknowledgement only -- no toggle, permission prompt, or sync call anywhere in the file, keeping the "nothing shared or synced by default" promise by requesting and syncing nothing at all
- `AboutYouRegistration.registerAll()` registers all six screens with `StepRegistry` through six literal calls, in its own file, never invoked from the app entry point (plan 01-18 owns that bootstrap call)
- `OnboardingRootView` now injects `.explanationRegister(_:)` at the root (closing the gap 01-12-SUMMARY.md's "Next Phase Readiness" flagged), reading `flow.answers.register` first so the environment updates live the instant a user picks, falling back to the stored profile and then `.plainLanguage`
- `AgeValidationTests` (6 tests) and `AboutYouStepTests` (3 tests) both green; full `RithamTests` suite: 57 tests, 8 suites, all pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Welcome and explanation-register screens** - `0701419` (feat)
2. **Task 2: Age, age-ineligible, and dietary pattern screens** - `34ed653` (feat)
3. **Task 3: Privacy explainer and step registration** - `478661c` (feat)

## Files Created/Modified
- `RithamApp/Ritham/Onboarding/Steps/WelcomeStepView.swift` - Welcome screen, `MomoHeroCard` optional-asset slot
- `RithamApp/Ritham/Onboarding/Steps/ExplanationRegisterStepView.swift` - Register choice, deferred-persist pattern, retroactive `ExplanationRegister: Identifiable`
- `RithamApp/Ritham/Onboarding/Steps/AgeStepView.swift` - Q0, `AgeValidator`/`AgeValidationError`, gated persist
- `RithamApp/Ritham/Onboarding/Steps/AgeIneligibleStepView.swift` - Under-13 block screen, single-step-back loop
- `RithamApp/Ritham/Onboarding/Steps/DietaryPatternStepView.swift` - Q0b, retroactive `DietaryPattern: Identifiable`
- `RithamApp/Ritham/Onboarding/Steps/PrivacyExplainerStepView.swift` - Privacy explainer, acknowledgement only
- `RithamApp/Ritham/Onboarding/Steps/AboutYouRegistration.swift` - `registerAll()`, six `StepRegistry.register` calls
- `RithamApp/RithamTests/AgeValidationTests.swift` - 6 Swift Testing tests against `AgeValidator`
- `RithamApp/RithamTests/AboutYouStepTests.swift` - 3 Swift Testing tests: registration coverage, router-walk ordering, under-13 self-loop
- `RithamApp/Ritham/App/OnboardingRootView.swift` - added `.explanationRegister(_:)` injection (Rule 2 deviation)
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each task, per the established 01-09/01-10/01-11/01-12 pattern

## Decisions Made
- `ExplanationRegisterStepView` persists conditionally (profile-exists guard) rather than unconditionally as the plan's literal text reads -- see key-decisions for the full architectural rationale; confirmed via advisor review that this is the correct, minimal resolution requiring no change to `HealthDataStore`'s already-committed, already-tested API
- `ChoiceQuestionView`'s own `prompt` parameter carries the screen headline for `ExplanationRegisterStepView`/`DietaryPatternStepView`, rather than duplicating it through `RithamScreen`'s separate `headline` slot
- `DietaryPatternStepView`'s CTA reuses `OnboardingCopy.Age.cta` ("Continue") since `OnboardingCopy.Diet` has no dedicated CTA constant and 01-UI-SPEC.md's Copywriting Contract lists no CTA row for Q0b
- `AgeIneligibleStepView` uses `DecorativeSurface.flat` (not a distinct surface value) for its header, per `DecorativeSurface.swift`'s own enumeration of "Age blocking (under 13)" as one of the nine flat-only screens; the off-white-card distinction is body-content styling, applied via a `RoundedRectangle` wrapping the blocking message

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `ExplanationRegisterStepView`'s literal "persist immediately" instruction conflicts with `HealthDataStore`'s required, non-optional `UserProfileDraft.age`**
- **Found during:** Task 1, before writing any code (caught during context-reading, confirmed via advisor review)
- **Issue:** The plan's Task 1 text instructs `ExplanationRegisterStepView` to call `HealthDataStore.updateProfile` unconditionally on continue. But `UserProfileDraft.age` is a required `Int`, and the explanation-register screen runs *before* Age in the flow (`.welcome -> .explanationRegister -> .age -> ...`) -- no `UserProfile` can exist yet the first time any user reaches this screen, since a `UserProfile` cannot be created without a real age. `HealthDataStore.updateProfile`'s own doc comment (plan 01-11) explicitly names the age step as "the very first write," confirming the persistence layer was built expecting this ordering.
- **Fix:** `ExplanationRegisterStepView` now writes through `HealthDataStore` only when `loadProfile()` already succeeds (a later visit, or a Settings edit reusing this screen per plan 01-17); it always sets `flow.answers.register` in memory regardless. `AgeStepView` folds `flow.answers.register` into its own first-ever `updateProfile` call, so the register is durably persisted no later than the moment the profile is created. No change to `HealthDataStore.swift` itself.
- **Files modified:** `RithamApp/Ritham/Onboarding/Steps/ExplanationRegisterStepView.swift`, `RithamApp/Ritham/Onboarding/Steps/AgeStepView.swift`
- **Verification:** `./Scripts/build-app.sh test -only-testing:RithamTests` (57/57 pass, including `HealthDataStoreTests` unaffected); `grep -c 'updateProfile' ExplanationRegisterStepView.swift` returns 3, satisfying the plan's own acceptance criterion
- **Committed in:** `0701419` (Task 1 commit)

**2. [Rule 2 - Missing Critical] `OnboardingRootView` never called `.explanationRegister(_:)`**
- **Found during:** Task 1, per the orchestrator's context note and 01-12-SUMMARY.md's "Next Phase Readiness" flag
- **Issue:** `RegisterEnvironment.swift` (plan 01-12) built the `explanationRegister` environment key with a `.plainLanguage` default, documented as "the app's real root always injects the value loaded from `UserProfile`" -- but no call site existed yet. Without it, `GlossaryTerm` would silently render the default register everywhere, never the user's actual choice.
- **Fix:** Added `.explanationRegister(currentRegister)` to `OnboardingRootView.body`, with `currentRegister` reading `flow.answers.register` first (so the environment updates live the instant a user picks, since `flow` is `@Observable`), falling back to the stored profile's value, then `.plainLanguage`.
- **Files modified:** `RithamApp/Ritham/App/OnboardingRootView.swift`
- **Verification:** `./Scripts/build-app.sh build` (BUILD SUCCEEDED); `grep -c 'explanationRegister' OnboardingRootView.swift` returns 3 (the modifier call, the property comment, and the doc reference)
- **Committed in:** `0701419` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking architectural resolution, 1 missing-critical-functionality addition). Both confirmed via advisor review before implementation.
**Impact on plan:** Neither fix changes any already-committed file from a prior plan (`HealthDataStore.swift` is untouched); both stay within files this plan already owns or `OnboardingRootView.swift`, which the orchestrator's own context note assigned to this plan. No scope creep, no new architecture, no new persisted field.

## Issues Encountered
None beyond the deviations above -- no simulator flakiness this run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All six "About You" screens are registered and reachable through `StepRegistry`; `AgeValidator`, the deferred-persist pattern, and the gated-persist pattern are ready for plan 01-17's edit-answer flow to reuse against the same `HealthDataStore` call sites
- `OnboardingRootView` now injects the explanation register live from `flow.answers.register`/the stored profile -- `GlossaryTerm` anywhere downstream renders the user's actual choice, not just the environment key's default
- `StepRegistry.unregisteredSteps` now excludes `.welcome`, `.explanationRegister`, `.age`, `.ageIneligible`, `.dietaryPattern`, `.privacyExplainer` -- twelve steps remain for plans 01-15/01-16/01-17 to cover before 01-18's `PhaseCoverageTests` can pass
- No blockers for the next plans in wave sequence (01-15, 01-16)

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 9 created files and 2 modified files verified present on disk; all 3 task commit hashes
(0701419, 34ed653, 478661c) verified in git log.
