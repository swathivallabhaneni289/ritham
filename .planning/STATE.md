---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 04.1
current_phase_name: group-goal-events-accountability-circles
status: executing
stopped_at: Completed 04.1-09-PLAN.md
last_updated: "2026-09-10T14:37:51.144Z"
last_activity: 2026-09-09
last_activity_desc: Phase 04.1 execution started
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 60
  completed_plans: 52
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-19)

**Core value:** Every user 13 or older, any health background — can safely track real training and
keep a fair, forgiving consistency streak, with core tracking always free and never subject to
comparison or ranking.
**Current focus:** Phase 04.1 — group-goal-events-accountability-circles

## Current Position

Phase: 04.1 (group-goal-events-accountability-circles) — EXECUTING
Plan: 10 of 17
see 02-16-SUMMARY.md) intentionally deferred to a single end-of-project testing pass, per the
user's 2026-09-06 decision (see PROJECT.md Key Decisions). Not a blocker on further phases.
Status: Ready to execute
(run /gsd-execute-phase 4.1)
batched verification pass runs
Last activity: 2026-09-09 — Phase 04.1 execution started

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
| Phase 02 P11 | 3h44m | 3 tasks | 5 files |
| Phase 02 P13 | 45min | 3 tasks | 5 files |
| Phase 02 P14 | 35min | 2 tasks | 4 files |
| Phase 02 P12 | 25min | 3 tasks | 9 files |
| Phase 02 P15 | 45min | 3 tasks | 5 files |
| Phase 03 P03 | 30min | 3 tasks | 2 files |
| Phase 03-momentum-recovery P04 | 15min | 3 tasks | 7 files |
| Phase 03-momentum-recovery P05 | 25min | 3 tasks | 8 files |
| Phase 03-momentum-recovery P06 | 45min | 3 tasks | 12 files |
| Phase 03-momentum-recovery P07 | 40min | 3 tasks | 6 files |
| Phase 03-momentum-recovery P08 | 50min | 3 tasks | 8 files |
| Phase 03-momentum-recovery P09 | 65min | 3 tasks | 11 files |
| Phase 03-momentum-recovery P10 | 25min | 3 tasks | 4 files |
| Phase 04.1 P01 | 30min | 3 tasks | 9 files |
| Phase 04.1 P02 | 20min | 2 tasks | 9 files |
| Phase 04.1 P03 | 65min | 3 tasks | 14 files |
| Phase 04.1 P04 | 100min | 3 tasks | 22 files |
| Phase 04.1 P05 | 25min | 3 tasks | 17 files |
| Phase 04.1 P06 | 70min | 3 tasks | 15 files |
| Phase 04.1 P07 | 25min | 3 tasks | 16 files |
| Phase 04.1 P08 | 45min | 3 tasks | 11 files |
| Phase 04.1 P09 | 40min | 3 tasks | 16 files |

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
- [Phase ?]: 02-11 (post-review fix): Gated the superset join action on both exercises already having a working set, and branched the section renderer on group membership rather than group.count > 1, since SupersetGrouping.join only assigns a group to a set (not a bare exercise-order entry) -- caught by advisor review
- [Phase 02]: 02-13: Pre-assessment walk uses StopwatchCardioSession only (no GPS), since the completion bar is duration-only and GPS would reintroduce calibration's blocking-prompt risk — Keeps ONBOARD-01's pre-assessment zero-friction, matching D-02's precedent
- [Phase 02]: 02-13: WorkoutPlanClient's local referral plan reuses WorkoutGuidanceCatalog.referralMessage rather than a second transcription — Prevents the on-device short-circuit and the Go service's own required-blocking note from ever drifting into two different messages
- [Phase ?]: 02-14: Heart-rate display deliberately omitted from the always-free list (no wearable pairing exists in this build); WEAR-01 (v2) is the requirement that restores it — Naming an unbuilt capability would break MONETIZE-01's own 'matches what's actually gated (or not) elsewhere' property
- [Phase ?]: 02-14: WeeklyFrequencyOption.all is a hardcoded [3,5,7] literal, not derived from HealthDataStore.supportedWeeklyFrequencies at declaration time — HealthDataStore is @MainActor; the option type must stay nonisolated to satisfy Identifiable generically for ChoiceQuestionView. A dedicated test pins the two lists together
- [Phase 02]: 02-12: AdjustedGuidanceBanner surfaces neverTriggersStreakLoss independent of the permission branch, since heartDiseaseRecentEventOrSymptomatic carries a zero-content workout permission and would otherwise lose that framing behind the referral message — Keeps HEALTH-03's streak-safety framing visible even under a required-blocking workout gate
- [Phase 02]: 02-12: NutritionGuidanceSection treats a nil stored dietaryPattern (profile never visited DietPlanView) as the one input suppressing both swaps and education, distinct from an explicitly-chosen DietaryPattern.none which still shows baseline swaps — Avoids silently defaulting an unanswered dietary preference to an omnivore swap list
- [Phase ?]: 02-15: StrengthHistoryModel.allSessionStartDates is populated only inside the model's existing full-store load(), never a dedicated year-list-only load, so YearJumpDatePicker's offered periods never require a separate whole-store read
- [Phase ?]: 02-15: SessionEditView was built and unit-tested at the model level but is not wired into StrengthHistoryView as a reachable sheet in this plan -- Task 3's file scope deliberately excluded StrengthHistoryView.swift; a future plan/task must add the .sheet(item:) entry point from a history row
- [Phase ?]: 03-03: Shield-accrual-isolation tests start from currentStreak: 20 (not 0) to avoid an unintended collision with milestone tier 12
- [Phase ?]: 03-03: The rebuilt-streak-reaches-first-met-week test constructs its ledger post-rebuild directly rather than chaining reconcile calls, after finding that a stale expired comeback window can re-fire its rebuild transition against a same-call subsequent met week in a large catch-up fold -- implemented literally per plan scope, flagged as a known edge case
- [Phase ?]: HealthDataStore.supportedMomentumTargets reads MomentumTarget.supported directly (no second literal), unlike supportedWeeklyFrequencies -- MomentumTarget.supported has no main-actor isolation conflict.
- [Phase ?]: loadMomentumLedger sorts milestone/comeback-window fetches (awardedAt/opensAt ascending) so a save-then-load round trip is order-stable and Equatable-comparable in tests.
- [Phase ?]: Did not add a ComebackWindow.resolved field to fix 03-03's flagged stale-window edge case -- out of this plan's file scope (would require touching MomentumReconciliation.swift); carried forward to whichever plan next touches reconciliation logic.
- [Phase ?]: 03-05: Locked deviation from 03-RESEARCH.md's Data Model Shape -- MovementSnapshotDay is derived at read time from existing CardioSessionRecord/LiftSessionRecord rows rather than a new append-only MovementSnapshotEntryRecord, making MOMENTUM-07's 'no streak, shield or target attached' structurally true.
- [Phase ?]: 03-05: MomentumSummaryReader.summary(now:) tolerates a profile-less store (catches HealthDataStoreError.profileMissing from activeConditionTags and treats it as an empty tag set) since Momentum reads must never throw on an empty store.
- [Phase ?]: 03-05: Elapsed-week reconciliation assembly is capped at 104 weeks per read (T-3-10); a long-idle store folds only the most recent bounded window and the ledger anchor advances past skipped overflow weeks, a documented tradeoff.
- [Phase 03-06]: MomentumProgressBlocks.blockStates and every pure test helper on MomentumView are nonisolated static funcs -- SwiftUI's View protocol is itself @MainActor, so isolation is inferred onto every member of a conforming type by default and traps at runtime when called from Swift Testing's off-main-actor test functions
- [Phase 03-06]: Comeback Session CTA routes to flow.open(.cardioActivityPicker) only, per 03-UI-SPEC.md Component 4 leaving the single-entry-point choice to the executor
- [Phase 03-06]: OnboardingRouter.nextStep's exhaustive switch and OnboardingFlowStateTests' hardcoded step-count expectation were updated as required blocking fixes for adding OnboardingStep.momentum (not in this plan's stated file list, but a compile-time and test-gate necessity)
- [Phase ?]: 03-07: MomentumTargetView is a Settings-presented sheet, not a registered OnboardingStep -- recorded in the file's own header comment (routing from inside a sheet would push behind that sheet; every shipped Settings sub-screen is a sheet for this reason; matches WorkoutFrequencyView precedent).
- [Phase ?]: 03-07: HomeHubView's Momentum summary section holds a plain MomentumSummary? loaded via its own MomentumSummaryReader construction in onAppear (not a hub-owned view model), keeping D-08's 'not baked into a hub-specific view model' requirement structural, and wires flow.open(.momentum), the entry point 03-06-SUMMARY.md explicitly left as this plan's scope.
- [Phase 03-momentum-recovery]: 03-08: SleepQualityOption wraps SleepQuality with manual == / hash(into:) over rawValue rather than a cross-module retroactive Hashable conformance, matching WeeklyFrequencyOption/MomentumTargetOption's precedent.
- [Phase 03-momentum-recovery]: 03-08: RecommendationsModel exposes the RECOVERY-01 adjustment as side-channel private(set) properties (originalPlan/adjustedPlan/isDisplayingAdjustedPlan) rather than widening RecommendationsState.plan's associated type, so every pre-existing test/call site stayed unchanged.
- [Phase 03-momentum-recovery]: 03-08: Added .sleepCheckIn to OnboardingRouter.nextStep's terminal-steps switch and updated OnboardingFlowStateTests' hardcoded step count (25->26) as a Rule 3 compile/test-gate fix, not in the plan's stated file list.
- [Phase ?]: 03-09: MovementSnapshotToggleView uses the app's existing two-option ChoiceQuestionView chip control instead of a first-ever native SwiftUI.Toggle, per 03-UI-SPEC.md Component 9's measured-contrast rationale.
- [Phase ?]: 03-09: MovementSnapshotView/MovementSnapshotToggleView/MovementSnapshotRegistration live in their own MovementSnapshot/ directory (not Momentum/), so MOMENTUM-07's 'no streak, shield or target' requirement is a directory-scoped, mechanically checkable constraint rather than a per-file reading.
- [Phase ?]: 03-10: Directory-walk source-scan (FileManager.enumerator relative to #filePath) chosen over a checked-in file-name list for the MOMENTUM-06 no-sharing structural gate, guarded by a non-zero scanned-file-count assertion so it cannot pass vacuously.
- [Phase ?]: 03-10: ROADMAP.md's Phase 3 criterion 5 carries a dated (2026-09-06) annotation recording MOMENTUM-06's household-sharing half as scoped-deferred to Phase 4's HOUSEHOLD-01, mirroring Phase 2 criterion 6's precedent.
- [Phase ?]: 04.1-01: go mod tidy pruned google/uuid, minio-go, golang-jwt, and goexif since nothing imports them yet; all six approved, only pgx/v5 and golang-migrate/v4 landed as direct requires -- the rest re-enter go.mod when 04.1-03/04.1-04 import them, no re-approval needed
- [Phase ?]: 04.1-01: golang-migrate's pgx/v5 driver registers under the pgx5:// URL scheme, not postgres:// -- Migrate() rewrites RITHAM_DATABASE_URL's scheme locally so one env var serves both pgxpool and the migration runner
- [Phase ?]: 04.1-01: Docker Desktop is unavailable in this environment (Subscription Service Agreement declined) -- connected store/migration tests were verified against a native Homebrew postgresql@16 service instead; this fully proves the Postgres half, MinIO half of docker-compose.dev.yml remains container-unverified pending a working Docker install
- [Phase ?]: 04.1-02: GroupVisibilityScope ships exactly two cases (onlyMe, group); the household rung is a doc comment only, not a Swift case -- HOUSEHOLD-01 still Pending, matching MomentumVisibility's Phase 3 precedent
- [Phase ?]: 04.1-02: PrivateCompletionDetail stays in GoalEventModels.swift (plan's own 7-file cap) rather than a separate file; its doc comment states the never-referenced-by-network-type invariant, enforced later by plan 04.1-10's reflection-based wire-contract shape lock
- [Phase ?]: 04.1-03: VerifyIdentityToken took an added expectedNonce parameter and SignInWithApple/New took added displayName/audience parameters, not present in the plan's artifact signatures, since Task 1/2's own behavior lists structurally required them (Rule 3).
- [Phase ?]: 04.1-03: Added Service.User(ctx, userID) to session.go, outside Task 3's stated file list, since GET /v1/identity/me needs a way to read a user's current display name and no existing method provided one (Rule 3).
- [Phase ?]: 04.1-03: NewMux(idsvc) registers the four identity routes only when idsvc is non-nil; a missing RITHAM_DATABASE_URL leaves them unregistered (404) rather than crashing the already-shipped workout-plan route -- documented in main.go's own header comment.
- [Phase ?]: 04.1-03: RequireSession depends on a one-method authenticator interface, not the concrete *identity.Service, so middleware tests run with a stub and no database.
- [Phase ?]: 04.1-04: iphone-capture.heic fixture is a synthetic sips-transcoded HEIF container, not a real device photo -- avoids committing an actual personal photo's real GPS/location metadata into git history
- [Phase ?]: 04.1-04: Service and photo_handler.go depend on narrow structural interfaces (objectWriter, photoIngester, sharedURLSigner), not concrete *ObjectStore/*Service -- extends 04.1-03's authenticator-interface pattern so Ingest and every HTTP response branch are fully unit-tested without a running S3-compatible backend
- [Phase ?]: 04.1-04: MinIO/S3 wire behavior (PutObject/PresignedGetObject against a real bucket) remains unverified -- Docker unavailable in this environment, same carried-forward gap 04.1-01 already documented, now also touching internal/photo's connected tests
- [Phase ?]: 04.1-05: Corrected the plan's stated nonce flow (Rule 1) -- the SHA-256 digest, not the raw nonce, must be sent to both Apple's request.nonce and the server's AppleSignInRequest.nonce, verified directly against RithamService/internal/identity/apple_test.go before implementing.
- [Phase ?]: 04.1-05: HomeHubView's new social section follows the dashboard's actual shell-less shape (Phase 4's sixth-round checkpoint revision), not the plan text's stale 'card shell' description written the same day.
- [Phase ?]: 04.1-06: friends.New gained a contactMatchSalt parameter (read once at construction) since per-call env reads would be non-hermetic and could silently and partially change matching mid-run
- [Phase ?]: 04.1-07: PrivacyZoneRecord registered in RithamModelContainer.swift (schema list), not HealthDataStore.swift as the plan's files_modified literally named -- HealthDataStore.swift got the CRUD accessors instead, matching every other model's registration pattern in the container.
- [Phase ?]: 04.1-07: PrivacyZonesView conforms to OnboardingStepPresenting and registers under .privacyZones purely to satisfy StepRegistry.unregisteredSteps, while being reached only from SettingsView's sheet -- reusing SignInWithAppleView's registered-but-not-routed precedent.
- [Phase ?]: 04.1-07: Delete in Privacy Zones uses a native confirmationDialog with a role: .destructive action plus a RithamColor.destructive-outlined row button -- the first live activation of that reserved-since-Phase-1 color token.
- [Phase ?]: 04.1-08: Invite requires the inviter to already be a member of the group (not just friends with the invitee) -- Rule 2 fix closing a door-opening gap the plan's behavior list didn't explicitly cover
- [Phase ?]: 04.1-08: CompletionVisibility is wired via a SetCompletionVisibility setter, not a New() parameter, so groups.New's plan-locked signature stays exactly as documented while plan 04.1-10 gets a clean seam to wire a real implementation into
- [Phase 04.1-09]: Backend fix (Rule 3): Incoming's query joins users so FriendRequestResponse carries the requester's display name -- neither Request nor the wire type had one, blocking the plan's own must_haves truth that an incoming request shows a name.
- [Phase 04.1-09]: Contact-matching opt-in records the flag only and submits no digests (Rule 1 correction of the plan's own text): verified against contactmatch.go that MatchContacts searches contact_match_digests, written only by a user's own identifier submission -- this app has no source for one yet, so requesting Contacts access and submitting address-book digests would misuse the field for a query guaranteed to return zero matches.
- [Phase 04.1-09]: AddFriendView's 'Invite link or QR code' and 'Share directly' rows both create an invite via FriendsModel.createInvite() and present InviteQRView, differing only in whether the system share sheet auto-presents -- FriendConnectionPath.directShare stays unwired since a genuine in-person mechanism needs URL-scheme/universal-link handling this app doesn't have.

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

- ~~Real (not stale) test-infrastructure issue found 2026-09-01...~~ Fixed 2026-09-06 (plan
  02-16, Task 1). Root cause was as diagnosed: `StepRegistry`'s shared static state races across
  Swift Testing suites that run concurrently, because a per-suite `.serialized` trait only orders
  tests *within* that suite, not across suites. The fix uses Swift Testing's real cross-suite
  serialization mechanism -- nesting: `RithamApp/RithamTests/StepRegistrySerialization.swift`
  declares an empty `@Suite("StepRegistryTouchingSuites", .serialized)` enum, and each of the five
  registry-touching suites (`AppShellTests`, `AboutYouStepTests`, `CalibrationSourceTests`,
  `PhaseCoverageTests`, `ScreeningFlowTests`) plus the new `Phase2CoverageTests` is re-declared
  inside an `extension StepRegistryTouchingSuites { ... }` in its own file -- Swift permits a
  nested type to be introduced by an extension in a different file from the type it extends, and
  Swift Testing's `.serialized` trait serializes an entire suite subtree recursively, not just
  the suite it is attached to. Verified via ten consecutive full-target `xcodebuild test` runs,
  all green, with no run reporting a registered step as unregistered. A single unrelated crash
  (`PersistenceTests.makeContext()`, a SwiftData in-memory `ModelContainer` concurrency flake) was
  observed once across seventeen total full-target runs during this verification; it is a
  pre-existing, separate issue untouched by this fix and is tracked below, not folded into this
  entry.

- DIET-01 (Phase 2) stays Pending: 02-06's HomeHubView -> Settings -> DietPlanView route is wired and unit/integration-verified but the interactive spot-check (launch app, click through) was not run -- no touch-injection tool (idb/XCUITest) is available in this environment, only simctl. Next interactive UAT pass on Phase 2 should run this click-through and mark DIET-01 complete if it renders.

- New, separate, low-frequency flake found 2026-09-06 during plan 02-16's ten-consecutive-run
  verification (unrelated to the StepRegistry race just fixed above): a full-target run crashed
  once (1 of 17 total runs) at `PersistenceTests.makeContext()`, which creates an in-memory
  SwiftData `ModelContainer`. Three other suites also create in-memory `ModelContainer`s without a
  `.serialized` trait (`HealthDataStoreTests`, `EditAnswerFlowTests`, plus `PersistenceTests`
  itself), so concurrent `ModelContainer` instantiation across suites is the likely cause -- a
  known category of SwiftData-runtime flake, distinct in kind from the registry race. Out of
  scope for plan 02-16 per its own scope boundary (pre-existing, unrelated file, not caused by
  this plan's changes); not fixed. Needs its own pass if it recurs: likely fix is `.serialized` on
  the three affected suites, or a shared lock around `ModelContainer(for:configurations:)` in test
  helpers.

- 04.1-05 Task 4 (real Sign in with Apple round trip on a physical Apple ID) deferred to the batched end-of-project physical-device verification pass -- Docker unavailable in this environment and no touch-injection tool exists to drive the Apple ID sheet on Simulator. See 04.1-05-SUMMARY.md.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-09-10T14:37:51.139Z
Stopped at: Completed 04.1-09-PLAN.md
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
is a placeholder, deliberately not settled).

2026-09-06 (plan 02-16): The `StepRegistry` cross-suite race referenced above is now fixed --
see Blockers/Concerns for the mechanism. Plan 02-16's Task 1 (the fix, plus `Phase2CoverageTests`)
is complete and committed (`1b65149`). Tasks 2 and 3 are blocked on a single combined checkpoint:
no physical iPhone is attached to this Mac (only Simulator) and no touch-injection tool is
available to drive Simulator UI, so real GPS/motion-sensor verification, the on-device Go
round-trip render, and the AX3/AX5 accessibility pass (including the radial-timer item carried
from Phase 1, referenced above -- it is STILL open, now via plan 02-16 rather than 01-18) all
remain undischarged. The Go service's own contract (all three permission tiers, plus the
service-down transport-error path) was curl-verified locally as the automatable slice. Full
per-step breakdown of what's done vs. still needed is in
`.planning/phases/02-core-tracking-adjusted-guidance/02-16-SUMMARY.md`'s Checkpoint section.
Phase 2 cannot close until a human runs those steps on a physical device and at AX3/AX5, and
reports back.

2026-09-09: Phase 4 round 1 (CROSSGEN-01 dashboard) closed after 7 rounds of checkpoint feedback
(see `04-03-SUMMARY.md`'s Checkpoint Iteration History). User then asked to skip HOUSEHOLD-01 and
build group goal-events instead (`docs/group-events.md`). That feature was previously v2-scoped
specifically to keep Phase 5's pre-launch privacy review narrow; told this explicitly, the user
chose to pull it into v1 anyway. Inserted as Phase 4.1 (`/gsd-review-backlog`-style promotion,
`gsd-tools phase insert`) between Phase 4 and Phase 5; Phase 5's Depends-on updated to Phase 4.1
since its review must now cover the new photo/location data. Requirements HOUSEHOLD-02 and
GROUPEVENTS-01 through 05 (already fully drafted in `REQUIREMENTS.md`'s "Social & Groups" section
from a prior ingest of `docs/group-events.md`) converted from backlog to active. Not yet planned —
next step is `/gsd-plan-phase 4.1 --prd docs/group-events.md`.
Resume file:
None
