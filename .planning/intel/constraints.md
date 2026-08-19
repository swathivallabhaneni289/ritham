# Constraints (SPECs)

Extracted from SPEC-classified docs: docs/health-screening.md, docs/dietary-pattern.md, docs/group-events.md (all medium confidence).

---

## From docs/health-screening.md

### CONSTRAINT-health-intake-flow
- **source:** docs/health-screening.md §1
- **type:** protocol / schema
- **content:** Fixed-choice screening questionnaire (never free text, never live AI-generated advice). Flow: Q0 (age, sets `Under 18 (Minor)` or `65+ / Deconditioned` tags) → Gate section G1–G7 (PAR-Q-style; any "Yes" triggers a clearance interstitial, urgent variant if G2/G3=Yes) → Condition checklist §1.3 (9 categories: Cardiovascular, Metabolic, Musculoskeletal/Joint, Pregnancy/Postpartum, Kidney/Renal, Eating Disorder History, Food Allergies, Other Serious Condition, or "None of the above") → severity/context follow-ups per selected category (§1.4, including the SCOFF eating-disorder screen ED-1–ED-5) → Universal follow-up U-1 (65+/deconditioned/returning-after-inactivity tag). Age-derived 65+ tag (Q0) can only be added to by U-1, never cleared by it.
- **flow mechanics (§1.6):** condition tags and "cleared by professional" toggle valid up to 12 months or until user edits an answer; re-screen prompted at 12-month mark; the "I've talked to a professional" toggle re-prompts rather than persisting forever.

### CONSTRAINT-condition-tag-data-model
- **source:** docs/health-screening.md §1.3–§1.4, §2, §3
- **type:** schema
- **content:** Condition tags (data model, non-exhaustive list): `Under 18 (Minor)`, `65+ / Deconditioned / Returning After Inactivity`, `Hypertension — Managed`, `Hypertension — Uncontrolled/Unsure`, `Heart Disease — Stable`, `Heart Disease — Recent Event/Symptomatic`, `Arrhythmia — Stable/Rate-Controlled`, `Arrhythmia — Uncontrolled/Unsure`, `Rate-Limiting Heart/BP Medication` (modifier), `Diabetes — On Insulin/Hypoglycemia-Risk Med`, `Diabetes — Not on such medication`, `Prediabetes`, `Diabetes — Retinopathy/Foot Complication Flagged` (modifier), `Osteoarthritis`, `Osteoporosis/Osteopenia`, `Chronic Low Back Pain`, `Prior Injury/Surgery — Not Yet Cleared`, `Prior Injury/Surgery — Cleared`, `Musculoskeletal Flare` (modifier), `Pregnancy — Uncomplicated`, `Pregnancy — Complicated/Unsure`, `Postpartum — Uncomplicated`, `Postpartum — C-Section/Complications`, `Kidney Disease/Dialysis`, `Eating Disorder History — Positive Screen/Active Symptoms`, `Eating Disorder History — Self-Reported Only/Negative Screen`, `Severe Food Allergy`, `Non-Severe Food Allergy`, `Other Serious Condition/Active Cancer Treatment`, `Existing Clinician-Prescribed Diet or Meal Plan` (modifier), `None of the Above/Baseline`.

### CONSTRAINT-workout-adjustment-rule-table
- **source:** docs/health-screening.md §2 (full table, ~25 rows)
- **type:** nfr / protocol
- **content:** Per-condition-tag workout adjustment + contraindication + Clearance Gate (`none` | `recommended` | `required-blocking`). Full table in source. Key structural rules: `required-blocking` = no personalized intensity/modality suggestion, only generic info + referral. Several rows explicitly state rest/held days "should never break the user's streak or trigger streak-loss messaging" (Heart Disease — Recent Event, Prior Injury Not Yet Cleared, Pregnancy — Complicated/Unsure, Postpartum — C-Section/Complications, Eating Disorder History — Positive Screen) — this is a direct cross-constraint with the Momentum streak system (see requirements.md REQ-momentum-streak-system) and is restated by weekly-timetable.md Design Rule 3.

### CONSTRAINT-nutrition-adjustment-rule-table
- **source:** docs/health-screening.md §3 (full table, ~25 rows)
- **type:** nfr / protocol
- **content:** Per-condition-tag nutrition guidance + prohibited actions + Clearance Gate. `required-blocking` = zero personalized quantity of any kind (no calorie/macro/portion/weight-loss number), generic education only or nothing. All numeric reference figures shown (2,300mg/1,500mg sodium, <10%/<6% saturated fat, <10% added sugar, ADA ~45–60g carb/meal, CDC 5–7% body-weight) are published population-level reference figures, never individually calculated. Under 18 (Minor): required-blocking specifically for any weight-management/calorie/macro/portion feature or weight-loss goal-setting, independent of any other condition — this rule is later re-invoked verbatim by dietary-pattern.md's non-gating rule and by weekly-timetable.md §1.

### CONSTRAINT-disclaimer-legal-framing
- **source:** docs/health-screening.md §4
- **type:** nfr
- **content:** Standard copy blocks: opening disclaimer, routine clearance interstitial, urgent clearance interstitial (G2/G3), persistent compact tag ("Adjusted for [Condition] · General guidance, not medical advice · Edit in Settings"), expanded disclaimer, required-blocking message, standing footer disclaimer. These exact strings are reused verbatim by weekly-timetable.md and referenced by dietary-pattern.md and cycle-recovery.md's own disclaimers.
- **legal flags (unresolved, pre-launch):** PAR-Q+ gate-question wording needs counsel review before referencing "PAR-Q+" by name in-product; SCOFF wording/scoring needs clinician confirmation before shipping.

### CONSTRAINT-red-flag-escalation-logic
- **source:** docs/health-screening.md §5
- **type:** protocol
- **content:** Governing principles: any "Not sure" resolves to the more cautious branch; when 2+ red-flag tags apply, the single most restrictive gate wins across all applicable tags (never averaged/blended/softened); required-blocking gates block personalization in a domain only, never app access as a whole (manual logging/generic info always available). 16 specific trigger combinations enumerated (G2/G3 emergency, recent cardiac event, uncontrolled hypertension, uncontrolled arrhythmia, insulin + hypoglycemia risk, diabetes eye/foot complications, pregnancy nutrition block, complicated pregnancy, postpartum C-section, any kidney/renal box, SCOFF≥2, MSK not-yet-cleared, any other-serious-condition box, under-18 + weight-loss goal anywhere in app, goal weight below healthy-BMI floor with no ED history reported, severe food allergy verify-flag). Standing product-wide prohibition: Ritham never generates insulin-dosing or medication-adjustment suggestions for any user, under any tag/combination, no exception via clearance toggle.

---

## From docs/dietary-pattern.md

### CONSTRAINT-dietary-pattern-field
- **source:** docs/dietary-pattern.md §1
- **type:** schema
- **content:** New field `dietary_pattern: none | vegetarian | vegan`, single-select, asked as Q0b directly after Q0 (age) in health-screening.md §1.1 "About You" — same section, unconditional, before the Gate section and Condition Checklist. Never a checkbox inside §1.3, never triggers a severity follow-up, not touched by the "None of the above clears other selections" behavior. Editable anytime in Settings, no expiry/re-screen logic.

### CONSTRAINT-dietary-pattern-non-gating-rule
- **source:** docs/dietary-pattern.md §2
- **type:** protocol
- **content:** `dietary_pattern` never changes a Clearance Gate value, never triggers `required-blocking`, never blocks/unlocks/softens a condition-specific suggestion; has no row in either Adjustment Rule Table and no entry in Red-Flag Escalation Logic. Only effect: after the Nutrition Adjustment Rule Table (health-screening.md §3) resolves its gate independently, and only if that gate resolved to `none` or `recommended`, a second independent lookup keyed on `dietary_pattern` decides which example foods populate the already-permitted slot. Worked example given: Vegan + Kidney Disease/Dialysis → gate stays `required-blocking`, unchanged, zero food content shown of any kind, vegan-flavored or otherwise.
- **cross-check:** verified consistent with CONSTRAINT-nutrition-adjustment-rule-table — no contradiction; this doc is explicitly additive/downstream.

### CONSTRAINT-protein-swap-table
- **source:** docs/dietary-pattern.md §3
- **type:** schema
- **content:** Maps 4 existing Nutrition Table rows (Baseline, Diabetes Plate Method, Hypertension DASH-style, Heart Disease AHA pattern) to standard/vegetarian/vegan example-food swaps. Applies only where the parent gate already resolved to `none` or `recommended`. Several swap entries flagged as "Ritham's own construction" / inference, not directly published by ADA or NHLBI (flagged with footnotes ⚑¹ ⚑² ⚑³) — engineers should treat these as needing dietitian sign-off before shipping, per the doc's own sourcing-discipline note.

### CONSTRAINT-nutrient-education-blocks
- **source:** docs/dietary-pattern.md §4
- **type:** nfr
- **content:** Vegan and vegetarian nutrient-awareness education blocks (B12, iron, zinc, omega-3, calcium, vitamin D, iodine for vegan; B12/iron/zinc/omega-3 for vegetarian) shown once, general education, identical regardless of any condition tag also present.

---

## From docs/group-events.md

### CONSTRAINT-friends-groups-data-model
- **source:** docs/group-events.md §1
- **type:** schema / protocol
- **content:** Friending is mutual/request-based (never one-directional follow); three closed-loop connection paths: contact matching (off by default, both-sides opt-in), invite link/QR (expiring after set window or first use), in-person/direct share (no in-app directory). Groups are small, closed, invite-only (invites sent only to existing friends); no public/joinable-by-anyone tier; no admin-approval queue since nobody outside the friend graph can request to join. Any member can leave anytime, no ownership-transfer gate; if the organizer leaves, the group simply continues (any remaining member can create the next goal-event).
- **visibility ladder:** Only Me → Household → this specific group. No "Friends of friends" rung, no "Public/Everyone" rung, for any surface (profile, group, completion post, certificate). Anything beyond the group boundary requires a deliberate individual export (§5).

### CONSTRAINT-goal-event-data-model
- **source:** docs/group-events.md §2
- **type:** schema / protocol
- **content:** A Goal-Event = shared, non-timed commitment. Organizer sets activity type, optional target (distance/duration), target date/window. No synchronized start, no clock. Each person logs their own completion independently; own time is optional, off by default, asked (not assumed) at logging, skippable with zero friction. Personal distance/pace/route stay in the user's private log only, never travels to group feed/certificate/export by construction. No ranking mechanism of any kind (no pooled total, no contribution ranking, no leaderboard sort, no score, no winner). Feed ordered chronologically by post time, never by completion speed. Non-completion is a non-event: completion feed shows positive completions only, no denominator paired with completion count, no expiry notice, event closes silently at window end.

### CONSTRAINT-photo-location-privacy
- **source:** docs/group-events.md §3
- **type:** protocol / nfr
- **content:** EXIF GPS/metadata stripped server-side, unconditionally, before any group-visible or exportable write (never relies on client-side stripping alone). Original file with metadata retained only in the user's private library. Location sharing is a separate, explicit opt-in from photo sharing (never bundled). Ritham does not capture precise coordinates for a completion log at all unless the user separately opts into a personal private route view; that data never reaches group feed/certificate/aggregate/export. Default location display (if opted in) is a reverse-geocoded coarse named place — never coordinates, never a pin, never an address, never a numeric radius/distance figure (to prevent triangulation). Privacy Zone: user-set sensitive locations (home, workplace) are automatically generalized/suppressed across every shared surface without requiring a per-post toggle. Headline commitment: Ritham will never build a cross-user aggregate location visualization (no heatmap, no "most active area" feature), ever.

### CONSTRAINT-shared-feed
- **source:** docs/group-events.md §4
- **type:** schema
- **content:** Feed visible to the group only, by default and permanently — not public, not discoverable, not indexed, no generic shareable link. Leaving/removal removes future feed access but past completion cards remain visible to the group (leave flow offers option to remove own past posts). Per-completion fields: name/avatar, Goal-Event name + activity type, completion date, optional EXIF-stripped photo, optional generalized location, optional caption, fixed non-comparative cheers. Never shows: pace, time-based rank, "first to complete," a completion denominator, or precise location.

### CONSTRAINT-digital-certificate
- **source:** docs/group-events.md §5
- **type:** schema / protocol
- **content:** Auto-generated per person on completion: Ritham branding, event name/activity type, participant's own name, completion date, own time only if opted in. Never includes: pace, measured distance, rank, GPS/address, any other member's name/photo/status/time, or "X of Y completed." Default export template is a branded graphic/badge, not the user's own photo (structurally avoids "whose photo is this" leaks). External export contains only the exporting user's own data — no member count/roster, no group name if person-identifying, no other member's data. Event name is free text and can itself be a location/identity disclosure — mitigated by (a) a creation-time nudge to the organizer, and (b) an editable display-name field at export time that lets the exporter rename their own certificate copy without altering what the group sees. Export path goes through the same EXIF-stripping guarantee as any other shared image.
