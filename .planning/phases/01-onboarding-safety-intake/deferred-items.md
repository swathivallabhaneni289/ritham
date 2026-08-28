# Deferred Items — Phase 01

Out-of-scope discoveries found during plan execution, logged rather than fixed per the executor's
scope-boundary rule (only auto-fix issues directly caused by the current task's own changes).

## From 01-10 (design system tokens)

- **`RithamApp/Ritham/App/StepRegistry.swift`'s `UnimplementedStepView` uses `.font(.caption)`**
  — below the type-scale floor `RithamType` now establishes (nothing renders below the `label`
  role / 16pt). This is 01-09's temporary placeholder shown only for an `OnboardingStep` with no
  registered screen yet; it is not user-facing production copy and 01-18's `PhaseCoverageTests`
  is expected to assert `unregisteredSteps` is empty once every screen plan lands, at which point
  this view stops rendering in practice. Out of scope for 01-10 (file not in its
  `files_modified`) — flagging so a later plan (01-18, or whichever plan is the file's next
  owner) either removes the placeholder's caption text or migrates it to `RithamType.label`
  before ship.

## From 01-17 (disclaimer surfaces, health profile, Settings/re-screen)

- **`.screeningComplete` and `.home` will still be unregistered when 01-18 runs.**
  01-16-SUMMARY.md's "Next Phase Readiness" states `.screeningComplete` is "owned by plan 01-17,"
  but 01-17-PLAN.md's own task list never tasks a screen or registration for either step, and
  01-18-PLAN.md's Task 1 only calls `AboutYouRegistration.registerAll()`,
  `CalibrationRegistration.registerAll()`, and `ScreeningRegistration.registerAll()` — none of
  which cover `.screeningComplete`/`.home`. 01-18's `PhaseCoverageTests` asserts
  `StepRegistry.unregisteredSteps` is empty, which will trip on these two steps as currently
  scoped. Flagging for 01-18 to resolve (likely a small additional screen/registrar, a Rule 3
  fix since it blocks that plan's own acceptance gate) rather than expanding 01-17's scope to
  build app-shell navigation that isn't otherwise this plan's job.

- **`HealthProfileView`'s store-derived `GateResolutionResult` cannot reconstruct §5 Rule 1**
  (G2 = chest pain/breathlessness at rest, or G3 = dizziness/loss of consciousness, both "Yes"
  forcing both domains to `.requiredBlocking`) after the onboarding session ends, because G2/G3
  are answer-driven, not tag-driven — no `ConditionTag` records this, and raw `ScreeningAnswers`
  is never durably persisted (01-11's deliberate derived-tags-only storage decision). A user who
  answered G2/G3 = Yes and then reopens the health profile in a later app session could see a
  laxer gate on that screen than the one their original screening actually produced. Every other
  §5 rule (2 through 13) is purely tag-driven and reconstructs correctly from
  `HealthDataStore.conditionTagStatuses(now:)`. Fixing this durably means persisting the G2/G3
  answer (or an equivalent standing flag) somewhere — out of this plan's scope (touches the
  persistence schema plan 01-11 owns) and not something Rule 2 covers on its own; flagging for
  whichever future plan next touches `HealthDataStore`/`UserProfile`.

- **`GateResolutionResult.gates` (the actual per-domain `ClearanceGate` values) is never
  persisted anywhere.** `HealthDataStore.saveScreeningResult` only ever writes `matchedTags` (as
  `ConditionTagRecord`s) and the derived eating-disorder outcome — the resolved `DomainGates`
  themselves have no durable home. `HealthProfileView` works around this by re-deriving gates at
  read time via `GateEscalation.escalate(tags:answers:)` over the persisted tags (see the Rule 1
  gap above for the one place that re-derivation is lossy). Phase 2's HEALTH-03/HEALTH-04
  suggestion surfaces will need a real, durable answer to "what is this user's current workout/
  nutrition gate" — flagging so that phase doesn't rediscover this gap independently.

- **`EditAnswerFlow` requires a same-session, populated `OnboardingFlow`.** Presenting it against
  a fresh/empty `OnboardingFlow` (e.g. a brand-new app launch with nothing carried forward in
  memory) re-resolves over blank answers for every section but the one being edited, silently
  wiping every other section's condition tags — the exact under-restriction failure class
  T-01-103/T-01-104 exist to prevent. Documented in `EditAnswerFlow.swift`'s own header comment
  and pinned by two tests in `EditAnswerFlowTests.swift` (one showing the correct populated-flow
  behavior, one showing the documented gap). Not fixable within this plan's scope without
  reversing 01-11's deliberate "derived tags only, no raw `ScreeningAnswers`" storage decision —
  that reversal is a Rule 4 (architectural) call for a future plan, not a Rule 2 fix here.
  Whichever plan wires Settings into real cross-launch app navigation must resolve this first,
  either by persisting raw `ScreeningAnswers` or by hydrating a fresh flow's answers from a
  durable source before presenting `EditAnswerFlow`.
