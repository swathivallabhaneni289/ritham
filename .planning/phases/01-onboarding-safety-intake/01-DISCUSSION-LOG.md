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

---

**Date:** 2026-08-23 (later same day)
**Phase:** 01-onboarding-safety-intake
**Areas discussed:** Reversal of the tiered parental-consent design — permanent 13+ age floor

---

## Age floor reversal — permanent 13+ instead of tiered parental consent

| Question | Options considered | Selected |
|---|---|---|
| Should Ritham keep the tiered consent design (under-13 fully locked pending verifiable parental consent; 13-17 partially gated behind parent approval for sensitive screening) discussed earlier the same day? | Keep tiered consent as designed / Replace with a permanent 13+ age floor and drop under-13 entirely | Permanent 13+ age floor ✓ |
| Should SCOFF and the rest of sensitive screening be narrowed to 18+ once the under-13 tier is gone? | Narrow to 18+ (matching MyFitnessPal's own floor) / Keep full screening identical for every 13+ user | Full screening for every 13+ user, identical ✓ |

**User's choices:** Ritham has no under-13 tier of any kind, permanently — not reduced-functionality, not gated. Age under 13 shows a plain blocking message; the user can back out and re-enter a different age, with nothing saved for the rejected attempt. A confirmed user who later edits their age down below 13 (e.g. in Settings) has that edit rejected, keeping the previous age. A 13-17-year-old gets full, identical access to an 18+ user from the moment they enter their age — calibration, tracking, Momentum, dietary pattern, and the complete safety screening (gate section, condition checklist, and SCOFF) all run identically, with zero parental involvement at any point. SCOFF stays included for teens rather than being restricted to 18+, because the screening is protective (a positive screen pauses risky features and shows a supportive referral, never a diagnosis) — excluding teens from it would leave them with less-safe guidance, not more, and teens are exactly the population MyFitnessPal's own 18+ floor was worried about.

**Notes:** This reverses the tiered-consent design captured earlier the same day in this log's "Parental consent verification" section above (kept there, not deleted, as historical record — see D-05/D-06/D-13 in `01-CONTEXT.md`, now marked SUPERSEDED). The reversal traces back to GitHub issue #1, which asked for real accounts so parental-consent state could survive a device change. Tracing that request back through a cost/benefit reassessment showed the tiered-consent design it depended on cost far more — a full Go consent-service backend (crypto tokens, a four-state consent machine, an HTTP API, a delayed second confirmation email for COPPA "email plus"), Universal Links, and an Apple association file, plus a COPPA legal review (LAUNCH-05) — than the problem was worth. Competitor research across Strava, Nike, Peloton, and MyFitnessPal found that none of them build real under-13 support of any kind; they all set a hard age floor instead. Dropping the tier removes the problem GitHub issue #1 was trying to solve, not just the sign-up mechanism it asked for. Full decision record: `01-CONTEXT.md` D-14 (the reversal itself) and D-15 (why SCOFF stays included for teens); D-05/D-06/D-13 remain in that file marked SUPERSEDED for history. Requirements/roadmap updated accordingly: MINOR-01 rewritten to the permanent-floor wording, MINOR-02 removed (nothing left to require once there's no consent step), LAUNCH-05 removed (no under-13 support means no COPPA review is needed).
