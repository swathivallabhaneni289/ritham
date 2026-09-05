---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
current_phase_name: core-tracking-adjusted-guidance
status: executing
stopped_at: Completed 02-11-PLAN.md
last_updated: "2026-09-05T12:28:41.676Z"
last_activity: 2026-09-05
last_activity_desc: Phase 02 execution started
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 30
  completed_plans: 25
  percent: 20
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-19)

**Core value:** Every user 13 or older, any health background — can safely track real training and
keep a fair, forgiving consistency streak, with core tracking always free and never subject to
comparison or ranking.
**Current focus:** Phase 02 — core-tracking-adjusted-guidance

## Current Position

Phase: 02 (core-tracking-adjusted-guidance) — EXECUTING
Plan: 12 of 16
Status: Ready to execute
Last activity: 2026-09-05 — Phase 02 execution started

Progress: [██░░░░░░░░] 20%

## Performance Metrics

**Velocity:**

- Total plans completed: 14
- Average duration: N/A
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 14 | - | - |

**Recent Trend:**

- Last 5 plans: N/A
- Trend: N/A

*Updated after each plan completion*
| Phase 01 P01 | 20min | 3 tasks | 9 files |
| Phase 01 P03 | 20min | 3 tasks | 9 files |
| Phase 01-onboarding-safety-intake P05 | 20min | 2 tasks | 4 files |
| Phase 01-onboarding-safety-intake P06 | 35min | 3 tasks | 5 files |
| Phase 01-onboarding-safety-intake P07 | 35min | 3 tasks | 9 files |
| Phase 01-onboarding-safety-intake P09 | 55min | 3 tasks | 10 files |
| Phase 01-onboarding-safety-intake P10 | 45min | 3 tasks | 8 files |
| Phase 01 P11 | 45min | 3 tasks | 9 files |
| Phase 01-onboarding-safety-intake P12 | 40min | 3 tasks | 9 files |
| Phase 01-onboarding-safety-intake P13 | 55min | 3 tasks | 11 files |
| Phase 01-onboarding-safety-intake P15 | 50min | 3 tasks | 13 files |
| Phase 01-onboarding-safety-intake P16 | 90min | 3 tasks | 13 files |
| Phase 01-onboarding-safety-intake P17 | 50min | 3 tasks | 12 files |
| Phase 02 P01 | 20min | 3 tasks | 7 files |
| Phase 02 P02 | 4min | 3 tasks | 6 files |
| Phase 02 P03 | 47min | 3 tasks | 6 files |
| Phase 02 P04 | 25min | 2 tasks | 3 files |
| Phase 02 P05 | 20min | 3 tasks | 9 files |
| Phase 02 P06 | 55min | 3 tasks | 14 files |
| Phase 02 P07 | 30min | 2 tasks | 4 files |
| Phase 02 P08 | 45min | 3 tasks | 8 files |
| Phase 02 P09 | 15min | 3 tasks | 5 files |
| Phase 02 P10 | 90min | 3 tasks | 6 files |
| Phase 02 P11 | 45min | 3 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Ingest: Local-first data storage with cloud sync as backup only (not source of truth).
- Ingest: Forgiveness mechanics (shields, comeback repair, injury guardrail) are never
  monetized, permanently.

- Ingest: `dietary_pattern` is strictly downstream of the Clearance Gate, never part of
  gate-resolution logic.

- Roadmapping: Cycle tracking, weekly timetable, and full group goal-events deferred to v2 to
  keep the pre-launch GDPR/CCPA privacy review scoped for v1; dietary pattern and recovery-aware
  Momentum (self-report slice) kept in v1 since they add no new sensitive-data review surface.

- 2026-09-01: Calibration (ONBOARD-01) is no longer onboarding's first mandatory session — it
  moves to a triggered pre-assessment inside a future exercise-recommendation feature
  (provisionally Phase 2), factoring in age and condition tags. Onboarding now ends after the
  safety screening. Calibration domain/UI kept intact, router-unreachable, for reuse.

- 2026-08-24: Ritham has a permanent 13+ age floor — no under-13 support in any form, no
  parental-consent flow for any age. Reverses the 2026-08-22 tiered-consent design. Removed the Go
  consent-service backend and 3 other now-dead plans from Phase 1 (18 → 14 plans). See PROJECT.md
  Key Decisions and `01-CONTEXT.md` D-14/D-15.

- [Phase ?]: Extracted CTA label text without brackets for routineClearanceCTA/urgentClearanceCTA per the plan's literal instruction
- [Phase ?]: 01-03: expiry(from:calendar:) derived from a private months constant instead of a TimeInterval validityWindow, to avoid leap-year/DST drift (Rule 1 deviation)
- [Phase ?]: 01-03: ConditionTag.under18Minor has no producer yet; tracked as an open gap for plan 01-06/01-07/01-11
- [Phase ?]: 01-05: Extended WalkProgress/LiftProgress with defaulted distance/load measurement fields (Rule 3) so CalibrationBaseline.derive computes a real, direction-correct pace/weight instead of a formula invariant to or inverted relative to the measurement
- [Phase ?]: 01-05: Corrected the provisional pace zone from a running-pace band to a genuine comfortable-walk band (660-840 s/km) to match D-03's under-loading requirement
- [Phase ?]: Added the ConditionTag.under18Minor producer inside TagDerivation.deriveTags (age < 18), closing the gap 01-03-SUMMARY.md flagged — without it §3's Under-18 nutrition required-blocking row could never fire for any minor — Rule 2 deviation; verified end-to-end via GateResolution.resolve
- [Phase ?]: 01-07: Added Codable conformance to ScreeningAnswers/SCOFFResponses/DietaryPattern/CalibrationBaseline and their nested types (Rule 3), since OnboardingAnswers' own required Codable conformance was structurally impossible without them
- [Phase ?]: 01-07: OnboardingRouter.nextStep's .age/.ageIneligible branch now holds at .age when age is unanswered (nil), instead of defaulting forward — an unanswered age must never reach the health screening (Rule 2 fix, caught in advisor review before finalizing)
- [Phase ?]: 01-07: needsSeverityFollowUps treats eating-disorder-history as a category needing follow-ups (its follow-up is SCOFF, reached via severityFollowUps -> scoffFollowUp) so an eating-disorder-only checklist selection still reaches SCOFF per D-10
- [Phase 01-09]: iOS app target scaffolded via xcodegen (project.yml -> Ritham.xcodeproj), iOS 17.0 deployment floor confirmed against SDK 26.5, Swift 6 strict concurrency — Reproducible/reviewable project generation instead of a hand-authored opaque .xcodeproj; iOS 17.0 required by SwiftData
- [Phase 01-09]: OnboardingRootView holds the sole NavigationStack; OnboardingStepPresenting + StepRegistry are the only mechanism for contributing a screen (CROSSGEN-05 structural enforcement) — Prevents any age-based navigation fork from ever being introduced by a later screen plan
- [Phase ?]: 01-10: BandGeometry's flat-margin split derives from only the fixed 57-degree angle and the render rect (span=height/tan(angle), margin=(width-span)/4 per side), producing 13-17% usable margins at real portrait header sizes rather than a knife-edge value that only barely passes a bare-positive test
- [Phase ?]: 01-10: DecorativeSurface.flat's header comment enumerates nine flat-charcoal screens (not the plan's stated ten) to match 01-UI-SPEC.md's 2026-08-23 update removing the under-13-halt/13-17-partial-gate rows after the permanent 13+ age floor decision
- [Phase ?]: 01-11: Only the derived eating-disorder outcome is stored (edScreenOutcomeRaw), never the five raw SCOFF answers
- [Phase ?]: 01-11: HealthDataStore.updateProfile treats a nil register/dietaryPattern in the draft as 'leave unchanged'; only invalidateSection clears those fields to unanswered
- [Phase ?]: 01-11: invalidateSection deletes the edited section's ConditionTagRecords rather than stamping editedAt, so an overdue tag's re-screen clock is never silently reset by starting an edit
- [Phase ?]: 01-11: File-protection read-back verification throws on-device only, logs on Simulator — Simulator's host filesystem does not honor Data Protection classes
- [Phase ?]: 01-12: ChoiceQuestionView's ChecklistItem-specific initializer defers directly to ChecklistSelection.toggle(_:) rather than reproducing its exclusive-option invariant through the generic ChoiceSelectionReducer
- [Phase ?]: 01-12: ChecklistItem: Identifiable conformance added at the UI layer (RithamApp target), not RithamCore, since Identifiable is a ForEach-driven UI concern RithamCore has no reason to carry
- [Phase 01]: 01-13: ExplanationRegisterStepView persists conditionally (profile-exists guard) rather than unconditionally; AgeStepView folds the in-memory register choice into its own first-ever updateProfile call, since UserProfileDraft.age is required and no profile can exist before Age runs (Rule 3 deviation)
- [Phase 01]: 01-13: OnboardingRootView now injects .explanationRegister(_:) at the root, reading flow.answers.register first, then the stored profile, then .plainLanguage (Rule 2 deviation, closes gap flagged by 01-12-SUMMARY.md)
- [Phase 01]: 01-15: OnboardingFlow.calibrationMode (transient, non-Codable) carries the intro's activity choice to the session screen since OnboardingRouter never branches on it and CalibrationMode has no Codable conformance to add to OnboardingAnswers
- [Phase 01]: 01-15: CalibrationSessionSource conformers (PedometerSession/StopwatchSession/LiftSessionRecorder) are non-actor-isolated with @unchecked Sendable + nonisolated(unsafe) storage, not @MainActor -- Swift 6 rejects an isolated conformance to a Sendable-inheriting protocol
- [Phase 01]: 01-15: Added OnboardingCopy.Calibration.skipCTA ('Skip for now'), transcribed verbatim from D-03's own decision text since 01-UI-SPEC.md's Copywriting Contract table has no dedicated row for it
- [Phase ?]: 01-16: Centralized every §1.2/§1.4 screening question prompt and option label into new ScreeningCopy.Gate/.FollowUp/.EatingPattern namespaces (RithamCore), plus ChecklistItem.displayName -- one reviewable file for LAUNCH-01/LAUNCH-02 counsel/clinician review instead of scattering doc-sourced wording across seven view files
- [Phase ?]: 01-16: SeverityFollowUpView is one data-driven screen -- a [ChecklistCategory: [SeverityQuestion]] table built via a generic severityQuestion(...) helper -- covering all eight §1.4 category groups instead of eight hand-built view bodies
- [Phase ?]: 01-16: Gate-pass affirmation shown via .alert gated on GateResolution.resolve's own interstitial == .none result, since no dedicated OnboardingStep case exists for it; 'shown once' for the opening disclaimer tracked via the existing OnboardingAnswers.completedSteps field, not a new persisted UserProfile column
- [Phase ?]: 01-17: HealthProfileView is store-driven (reconstructs GateResolutionResult from persisted tags via GateEscalation.escalate), not OnboardingFlow-driven, so it works reachable-anytime after onboarding ends
- [Phase ?]: 01-17: EditAnswerFlow reuses plan 01-16's registered screening screens via StepRegistry, neutralizing their flow.advance side effect by popping flow.path back after each edit, rather than forking a second copy of any question
- [Phase ?]: 01-17: Added HealthDataStore.conditionTagStatuses(now:) (Rule 2) -- no existing accessor exposed per-tag validity, which D-08's overdue-tag display requires
- [Phase ?]: 02-01: CardioProgress.recordInterruption() zeroes only continuousDuration, never distanceMeters/elevationGainMeters -- ground already covered during a cardio session stays recorded, unlike WalkProgress's calibration-specific full reset
- [Phase ?]: 02-01: GradeAdjustedPace.adjustedSecondsPerKm divides raw pace by a grade-derived effort factor (not multiplies) -- uphill yields a faster/smaller number, downhill benefit peaks at -10% and reverses past it due to eccentric-braking cost
- [Phase 02]: 02-02: PlateCalculator bounds target weight at 1000 kg as the ASVS V5 'absurdly large' ceiling (no plan-specified number existed)
- [Phase 02]: 02-02: Equipment.stackMachine.defaultBarWeightKg is 0 (not optional), documented as unread by PlateCalculator's pinStack path
- [Phase 02-03]: SupersetGroupID created a task early (in Superset.swift, Task 1 not Task 2) to break a genuine forward-dependency: LiftSet.supersetGroupID needs the type to compile, and SupersetGrouping's own functions take/return LiftSession, so reordering the other direction doesn't work either. — Stub-then-extend preserves Task 2's own acceptance greps against Superset.swift unchanged.
- [Phase ?]: 02-04: mostRestrictive folds via .min() not .max() since ContentPermission's declaration order is ascending permissiveness (none<educationOnly<full), the inverse of ClearanceGate's ascending restrictiveness
- [Phase ?]: 02-04: Nutrition recommended-gate rows are educationOnly only when the row's own prose forbids a personalized quantity; severeFoodAllergy, clinicianPrescribedDietOrMealPlan, and eatingDisorderSelfReportedNegativeScreen are full since their recommended gate is for an unrelated reason
- [Phase ?]: 02-04: WorkoutGuidanceCatalog.referralMessage aliases ScreeningCopy.requiredBlockingMessage (section 4.6) rather than re-transcribing it, avoiding two divergent copies
- [Phase ?]: 02-05: requiredBlocking zeroes Plan.FrequencyPerWeek too, not just Sessions -- the stricter reading of the action text's 'no numeric field populated anywhere' requirement — No consumer exists yet; costs nothing and closes a gap between the acceptance criteria and the action text
- [Phase ?]: 02-05: Added a third sentinel error (ErrUnknownGuidancePermission) so an unrecognized permission value fails closed with 400 rather than silently defaulting to a full plan — The plan only specified sentinels for frequency and experience level; an unhandled fall-through is the wrong failure mode for a health-adjacent gate
- [Phase 02]: 02-06: HomeHubView uses DecorativeSurface.boundedHeaderOnly (not .flat) since it introduces/explains rather than collecting health data
- [Phase 02]: 02-06: Regenerated and committed Ritham.xcodeproj/project.pbxproj alongside each task adding new files/directories -- xcodegen's directory-scan source list requires regeneration for xcodebuild to see new files (Rule 3 deviation)
- [Phase ?]: 02-07: presentableGuidance(for:) collapses the plan's three-tier description into two branches, since section 3's own row text already carries the correct education-only-vs-full framing
- [Phase ?]: 02-07: rateLimitingHeartOrBPMedication's nutrition fallback is a dedicated no-rule message, not referralMessage, since it has no section 3 row but carries a full permission -- avoiding a HEALTH-04 correctness bug
- [Phase ?]: 02-07: sodium/saturated-fat reference-figure publishing-body attribution (NHLBI/AHA) resolved via contextual sentence-proximity inference, since the source document names an explicit body only for the ADA and CDC figures
- [Phase ?]: 02-07: all three dietary-pattern.md footnotes (flag1/2/3) treated as Ritham-own-construction flags on their swap cells, matching the plan's stated count of three flagged inference footnotes
- [Phase ?]: 02-08: Splits stored via a file-local Codable DTO (EncodedSplit) rather than adding Codable to RithamCore's CardioSplit, keeping this plan's edits confined to its own file list
- [Phase ?]: 02-08: experienceLevel() maps a provisional baseline to .beginner and a measured baseline to .intermediate -- Phase 2 has no specified pace/weight-threshold mapping across all four buckets for a real measurement, documented placeholder for a future phase to refine
- [Phase ?]: 02-09: GPSTrackingSession requests when-in-use authorization only, never always authorization, and confines startUpdatingLocation to session start with a matching stop on pause/end -- exposes authorizationStatus/requiresManualFallback so the view layer (02-10) can fall back to StopwatchCardioSession on denial without this type presenting UI itself
- [Phase ?]: 02-09: MotionActivityDetector's foreground/background lifecycle is left to the caller (plan 02-10's view) via startObserving/stopObserving, matching PedometerSession's precedent of not self-managing app lifecycle; running wins over walking when CMMotionActivityManager reports both above threshold confidence
- [Phase 02-10]: OnboardingFlow (inside StepRegistry.swift) gained transient cardioActivityType/cardioCaptureMode carriers and returnToHub(), matching the existing calibrationMode precedent, to hand the picker's choice to the session screen and pop two levels back to the hub on finish.
- [Phase 02-10]: CardioSessionModel.pause() calls StopwatchCardioSession.stop() rather than .pause(), since .pause() zeroes continuousDuration (calibration's break-continuity semantics) while .stop() freezes it -- caught by a failing unit test before commit.
- [Phase 02-10]: No coordinate/location-trail data is persisted anywhere in the codebase (CardioProgress/CardioSessionRecord/GPSTrackingSession all discard per-sample coordinates). CardioHistoryView's MapKit route map is real code gated on empty input (called with [] today); RouteComparisonView's 'same route' is approximated as same-activity-type-within-a-250m-distance-band rather than real polyline matching.
- [Phase ?]: 02-11: Pre-fill seeding reads HealthDataStore.autoFillSet(forExercise:) alone, never the in-progress unsaved session's own newly-logged sets, per the plan's explicit no-filter/no-fallback instruction
- [Phase ?]: 02-11: PlateCalculatorModel.isInvalidInput is true whenever result == nil (including an empty target field), matching the plan's literal behavior list rather than special-casing an untouched field
- [Phase ?]: 02-11: Superset join/ungroup and the plate-calculator sheet were wired into StrengthSessionView.swift during Task 3 (not Task 2), since Task 2's file list omitted StrengthSessionView.swift but the plan's success criteria required the calculator to be reachable from set entry

### Pending Todos

- GitHub issue #1's device-continuity question is still open: whether/how a user's training data
  should survive a device change (its parental-consent-continuity motivation is now moot, but the
  general question for all users was never resolved — see the Option A/B/C discussion in the
  2026-08-23/24 session). Not yet decided or built.

- Workout plan frequency selection (3/5/7 days a week) and experience-level scaling
  (beginner through daily exerciser) for Phase 2 — connects to ONBOARD-01's triggered
  calibration pre-assessment. See `.planning/todos/pending/2026-09-03-workout-plan-frequency-selection-and-experience-scaling.md`.

### Blockers/Concerns

- Phase 5 (Launch Readiness) requires external sign-off from counsel, a clinician, and a
  registered dietitian before public App Store submission — schedule these reviews early enough
  that they don't block the release once Phases 1-4 are code-complete.

- ~~01-18's PhaseCoverageTests (unregisteredSteps-is-empty) will trip...~~ Stale as of
  2026-09-01: verified this already passes. `OnboardingCompletionRegistration` (registering
  `.screeningComplete`/`.home`) is already wired into `StepBootstrap.registerAllSteps()`;
  presumably fixed in a prior session not reflected here. See `deferred-items.md`, itself also
  stale on this point.

- Real (not stale) test-infrastructure issue found 2026-09-01: `xcodebuild test` run against the
  full RithamTests target intermittently fails with steps reported as "unregistered" that are, in
  fact, registered. Confirmed via `git stash` that this predates the 2026-09-01 calibration pivot.
  Root cause: `StepRegistry`'s shared static state races across Swift Testing suites that run
  concurrently -- each suite's own `.serialized` trait only serializes tests *within* that suite,
  not across suites, so one suite's `StepRegistry.reset()` can interleave with another suite's
  in-flight assertions. Every suite passes reliably run individually
  (`-only-testing:RithamTests/<Suite>`); only the full concurrent run flakes. Not fixed --
  needs its own pass (likely: merge the `StepRegistry`-touching suites into one `.serialized`
  suite, or find swift-testing's real cross-suite serialization mechanism if one exists).

- DIET-01 (Phase 2) stays Pending: 02-06's HomeHubView -> Settings -> DietPlanView route is wired and unit/integration-verified but the interactive spot-check (launch app, click through) was not run -- no touch-injection tool (idb/XCUITest) is available in this environment, only simctl. Next interactive UAT pass on Phase 2 should run this click-through and mark DIET-01 complete if it renders.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-09-05T12:28:33.087Z
Stopped at: Completed 02-11-PLAN.md
(ONBOARD-01) moved out of onboarding entirely this session -- see `PROJECT.md` Key Decisions,
`REQUIREMENTS.md`'s rewritten ONBOARD-01, and `ROADMAP.md`'s revised Phase 1 criterion 1 and new
Phase 2 criterion 8 (provisional). This resolved 01-18's physical-device GPS-walk verification
task (moot now) but opened a new one: `RadialSessionTimer` (the calibration session screen's new
radial progress ring, built this session) has never been verified at AX3/AX5 -- that screen is
currently unreachable in the running app, so this check waits for whichever phase builds the
recommend-exercises trigger, not 01-18.

Phase 999.3 backlog (onboarding visual polish, round 2): item 1 (the "plain terms" Privacy
headline complaint) is resolved -- changed to "Your privacy, up front.", confirmed by direct
feedback. Item 2 (calibration timer redesign) is resolved -- `RadialSessionTimer` ships, plus an
upfront duration statement. Item 3 (`ScreeningOpeningDisclaimerView`'s flat-surface tension) has a
researched recommendation (treat it like Privacy Explainer: `DecorativeSurface.boundedHeaderOnly`,
not full arcs) but was never confirmed or implemented -- the conversation moved to the calibration
pivot before that AskUserQuestion resolved. Item 4 (scroll concern) untouched.

Next step: 01-18's remaining task is now just the AX3/AX5 accessibility pass across onboarding
(the GPS-walk task is moot). Also still open: item 3 above needs a decision before implementing,
and the Phase 2-vs-new-phase question for the exercise-recommendation feature (Phase 2 criterion 8
is a placeholder, deliberately not settled). A real, pre-existing `StepRegistry` test-concurrency
flake was found and documented in Blockers/Concerns but not fixed -- worth its own pass before
trusting a full `xcodebuild test` run's pass/fail as-is.
Resume file:
None
