# Phase 1: Onboarding & Safety Intake - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-23
**Phase:** 01-onboarding-safety-intake
**Areas discussed:** Calibration session mechanics, Parental consent verification, Condition-tag re-screen experience, SCOFF trigger & restriction transparency

---

## Calibration session mechanics

| Question | Options considered | Selected |
|---|---|---|
| Minimum to count as complete? | Time-based minimum / User just marks it done / Distance-rep target | Time-based minimum ✓ |
| How is it measured? | GPS if available, manual fallback / Manual stopwatch only | GPS if available, manual fallback ✓ |
| Can it be skipped? | No — required / Yes — skippable, prompted later | Skippable ✓ |
| What happens while skipped? | Generic starting point in the meantime / No personalized suggestions until completed | Generic starting point ✓ |
| What does completion set? | Pace zone / starting weight / Something else | Pace zone / starting weight ✓ |

**User's choices:** At least 10 continuous minutes for the walk. GPS with manual stopwatch fallback. Skippable via "skip for now." Generic starting point given while skipped. Confirmed pace-zone/starting-weight baseline framing.
**Notes:** The 4-question batch (AskUserQuestion) was rejected as too dense/technical on first attempt — the user said "i didnt understand the question." Re-asked one plain-language question at a time in prose instead; all five sub-questions were answered this way.

---

## Parental consent verification

| Question | Options considered | Selected |
|---|---|---|
| How does the parent confirm? | Email verification link / Something else | Email link ✓ |
| What can the under-13 user do while waiting? | Fully locked until confirmed / Limited preview access | Fully locked ✓ |

**User's choices:** Email link (parent enters email, gets a link, clicks to confirm). Fully locked, no partial access, while awaiting confirmation.
**Notes:** Distinguished from the 13–17 flow, which already allows calibration/tracking before parental approval per `docs/health-screening.md` §1.1 — that existing distinction was preserved, not changed.

---

## Condition-tag re-screen experience

| Question | Options considered | Selected |
|---|---|---|
| Blocking or non-blocking at 12-month expiry? | Blocking until re-screened / Non-blocking reminder | Non-blocking ✓ |
| Guidance while overdue? | Keep old restrictions / Fall back to generic guidance | Keep old restrictions ✓ |
| Does editing one answer re-open the whole questionnaire? | Re-open entire questionnaire / Re-check just that section | Re-check just that section ✓ |

**User's choices:** Non-blocking reminder banner; old restrictions persist (safer default) until re-screened; editing one answer only re-checks that section.
**Notes:** None beyond the direct answers.

---

## SCOFF trigger & restriction transparency

| Question | Options considered | Selected |
|---|---|---|
| What triggers SCOFF? | (Pre-answered by `docs/health-screening.md` §1.3/§1.4 — not asked) | Only the "Eating Disorder History" checkbox |
| Does the user see why a restriction applies? | (Pre-answered by `01-UI-SPEC.md`'s persistent disclaimer tag — not asked) | Yes, already locked |
| When 2+ conditions apply but only one gate binds, show one or all? | Show only the binding condition / Show all matched conditions | All matched conditions ✓ |

**User's choices:** All matched conditions listed in the disclaimer tag, not just the single binding one.
**Notes:** Two of the three planned questions in this area turned out to already be answered by existing docs (`docs/health-screening.md` and `01-UI-SPEC.md`) — surfaced to the user rather than re-asked as if undecided.

---

## Claude's Discretion

- Resend/edit-email UX for a mistyped parent email or expired confirmation link (standard pattern, not discussed in depth).
- The light-lift calibration threshold ("2+ sets across 1+ exercise") is inferred from Momentum's qualifying-session bar (MOMENTUM-01), not independently confirmed with the user — flagged for the planner to verify against MOMENTUM-01's exact wording.

## Deferred Ideas

None — discussion stayed within phase scope. Whether Momo (the mascot) ships at all remains an open, separately-tracked decision (see CONTEXT.md `<specifics>`), not a scope-creep deferral to a future phase.
