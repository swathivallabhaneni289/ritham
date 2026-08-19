# Context (DOC)

Extracted from DOC-classified docs: docs/weekly-timetable.md (medium confidence).

---

## Topic: Weekly timetable feature — framing

- **source:** docs/weekly-timetable.md §1
- **notes:** A "timetable" is a weekly-rhythm template (default, editable arrangement of movement/food-pattern by day) — not a rigid prescription, not a compliance checklist. Explicitly stated to add no new condition tags, gates, or adjustment logic beyond docs/health-screening.md — every row is either a direct restatement of health-screening.md §2/§3 arranged into a 7-day layout, or general population-level guideline content. Inherits health-screening.md's constraints without exception (no Under-18 calorie/macro/portion numbers regardless of other conditions present; required-blocking domains show the referral message, never a quantity/intensity).

## Topic: Under-18 weekly timetable

- **source:** docs/weekly-timetable.md §2
- **notes:** Baseline template targets HHS's 60+ min/day moderate-to-vigorous activity, vigorous/muscle-strengthening/bone-strengthening each on 3+ days/week (no official day-by-day HHS prescription — Ritham's Mon/Wed/Fri/Tue/Thu/Sat arrangement is explicitly flagged as Ritham's own illustrative default, not an official recommendation). Food side uses MyPlate half-plate structure with rotating vegetable subgroups; explicitly does not specify a numeric meal/snack count since no AAP/USDA primary source confirms one. Worked example given: Under-18 + Type 1 Diabetes (On Insulin) — combines health-screening.md's Diabetes workout/nutrition rows with the Under-18 numeric-figure ban, keeping only Plate Method *proportions* (not the ADA's optional ~45–60g carb/meal or <10% added-sugar numeric figures, which are withheld for this tier).

## Topic: 65+ weekly timetable

- **source:** docs/weekly-timetable.md §3
- **notes:** Baseline template targets HHS/NHS adult floor (150–300 min/week moderate or 75–150 min/week vigorous aerobic, resistance 2+ days/week) plus the 65+-specific multicomponent balance/functional-strength requirement from health-screening.md. Includes population-level reference bands (calorie range by activity level, sodium ≤2,300mg/day, protein-spread guidance, vitamin D/calcium/potassium reference intakes) sourced from NIA — explicitly shown as general education, never computed per user, matching the sourcing discipline of health-screening.md. Some gaps explicitly flagged as unconfirmed (no specific fiber gram target, no daily fluid-volume target — NIA doesn't publish an age-specific number for either). Worked example given: 65+ + Hypertension — Managed, combining the DASH-style/Valsalva-avoidance rules from health-screening.md with the baseline template.

## Topic: Design rules for the timetable feature (7 rules)

- **source:** docs/weekly-timetable.md §4
- **notes:**
  1. Required-blocking cells render the exact §4.6 referral message in place of any suggestion, scoped to that cell; manual logging/generic info still available in that slot.
  2. The timetable shell is always editable independent of any gate — being blocked from a personalized suggestion never means being blocked from rearranging the template.
  3. The timetable is a suggestion layer, fully decoupled from Momentum's counting logic — completing/skipping a slot never itself triggers streak gain/loss; only an actual qualifying session counts. **This rule's own restatement of the qualifying-session definition ("a GPS-tracked run/walk of 10+ minutes, or a lift with 3+ working sets across 2+ exercises") narrows docs/roadmap.md's actual definition, which also counts manually-entered/stopwatch-tracked sessions. See INGEST-CONFLICTS.md — resolved in favor of docs/roadmap.md (PRD outranks DOC) for synthesized intel purposes; the timetable doc's cell text should be corrected before implementation.** Rows already marked "should never break the streak" in health-screening.md's tables carry that same protection into the timetable rendering.
  4. Under-18 tier is school-schedule aware — user/parent marks school days vs. weekends/breaks; sessions can compress/shift to a lighter "micro-break" mode around exam periods without streak penalty (mirrors the Recovery-Week guardrail, doesn't invent a new mechanic).
  5. 65+ tier is routine-consistency aware — low-maintenance template set once, "same time each day" defaults, editing available but never prompted unless user-initiated.
  6. Multiple condition tags on the same cell merge adjustment content but never soften the gate — most-restrictive-wins rule from health-screening.md §5 still applies, never averaged/blended.
  7. No number appears in a timetable cell without a citation trail (HHS, WHO, NIA, PROT-AGE, ADA, or an existing Ritham rule row); unconfirmed figures are explicitly flagged as gaps rather than filled with a plausible default.

## Cross-doc consistency check

All of weekly-timetable.md's numeric claims and gate behavior were checked against docs/health-screening.md (SPEC, higher precedence) and docs/roadmap.md's Momentum mechanic (PRD). One narrowing inconsistency was found and auto-resolved in favor of the higher-precedence source (see Design Rule 3 above and INGEST-CONFLICTS.md). No other contradictions were found — this document is otherwise a derived/restated layout, not an independent source of new requirements or rules, consistent with its own DOC self-framing and the classifier's notes.
