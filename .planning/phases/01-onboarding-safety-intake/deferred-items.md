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
