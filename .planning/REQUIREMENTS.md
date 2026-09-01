# Requirements: Ritham

**Defined:** 2026-08-19
**Core Value:** Every user 13 or older, any health background — can safely track real training and
keep a fair, forgiving consistency streak, with core tracking always free and never subject to
comparison or ranking.

## v1 Requirements

Requirements for initial release. Each maps to exactly one roadmap phase.

### Onboarding

- [ ] **ONBOARD-01**: The first time a user requests exercise recommendations, they complete a
  short, guided walk-or-light-lift pre-assessment (never a self-reported fitness-level dropdown)
  that sets their actual starting baseline, factoring in age and applicable condition tags from
  the safety screening. Revised 2026-09-01: no longer onboarding's first mandatory session (see
  `PROJECT.md` Key Decisions) — the "never a dropdown" half is unchanged, only "first session"
  is reversed. Calibration domain/UI already built in Phase 1 and kept intact for reuse; the
  triggered entry point itself is not yet built.

### Explanation Layer

- [x] **EXPLAIN-01**: Ritham speaks to every user in one consistent voice, with no user-chosen
  explanation register anywhere in the product (no onboarding question, no Settings toggle);
  every technical term elsewhere (1RM, HRV, grade-adjusted pace, etc.) is tap-to-expand into a
  single, well-written definition. There is no dual-register system to infer from age, and no
  separate "senior mode."

### Health Screening

- [x] **HEALTH-01**: User completes a fixed-choice screening questionnaire (never free text,
  never live AI-generated advice): Q0 (age, sets Under-18/65+ tags) → gate section G1–G7
  (PAR-Q-style; any "Yes" triggers a clearance interstitial, urgent variant if G2/G3) → condition
  checklist (9 categories, incl. "None of the above") → severity/context follow-ups per selected
  category (including the SCOFF eating-disorder screen ED-1–ED-5) → universal follow-up
  (65+/deconditioned/returning-after-inactivity tag).

- [x] **HEALTH-02**: Condition tags and the "cleared by professional" toggle persist and stay
  valid up to 12 months or until the user edits an answer; a re-screen is prompted at the
  12-month mark; the professional-clearance toggle re-prompts rather than persisting forever.

- [ ] **HEALTH-03**: Workout guidance adjusts per applicable condition tag the moment a user logs
  or plans a session. A `required-blocking` gate shows only generic info + referral, never a
  personalized intensity/modality suggestion. Rows marked "should never break the streak" (Heart
  Disease — Recent Event, Prior Injury Not Yet Cleared, Pregnancy — Complicated/Unsure,
  Postpartum — C-Section/Complications, Eating Disorder History — Positive Screen) never trigger
  streak-loss messaging.

- [ ] **HEALTH-04**: Nutrition guidance adjusts per applicable condition tag. A
  `required-blocking` gate shows zero personalized quantity of any kind (no calorie/macro/portion/
  weight-loss number) — generic education only, or nothing. All numeric reference figures shown
  are published population-level figures, never individually calculated. Under 18 (Minor) is
  `required-blocking` for any weight-management/calorie/macro/portion feature or weight-loss
  goal-setting, independent of any other condition.

- [x] **HEALTH-05**: Standard disclaimer/legal copy blocks (opening disclaimer, routine clearance
  interstitial, urgent clearance interstitial, persistent compact tag, expanded disclaimer,
  required-blocking message, standing footer disclaimer) appear at their defined touchpoints.

- [x] **HEALTH-06**: Red-flag escalation logic applies: any "Not sure" resolves to the more
  cautious branch; when 2+ red-flag tags apply, the single most restrictive gate wins across all
  applicable tags (never averaged/blended/softened); a `required-blocking` gate blocks
  personalization in that domain only, never app access as a whole (manual logging/generic info
  stays available). Ritham never generates insulin-dosing or medication-adjustment suggestions,
  for any user, under any tag/combination, no exception via clearance toggle.

### Age Floor

- [x] **MINOR-01**: Ritham requires users to be 13 or older, permanently — there is no under-13
  tier of any kind, reduced-functionality or otherwise. Age (Q0) is self-attested with no
  verification beyond entry; an age under 13 shows a plain blocking message and lets the user back
  out and re-enter a different age, with nothing saved for the rejected attempt. A 13–17-year-old
  gets identical access to an 18+ user from the moment they enter their age — no parental consent
  step, no partial gate, no age-based fork anywhere in the product, consistent with CROSSGEN-05.
  If a confirmed user later edits their age down below 13 (e.g. in Settings), the edit is rejected
  and the previous age is kept — never silently saved, never a retroactive lockout.

### Dietary Pattern

- [ ] **DIET-01**: User sets a `dietary_pattern` (none/vegetarian/vegan, single-select) whenever
  they choose to, in Settings — not a mandatory onboarding step. Editable anytime, no
  expiry/re-screen. Never changes a Clearance Gate value, never triggers `required-blocking`,
  never blocks/unlocks/softens a condition-specific suggestion. A user who never sets one simply
  has none on file — nothing else in the app depends on it being set.
  *2026-08-29 revision*: originally shipped in Phase 1 as Q0b, asked unconditionally right after
  age in onboarding. Removed from onboarding after direct product feedback that the question felt
  arbitrary that early and some users may not want to engage with diet features at all — the
  Settings-editable path (`SettingsView`) already existed independently and needed no new code to
  become the only way to set it. Re-homed to Phase 2 since that's where `DIET-02`/`DIET-03`
  (its actual consumers) live, though the specific "diet plan" screen this eventually surfaces in
  is not yet scoped.

- [ ] **DIET-02**: When the Nutrition Adjustment Rule Table's gate resolves to `none` or
  `recommended`, a dietary-pattern-keyed lookup decides which example foods populate the already-
  permitted slot (mapped rows: Baseline, Diabetes Plate Method, Hypertension DASH-style, Heart
  Disease AHA pattern). A `required-blocking` gate stays unchanged and shows zero food content
  regardless of dietary pattern.

- [ ] **DIET-03**: Vegan and vegetarian nutrient-awareness education blocks (B12, iron, zinc,
  omega-3, calcium, vitamin D, iodine for vegan; B12/iron/zinc/omega-3 for vegetarian) are shown
  once, as general education, identical regardless of any condition tag also present.

### Cross-Generational Design

- [ ] **CROSSGEN-01**: Home screen shows exactly 3 things by default — today's target, current
  streak, last session summary; everything else is one tap deeper.

- [ ] **CROSSGEN-02**: Passive-first capture (auto-detect walk/run from motion sensors) is
  available, alongside full manual session configuration for power users.

- [x] **CROSSGEN-03**: Privacy is explained on one screen, in plain language, before being
  requested — nothing is shared or synced by default.

- [ ] **CROSSGEN-04**: Visibility is a spectrum (not binary) per social surface. v1 delivers two
  rungs — fully private solo use, or opt-in household circle sharing; a third rung, an opt-in
  friend-only accountability circle, arrives in v2 (see HOUSEHOLD-02).

- [x] **CROSSGEN-05**: No age gating anywhere in the product; no screen is ever labeled "senior
  mode," and there is no separate under-18 app mode or age-based navigation fork.

### Cardio & Activity Tracking

- [ ] **CARDIO-01**: Activity-type selector (Run/Walk/Cycle/Hike/Swim/Elliptical, extensible),
  manual stopwatch for non-GPS sessions, and full training history — all free at launch,
  permanently, stored local-first with cloud sync as backup only.

- [ ] **CARDIO-02**: GPS pace/distance/elevation/splits/grade-adjusted pace, shown with a visible
  accuracy/confidence indicator rather than a silently varying number.

- [ ] **CARDIO-03**: Route/segment comparison is available but opt-in only — no default public
  KOM/leaderboard.

### Strength Tracking

- [ ] **STRENGTH-01**: Set logging with auto-fill of the previous session's weight/reps.
- [ ] **STRENGTH-02**: Free plate calculator (standard barbell, EZ bar, trap bar, Smith machine,
  stack machines) with nearest-loadable-weight display.

- [ ] **STRENGTH-03**: Built-in supersets/circuits.
- [ ] **STRENGTH-04**: Auto-tagged movement pattern (push/pull/squat/hinge/carry), filterable in
  history/progress.

- [ ] **STRENGTH-05**: Full retroactive editing with date-picker/year-jump navigation and session
  merge/split.

### Monetization Boundary

- [ ] **MONETIZE-01**: The "always free" feature list (core GPS/manual-stopwatch tracking, with
  heart-rate display when a device is paired but never required, full training history, plate/1RM
  calculators, superset support, movement-pattern tagging, all streak-forgiveness mechanics) is
  stated visibly in-app (e.g., Settings), not just as internal policy, and matches what is
  actually never paywalled elsewhere in the app.

### Momentum (Streak System)

- [ ] **MOMENTUM-01**: A single cross-modality streak treats a qualifying cardio session
  (continuous tracked movement, minimum 10 minutes, GPS or manual stopwatch) and a qualifying
  lift session (at least 3 working sets across 2+ exercises) as equally valid toward one shared
  weekly target (default 3, user-adjustable 2–5). Manually-entered sessions count but are
  labeled distinctly from sensor-verified ones. First Momentum week starts pre-filled at 1/3
  after the user's first logged session, not 0/3.

- [ ] **MOMENTUM-02**: Shields accrue automatically (1 per 4 consecutive successful weeks,
  stacking up to 3), are never purchasable, and auto-apply the moment a week is about to be
  missed.

- [ ] **MOMENTUM-03**: The tracked week resets Monday 3am local time, not midnight Sunday. A
  user-initiated "Recovery Week" flag pauses the target without breaking the streak count; it is
  never auto-triggered by the app.

- [ ] **MOMENTUM-04**: A missed week (no guardrail, no shield) is restored via a single "Comeback
  Session" logged within 3 days, restoring the streak count minus one — never zeroing it.

- [ ] **MOMENTUM-05**: Milestone rewards (badge + bonus shield) arrive at 4/12/26/52 weeks.
  Framing is informational/competence-based, never threat-framed (e.g., "Week 1 of your rebuilt
  streak," never a deleted/reset-to-zero animation).

- [ ] **MOMENTUM-06**: Streak/shield visibility is private by default; only opt-in
  household/accountability-contact sharing is available; there is never a public leaderboard of
  streak length.

- [ ] **MOMENTUM-07**: A separate, optional Daily Movement Snapshot exists with no
  streak/shield/target attached to it.

- [ ] **MOMENTUM-08**: A self-reported pain/injury flag can automatically trigger a streak freeze
  (self-reported version only in v1; pattern-detected auto-freeze is v2 — see INJURY-02).

### Recovery-Aware Momentum

- [ ] **RECOVERY-01**: A daily self-report prompt (Great/OK/Poor + optional note) is the sleep
  signal for the day's suggested session. Poor sleep shifts the suggestion toward
  technique-light/lower-velocity/lower-force/moderate-intensity work; a single poor night is
  never presented as injury-risk messaging. The following invariants hold without exception: the
  10-minute/3-working-set qualification bar never changes; a lighter suggested session that meets
  the bar fully qualifies for Momentum, identical in effect to any other qualifying session;
  declining the lighter suggestion and doing the original harder session is always available and
  fully qualifies; skipping the check-in has zero effect (never a penalty, never an assumed "bad"
  state); the feature never auto-consumes a shield and never auto-triggers a Recovery Week; the
  weekly cadence target is untouched; no penalty/asterisk/badge/messaging differentiates training
  harder than suggested vs. accepting the lighter option.

### Household

- [ ] **HOUSEHOLD-01**: Household grouping (e.g., grandparent/parent/teenager under one plan)
  with the only cross-member interaction being a fixed, non-ranked cheer set ("nice work"/"keep
  going") — no shared leaderboard, no visible pace/weight comparison between members.

### Launch Readiness (Legal & Clinical Review)

- [ ] **LAUNCH-01**: PAR-Q+-style gate-question wording has been reviewed by counsel before
  "PAR-Q+" is referenced by name anywhere in-product (or the app ships without the branded name
  until cleared).

- [ ] **LAUNCH-02**: The SCOFF eating-disorder screen's wording and scoring have been confirmed
  by a clinician before shipping to any user.

- [ ] **LAUNCH-03**: Every protein-swap example-food entry flagged as Ritham's own construction
  (not directly sourced from ADA/NHLBI, per docs/dietary-pattern.md §3 footnotes) has dietitian
  sign-off before the nutrition guidance ships.

- [ ] **LAUNCH-04**: A completed GDPR/CCPA privacy review covers all sensitive health data
  collected during intake (condition tags, SCOFF responses, and any other screening data), with
  the disclosures/consent flows it requires in place, before public App Store submission.

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Cardio/Strength Enhancements

- **SCHED-01**: Interference-aware scheduler — after a logged heavy leg day, flag the next day's
  planned run with a lighter-intensity suggestion and a one-line reason.

- **WEAR-01**: Multi-wearable fusion — ingest Oura, WHOOP, Garmin, and Apple Watch simultaneously
  into one training-load view, no vendor lock-in.

- **WEAR-02**: Wearable HRV/sleep-stage data augments (never replaces) RECOVERY-01's self-report
  signal; a single isolated HRV reading never drives the day's suggestion alone.

### Onboarding & Accessibility

- **ONBOARD-02**: Auto-calibrated first-session baseline formally replaces self-reported fitness
  level at onboarding.

- **A11Y-01**: Full screen-reader accessibility audit and hardening.

### Momentum Enhancements

- **INJURY-02**: Pattern-detected injury guardrail (e.g., pace slowing at consistent effort)
  auto-suggests a freeze — transparent, user-confirmed, never silently auto-triggered.

### Cycle Tracking

- **CYCLE-01**: Opt-in menstrual cycle tracking as an adaptive-suggestion layer — never a
  condition, never gated, never part of mandatory health intake. Settings-page opt-in only, off
  by default, with a consent screen before enabling. Logs period start dates (primary), optional
  average cycle length, optional daily symptom tags (the actual suggestion-adjustment trigger,
  not the phase label), optional contraceptive method category. Phase estimate is presented as
  low-confidence, context-only — never the suggestion trigger. Confidence downgrades for
  irregular cycle length or hormonal contraceptive use. **Hard rule**: if a Pregnancy or
  Postpartum tag is added while cycle tracking is on, it auto-disables immediately (one-time
  notice); re-enabling always requires a fresh explicit opt-in. Composes with RECOVERY-01 into a
  single most-conservative suggestion when both would adjust the same day; neither ever gates a
  session.
  *Deferred reason*: opt-in but adds special-category health data (consent flow, symptom logs,
  contraceptive-method categories) to the pre-launch privacy review surface; deferring keeps
  v1's GDPR/CCPA review (LAUNCH-04) scoped and v1 shippable sooner.

### Weekly Timetable

- **TIMETABLE-01**: Editable weekly-rhythm template (default movement/food-pattern arrangement by
  day, not a rigid prescription) with an Under-18 variant (school-schedule-aware, HHS-aligned,
  exam-period "micro-break" mode without streak penalty) and a 65+ variant (HHS/NHS adult floor +
  multicomponent balance/functional-strength requirement, routine-consistency defaults). Adds no
  new condition tags, gates, or adjustment logic beyond HEALTH-03/HEALTH-04 — purely a rendering
  layer. Required-blocking cells show the referral message, never a quantity/intensity; the
  timetable shell stays editable regardless of gate state; completing/skipping a timetable slot
  never itself triggers streak gain/loss (only an actual qualifying Momentum session counts).
  **Correction needed before shipping**: `docs/weekly-timetable.md` §4 Design Rule 3's cell text
  currently narrows the qualifying-session definition by omitting the manual-stopwatch path — must
  be corrected to match MOMENTUM-01's definition before this feature ships.
  *Deferred reason*: a UX layer over v1's already-shipped condition-tag guidance (HEALTH-03/04),
  not new safety logic — v1 ships the underlying guidance without the dedicated weekly-grid UI.

### Social & Groups

- **HOUSEHOLD-02**: Opt-in accountability-circle visibility tier, beyond household — friend-only,
  Apple-Fitness-Competitions-style, never public.

- **GROUPEVENTS-01**: Friends/groups data model — mutual/request-based friending (never
  one-directional follow), three closed-loop connection paths (contact matching off by default
  and both-sides opt-in, invite link/QR expiring after a set window or first use, in-person/direct
  share), small closed invite-only groups (no public/joinable-by-anyone tier), any member can
  leave anytime with no ownership-transfer gate. Visibility ladder capped at Only Me → Household →
  this specific group — no "friends of friends" rung, no "Public/Everyone" rung, for any surface.

- **GROUPEVENTS-02**: Goal-Event data model — a shared, non-timed commitment; organizer sets
  activity type, optional target (distance/duration), and target date/window, no synchronized
  start. Each person logs their own completion independently; own time is optional, off by
  default, skippable with zero friction. Personal distance/pace/route stay in the user's private
  log only. No ranking mechanism of any kind (no pooled total, no contribution ranking, no
  leaderboard sort, no score, no winner). Feed ordered chronologically by post time. Non-completion
  is a non-event — no denominator paired with completion count, no expiry notice.

- **GROUPEVENTS-03**: Photo/location privacy — EXIF GPS/metadata stripped server-side,
  unconditionally, before any group-visible or exportable write (never relies on client-side
  stripping alone); original file retained only in the user's private library. Location sharing is
  a separate, explicit opt-in from photo sharing. Default location display (if opted in) is a
  reverse-geocoded coarse named place — never coordinates, a pin, an address, or a numeric radius.
  User-set Privacy Zones (home, workplace) are automatically generalized/suppressed across every
  shared surface. Ritham will never build a cross-user aggregate location visualization.

- **GROUPEVENTS-04**: Shared feed — visible to the group only, by default and permanently; not
  public, not discoverable, not indexed, no generic shareable link. Leaving/removal removes future
  feed access but past completion cards remain visible to the group. Never shows pace, time-based
  rank, "first to complete," a completion denominator, or precise location.

- **GROUPEVENTS-05**: Digital certificate — auto-generated per person on completion (Ritham
  branding, event name/activity type, participant's own name, completion date, own time only if
  opted in). Never includes pace, measured distance, rank, GPS/address, or any other member's
  name/photo/status/time. Default export template is a branded graphic/badge, not the user's own
  photo. Event name gets a creation-time identity-disclosure nudge for the organizer and an
  editable export-time display name for the exporter.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cross-user aggregate location visualization (heatmap, "most active area" feature) | Permanent product-category exclusion per `docs/group-events.md` §3 — never building this, regardless of milestone |
| Public leaderboards of streak length, pace, or weight lifted, anywhere in the app | Structural design commitment across `docs/roadmap.md` and `docs/group-events.md` — visibility is always private-by-default with opt-in circles, never public ranking |
| Insulin-dosing or medication-adjustment suggestions, for any user, any condition-tag combination | Standing product-wide prohibition per `docs/health-screening.md` §5, no exception via any clearance toggle |
| Camera-based form correction | Moonshot tier per `docs/roadmap.md` §5 — speculative, no near-term plan |
| Chronic-pain-aware pacing engine | Moonshot tier per `docs/roadmap.md` §5 |
| Perimenopause/hormonal-transition-aware programming track | Moonshot tier per `docs/roadmap.md` §5 |
| VR/AR training mode | Moonshot tier per `docs/roadmap.md` §5 |
| Full AI fusion coaching | Moonshot tier per `docs/roadmap.md` §5 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ONBOARD-01 | Phase 2 (provisional) | Not started -- domain/UI built in Phase 1, kept for reuse; trigger not yet built |
| EXPLAIN-01 | Phase 1 | Complete |
| HEALTH-01 | Phase 1 | Complete |
| HEALTH-02 | Phase 1 | Complete |
| MINOR-01 | Phase 1 | Complete |
| HEALTH-05 | Phase 1 | Complete |
| HEALTH-06 | Phase 1 | Complete |
| CROSSGEN-03 | Phase 1 | Complete |
| CROSSGEN-05 | Phase 1 | Complete |
| CARDIO-01 | Phase 2 | Pending |
| CARDIO-02 | Phase 2 | Pending |
| CARDIO-03 | Phase 2 | Pending |
| STRENGTH-01 | Phase 2 | Pending |
| STRENGTH-02 | Phase 2 | Pending |
| STRENGTH-03 | Phase 2 | Pending |
| STRENGTH-04 | Phase 2 | Pending |
| STRENGTH-05 | Phase 2 | Pending |
| HEALTH-03 | Phase 2 | Pending |
| HEALTH-04 | Phase 2 | Pending |
| DIET-01 | Phase 2 | Pending |
| DIET-02 | Phase 2 | Pending |
| DIET-03 | Phase 2 | Pending |
| MONETIZE-01 | Phase 2 | Pending |
| CROSSGEN-02 | Phase 2 | Pending |
| MOMENTUM-01 | Phase 3 | Pending |
| MOMENTUM-02 | Phase 3 | Pending |
| MOMENTUM-03 | Phase 3 | Pending |
| MOMENTUM-04 | Phase 3 | Pending |
| MOMENTUM-05 | Phase 3 | Pending |
| MOMENTUM-06 | Phase 3 | Pending |
| MOMENTUM-07 | Phase 3 | Pending |
| MOMENTUM-08 | Phase 3 | Pending |
| RECOVERY-01 | Phase 3 | Pending |
| HOUSEHOLD-01 | Phase 4 | Pending |
| CROSSGEN-01 | Phase 4 | Pending |
| CROSSGEN-04 | Phase 4 | Pending |
| LAUNCH-01 | Phase 5 | Pending |
| LAUNCH-02 | Phase 5 | Pending |
| LAUNCH-03 | Phase 5 | Pending |
| LAUNCH-04 | Phase 5 | Pending |

**Coverage:**

- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-19*
*Last updated: 2026-08-23 — reversed the 2026-08-22 tiered parental-consent gate: removed MINOR-02
and LAUNCH-05 (COPPA review) entirely, and rewrote MINOR-01 as a permanent 13+ age floor with no
minor-consent flow of any kind. See PROJECT.md Key Decisions and `01-CONTEXT.md` for the full
reasoning (GitHub issue #1).*
