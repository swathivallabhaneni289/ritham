---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 01
current_phase_name: onboarding-safety-intake
status: executing
stopped_at: context exhaustion at 100% (2026-08-28)
last_updated: "2026-08-28T12:26:21.071Z"
last_activity: 2026-08-25
last_activity_desc: Phase 01 execution started
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 14
  completed_plans: 13
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-19)

**Core value:** Every user 13 or older, any health background — can safely track real training and
keep a fair, forgiving consistency streak, with core tracking always free and never subject to
comparison or ranking.
**Current focus:** Phase 01 — onboarding-safety-intake

## Current Position

Phase: 01 (onboarding-safety-intake) — EXECUTING
Plan: 14 of 14
Status: Ready to execute
Last activity: 2026-08-25 — Phase 01 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: N/A
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

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

### Pending Todos

- GitHub issue #1's device-continuity question is still open: whether/how a user's training data
  should survive a device change (its parental-consent-continuity motivation is now moot, but the
  general question for all users was never resolved — see the Option A/B/C discussion in the
  2026-08-23/24 session). Not yet decided or built.

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

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-09-01 (live design review + calibration moved out of onboarding)
Stopped at: Phase 1 functionally complete (13/14 plans, all passing individually). Calibration
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
