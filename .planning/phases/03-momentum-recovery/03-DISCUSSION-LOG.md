# Phase 3: Momentum & Recovery - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-06
**Phase:** 03-momentum-recovery
**Areas discussed:** Architecture (client-side vs. Go backend), Self-report signal separation,
Recovery-aware suggestion integration, Visibility/Household scoping, Home surface integration

**Mode:** `--auto` (fully autonomous — user asked to move fast with minimal back-and-forth this
session, matching Phase 2's precedent). No AskUserQuestion prompts were shown; each area below
was resolved directly using the recommended/lowest-risk option, informed by
`docs/roadmap.md` §4's already-detailed mechanic spec and Phase 2's `02-CONTEXT.md` precedent.

---

## Architecture — client-side vs. Go backend

| Option | Description | Selected |
|--------|-------------|----------|
| Client-side only (RithamCore + HealthDataStore) | Momentum computed entirely on-device from existing session records; no new Go endpoint | ✓ |
| New Go endpoint for Momentum computation | Server-side streak calculation, mirroring the workout-plan-generation pattern | |

**Selected:** Client-side only.
**Notes:** Momentum only needs data already local to the device (cardio/lift session records).
Adding a Go round-trip would widen the GDPR/CCPA review surface for no benefit and contradicts
PROJECT.md's local-first storage decision. Phase 2's Go surface (workout-plan generation) stays
exactly as scoped.

---

## Self-report signal separation (sleep check-in / Recovery Week / injury freeze)

| Option | Description | Selected |
|--------|-------------|----------|
| Three independent state machines, no auto-transitions | Sleep check-in, Recovery Week flag, and injury freeze each stand alone; requirements' explicit no-auto-trigger invariants enforced structurally | ✓ |
| One shared "recovery state" model | Single enum/flag covering all three signals, branching on source | |

**Selected:** Three independent state machines.
**Notes:** RECOVERY-01 and MOMENTUM-03 each explicitly forbid one signal from auto-triggering
another (sleep check-in never auto-consumes a shield or auto-triggers Recovery Week; Recovery
Week is never auto-triggered by the app at all). A shared enum makes those invariants a matter of
discipline rather than structure — rejected for that reason.

---

## Recovery-aware suggestion (RECOVERY-01) integration

| Option | Description | Selected |
|--------|-------------|----------|
| Client-side post-processing over the existing Recommendations plan | No Go API change; sleep signal never crosses the network | ✓ |
| Add a 4th field (sleep quality) to the Go workout-plan request | Server adjusts the generated plan directly | |

**Selected:** Client-side post-processing.
**Notes:** Keeps Phase 2's D-07 three-field data-minimization boundary untouched, keeps sleep
data off the network entirely, and — critically — keeps RECOVERY-01 fully unit-testable rather
than pushing verification into the physical-device/cross-process bucket already deferred to the
end-of-project batch pass.

---

## Visibility & Household (MOMENTUM-06)

| Option | Description | Selected |
|--------|-------------|----------|
| Private-only in Phase 3; scoped, dated deferral of the household-sharing half to Phase 4 | Ship the private-by-default guarantee now; record explicitly that opt-in sharing needs Household to exist first | ✓ |
| Build a placeholder/stub household-sharing toggle now | UI exists but is non-functional until Phase 4 | |

**Selected:** Private-only, with a dated ROADMAP.md annotation (to be added during execution),
mirroring Phase 2 criterion 6's own 2026-09-04 correction precedent.
**Notes:** Household (HOUSEHOLD-01) doesn't exist until Phase 4 — there's nothing to opt into
yet. A placeholder toggle would be dead UI. The data model still reserves a visibility-scope
property so Phase 4 can extend it without a migration (see CONTEXT.md D-07).

---

## Home surface integration

| Option | Description | Selected |
|--------|-------------|----------|
| Add Momentum summary to Phase 2's existing interim HomeHubView, with a standalone `MomentumSummary` accessor | Reachable now; shaped for Phase 4's CROSSGEN-01 home to reuse later | ✓ |
| Build Momentum's own separate top-level surface, ignore HomeHubView | New nav entry point, not reusing the interim hub | |

**Selected:** Add to interim HomeHubView with a standalone, reusable accessor.
**Notes:** Continues Phase 2's D-05 interim-hub pattern. Phase 4's polished home screen needs
"today's target + current streak" as 2 of its exactly-3 default items — building the accessor
as a standalone queryable unit now avoids rework later.

---

## Claude's Discretion

- Weekly-target adjustability (2-5, default 3): Settings preference, same pattern as Phase 2's
  workout-frequency setting.
- Comeback Session UI: plain CTA, no wizard.
- Milestone badges: simple badge case/list UI, no bespoke celebration animation — framing
  constraint governs copy, not visual complexity.
- Monday 3am week-boundary math and full SwiftData schema: left to research/planning.

## Deferred Ideas

None new. MOMENTUM-06's household-sharing half is an existing v1 requirement with a structural
forward dependency on Phase 4, not a new deferred idea — see CONTEXT.md D-06.
