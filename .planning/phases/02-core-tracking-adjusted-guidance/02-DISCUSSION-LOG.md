# Phase 2: Core Tracking & Adjusted Guidance - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-04
**Phase:** 02-core-tracking-adjusted-guidance
**Areas discussed:** ONBOARD-01 trigger scope, Home navigation, Backend architecture (Go),
Workout frequency & experience scaling (Claude's Discretion), Condition-adjusted guidance
surfacing (Claude's Discretion), Passive-first capture (Claude's Discretion)

---

## ONBOARD-01 trigger scope

**Q1: Does the ONBOARD-01 triggered pre-assessment get built in Phase 2, or pushed to its own phase?**

| Option | Description | Selected |
|--------|-------------|----------|
| Build it in Phase 2 (Recommended) | Keeps "recommendations" meaningful from day one; HEALTH-03/04 and the trigger are the same feature surface | ✓ |
| Defer to its own future phase | Phase 2 ships tracking + guidance only; trigger + recommendation engine become a dedicated later phase | |

**User's choice:** Build it in Phase 2.

**Q2: Should real CARDIO/STRENGTH tracking reuse/extend `CalibrationSession`, or be a separate domain?**

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse/extend CalibrationSession (Recommended) | One session-tracking domain; completed calibration naturally becomes real logged history | |
| Separate WorkoutSession domain | Calibration stays narrow/isolated; real tracking gets its own domain referencing only the shared threshold constants | ✓ |

**User's choice:** Separate `WorkoutSession` domain.

**Q3: What's the concrete entry point for "requesting exercise recommendations"?**

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated "Recommendations" surface (Recommended) | New tab/screen/CTA the user explicitly opens | ✓ |
| Auto-surfaced within condition-adjusted guidance | Trigger fires implicitly the first time HEALTH-03 guidance would show | |

**User's choice:** Dedicated "Recommendations" surface.

**Q4: Does completing the triggered pre-assessment count as a real logged session?**

| Option | Description | Selected |
|--------|-------------|----------|
| Counts as a real logged session (Recommended) | Feeds Phase 3's Momentum once it ships; matches "endowed progress" design | |
| Baseline-only, never in training history | Keeps calibration conceptually separate from "real training," matches D-04 | ✓ |

**User's choice:** Baseline-only, never in training history.

**Notes:** None beyond the selections above.

---

## Home navigation

**Q: Should Phase 2 build a lightweight interim navigation hub?**

This question was folded into a broader conversation rather than answered via AskUserQuestion —
the user raised the underlying concern unprompted ("I think we should build the home where all
these features are, and they can select which one they go to") before I had asked about it
formally. Treated as a direct answer: yes, build the interim hub. See CONTEXT.md D-05.

**User's choice:** Yes — build a lightweight interim hub in Phase 2 (not Phase 4's polished
CROSSGEN-01 design, just enough real navigation to reach and test Phase 2's features).

---

## Backend architecture (Go)

This was not one of the four originally-selected gray areas — it emerged mid-discussion when the
user redirected the conversation to ask about switching the project off Swift, and after
clarification, to specifically add Go. The exchange (paraphrased):

1. User initially asked whether Go/Python could be used "for future tasks," framed around a
   voice-garbled reference to "gold lying" (Go), then a follow-up naming Python directly.
2. When the frequency question (below) was interrupted, the user asked more directly about
   switching off Swift, revealing the real motivation: applying for jobs and worried Swift isn't
   "noticeable" enough on a resume compared to Python or Go.
3. Claude clarified the hard constraint (Go/Python cannot build native iOS UI — no SwiftUI
   equivalent) and asked whether this meant a backend addition or something else, and separately
   surfaced the home-navigation gap (Phase 2 vs. Phase 4).
4. User clarified they're targeting **general software-engineering roles**, not iOS-specific —
   Claude recommended keeping Ritham Swift-only and building a separate standalone Python/Go
   portfolio project instead, to avoid scope creep and avoid conflicting with Ritham's
   local-first-storage design.
5. User overrode that recommendation: **"i definetly started with i want to build this project
   using golang. if necessary change things."**
6. Claude laid out what a Go backend concretely requires (new service, hosting, a decision on
   whether to port existing Swift domain logic, and a wider GDPR/CCPA review surface since health
   data would be leaving the device) and asked whether Go should take over only new Phase 2+
   logic, or also existing Phase 1 Swift logic.
7. User closed the loop: **"just build it make it fast i dont want to spend too much time on this
   project."** Claude took this as confirming the lower-risk, faster option — new logic only,
   Phase 1 untouched — rather than opening another round of questions.

**Decision:** New Phase 2+ server-side logic (workout-plan generation first) runs behind a Go
backend API. Phase 1's existing Swift domain logic is not ported or touched. See `CONTEXT.md`
D-06/D-07 and `PROJECT.md` Key Decisions for the full rationale and its origin in the user's job
search (general SWE roles), not a product requirement of Ritham itself.

---

## Claude's Discretion

The user's closing instruction — "just build it, make it fast, i dont want to spend too much time
on this project" — was taken as authorization to resolve the three remaining originally-selected
gray areas (Workout frequency & experience scaling, Condition-adjusted guidance surfacing,
Passive-first capture) without further interactive questions, rather than continuing the
per-area AskUserQuestion loop. See `CONTEXT.md`'s "Claude's Discretion" subsection for the
specific defaults chosen and their rationale (each traces to an existing Phase 1 pattern or
decision, to keep scope lean and consistent rather than inventing new approaches). All are
flagged as overridable during planning.

## Deferred Ideas

None new. The Momo mascot go/no-go decision remains open from Phase 1 — not re-litigated here.
