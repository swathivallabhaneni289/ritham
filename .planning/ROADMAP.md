# Roadmap: Ritham

## Overview

Ritham ships as five phases that build a safe foundation before layering tracking, habit
mechanics, and social features on top. Phase 1 establishes onboarding, the explanation layer, and
the safety-screening intake that every later feature depends on for its condition-tag guardrails.
Phase 2 delivers the free-forever cardio and strength tracking core, with workout/nutrition
guidance now adjustable by the condition tags Phase 1 collected. Phase 3 builds the cross-modality
Momentum streak system on top of that logging, plus the sleep-based Recovery-aware suggestion
layer. Phase 4 adds household accounts and the cross-generational home screen, both of which need
real streak and session data to be observable. Phase 5 is the pre-launch legal/clinical review
gate — PAR-Q+ wording, SCOFF wording, dietitian sign-off, and a GDPR/CCPA privacy review — required
before public App Store submission per the project's success metric.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Onboarding & Safety Intake** - New users complete a fixed-choice safety screening that gates every later feature's condition-aware guidance (calibration deferred to Phase 2's triggered pre-assessment, see Key Decisions)
- [ ] **Phase 2: Core Tracking & Adjusted Guidance** - Free-forever cardio and strength tracking, with condition-tag-adjusted workout/nutrition guidance and dietary-pattern swaps
- [ ] **Phase 3: Momentum & Recovery** - A single fair, forgiving cross-modality weekly streak that adapts to sleep without ever punishing rest
- [ ] **Phase 4: Household & Home** - Cross-generational households share one app with a simple home screen and structurally non-comparative encouragement
- [ ] **Phase 5: Launch Readiness (Legal & Clinical Review)** - Clinical and legal sign-off plus a completed privacy review, clearing the app for public App Store submission

## Phase Details

### Phase 1: Onboarding & Safety Intake

**Goal**: Every new user, regardless of age or health background, completes a safety screening that will safely gate personalized guidance later — without ever being funneled into a separate "senior" or "kid" experience.
**Depends on**: Nothing (first phase)
**Requirements**: EXPLAIN-01, HEALTH-01, HEALTH-02, HEALTH-05, HEALTH-06, MINOR-01, CROSSGEN-03, CROSSGEN-05
**Success Criteria** (what must be TRUE):

  1. *Revised 2026-09-01 (see PROJECT.md Key Decisions):* Onboarding contains no calibration or
     fitness-assessment step of any kind — a new user's flow is exactly welcome, the 13+ age
     floor, the privacy explainer, then the complete safety screening straight through to home.
     A real guided walk-or-light-lift pre-assessment (never a self-reported fitness-level
     dropdown, ONBOARD-01) still exists and is unchanged in kind — it now triggers later, the
     first time a user requests exercise recommendations, and is scoped to Phase 2 (provisional).

  2. Ritham speaks to every user in one consistent voice, with no explanation-register choice
     anywhere in onboarding or Settings, and every technical term elsewhere is tap-to-expand into
     that one well-written definition.

  3. A user completes the fixed-choice screening questionnaire (age, gate questions, condition
     checklist, SCOFF follow-up where triggered) with no free-text entry or live AI-generated
     advice anywhere in the flow; "Not sure" answers and multi-tag conflicts always resolve to the
     single most restrictive path, a blocking result only restricts that one domain (never the
     rest of the app), and condition tags stay valid for 12 months or until edited, prompting a
     re-screen at expiry.

  4. No user ever sees a "senior mode," a separate under-18 app mode, or an age-based navigation
     fork — age only ever adjusts content within shared screens.

  5. A user under 13 sees a plain blocking message and cannot proceed — Ritham has no under-13
     tier of any kind, permanently. Anyone 13 or older gets full, identical access from the moment
     they enter their age: tracking, Momentum, and the complete safety screening (gate questions,
     condition checklist, SCOFF) — no parental consent step, no partial gate, at any age from 13
     up.

  6. A user sees privacy/sharing explained on one screen, in plain language, before being asked to
     opt in — nothing is shared or synced with anyone by default.
**Plans**: 14/14 plans executed — Phase complete 2026-09-03

Plans:

- [x] 01-01-PLAN.md — RithamCore package, toolchain-adaptive test harness, and the single-source copy catalog
- [x] 01-03-PLAN.md — Screening domain: condition tags, orderable clearance gates, fixed-choice answers, tag validity
- [x] 01-05-PLAN.md — Calibration domain: completion thresholds and baseline derivation
- [x] 01-06-PLAN.md — Gate resolution: tag derivation plus the sixteen red-flag escalation rules
- [x] 01-07-PLAN.md — Onboarding routing core, the permanent 13+ age floor, and its no-age-fork guarantee
- [x] 01-09-PLAN.md — Xcode install checkpoint, iOS app target, single shared navigation container
- [x] 01-10-PLAN.md — Design system: palette, type scale, spacing, computed band motif geometry
- [x] 01-11-PLAN.md — SwiftData persistence with file protection (no consent gate — see D-14)
- [x] 01-12-PLAN.md — Shared UI components and the tap-to-expand glossary
- [x] 01-13-PLAN.md — Welcome, explanation register, age, age-ineligible block, dietary pattern, privacy explainer
- [x] 01-15-PLAN.md — Calibration screens with pedometer and stopwatch sources
- [x] 01-16-PLAN.md — The screening questionnaire: disclaimer, gate section, interstitials, checklist, follow-ups
- [x] 01-17-PLAN.md — Disclaimer surfaces, health profile, Settings and re-screen
- [x] 01-18-PLAN.md — Step bootstrap, phase coverage assertions, end-to-end human verification
  (Task 2's physical-device calibration walk superseded by the 2026-09-01 decision below —
  only the AX3/AX5 accessibility pass was required; disclaimer-tag check deferred to Phase 4,
  see deferred-items.md)

*2026-08-23: four plans removed entirely (01-02 Go consent service, 01-04 consent domain, 01-08*
*consent HTTP API, 01-14 consent screens/client) after D-14 replaced tiered parental consent with a*
*permanent 13+ age floor — see `01-CONTEXT.md` D-14/D-15 and `01-DISCUSSION-LOG.md`. Original count*
*was 18 plans across 9 waves; no wave was fully emptied, so the wave count is unchanged.*

*2026-09-01: calibration moved out of onboarding entirely (see PROJECT.md Key Decisions).*
*01-05 and 01-15 stay checked — the calibration domain and screens they built are real, working,*
*and kept intact for reuse by the future exercise-recommendation flow; only `OnboardingRouter`'s*
*wiring changed (calibration is now router-unreachable from `.welcome`). This also resolves*
*01-18's remaining human-verification gap: its physical-device GPS calibration walk task is moot*
*now that calibration isn't part of onboarding's closure criteria — only the AX3/AX5*
*accessibility pass remains for 01-18. `RadialSessionTimer` (built 2026-09-01 for the calibration*
*session screen) has not yet been verified at AX3/AX5 itself, since that screen is currently*
*unreachable in the running app — carry that check into whichever phase builds the*
*recommend-exercises trigger.*
**UI hint**: yes

### Phase 2: Core Tracking & Adjusted Guidance

**Goal**: Users can log every real training session — cardio or strength — and see safety-adjusted guidance the moment it applies, forever for free.
**Depends on**: Phase 1
**Requirements**: CARDIO-01, CARDIO-02, CARDIO-03, STRENGTH-01, STRENGTH-02, STRENGTH-03, STRENGTH-04, STRENGTH-05, HEALTH-03, HEALTH-04, DIET-01, DIET-02, DIET-03, MONETIZE-01, CROSSGEN-02, ONBOARD-01
**Success Criteria** (what must be TRUE):

  1. A user can track a cardio session via GPS (pace/distance/elevation/splits/grade-adjusted
     pace with a visible confidence indicator) or via manual stopwatch for non-GPS activities, and
     can let the app auto-detect a walk/run from motion sensors while still fully configuring a
     session manually.

  2. A user can log a strength session with auto-filled weight/reps from their last session, a
     free plate calculator across barbell/EZ/trap/Smith/stack equipment, built-in supersets,
     auto-tagged movement patterns filterable in history, and can retroactively edit/merge/split
     any past session via a year-jump date picker.

  3. Route/segment comparisons are opt-in only — no session ever appears on a public leaderboard
     by default.

  4. A user with an applicable condition tag sees workout guidance adjusted for that tag the
     moment they log or plan a session, and a required-blocking tag replaces personalized
     intensity guidance with a generic referral message — never restricting app access in any
     other area.

  5. A user with an applicable condition tag sees nutrition guidance built only from published
     population-level reference figures (never an individually calculated number), matched to
     their dietary pattern when the underlying gate allows it, and a required-blocking nutrition
     tag shows zero personalized quantity of any kind for that domain.

  6. In Settings, a visible "always free" list confirms that GPS/manual-stopwatch tracking, full
     history, plate/1RM calculators, supersets, and movement-pattern tagging are never paywalled —
     matching what's actually gated (or not) elsewhere in the app. *Corrected 2026-09-04 (plan
     checker finding): the original wording also named "heart-rate display when a device is
     paired," but this phase builds no wearable-pairing capability at all — that's WEAR-01 (v2).
     Listing an unbuilt capability would violate this same criterion's own "matches what's
     actually gated (or not) elsewhere" test. Heart-rate display returns to this list whenever
     WEAR-01 ships.*

  7. A user can set a dietary pattern (none/vegetarian/vegan) whenever they choose to — never a
     mandatory onboarding step — and it never changes a clearance-gate outcome.

  8. *Resolved 2026-09-04 (see `02-CONTEXT.md` D-01–D-04, D-06/D-07):* a user opens a dedicated
     Recommendations surface and requests exercise recommendations; the first time they do, they
     complete the real walk-or-light-lift pre-assessment moved out of onboarding (ONBOARD-01) —
     via a new, separate `WorkoutSession` domain (not a reuse of Phase 1's `CalibrationSession`),
     completion stays baseline-only and never enters training history. Recommendations factor in
     age and applicable condition tags from the safety screening, generated by a new Go backend
     service (`RithamService`) the client calls with a minimized signal — never raw condition
     tags or SCOFF answers — per D-07. Stays folded into Phase 2, not its own phase.

  9. *Added 2026-09-04 (see `02-CONTEXT.md` D-05):* Phase 2 builds a lightweight interim
     navigation hub so its own features (tracking, recommendations, diet plan) are reachable in
     the running app — not Phase 4's polished 3-item CROSSGEN-01 home design, just enough real
     navigation to replace Phase 1's `.home` stub until Phase 4 ships.
**Plans**: 9/16 plans executed

Plans:

- [x] 02-01-PLAN.md — Cardio domain: activity types, session/split value types, accuracy-filtered
  track accumulator, grade-adjusted pace with elevation-confidence gating

- [x] 02-02-PLAN.md — Strength lookups: equipment, plate calculator, 1RM estimator,
  movement-pattern catalog

- [x] 02-03-PLAN.md — Lift session domain: stable set identity, auto-fill lookup, superset
  grouping, retroactive merge/split

- [x] 02-04-PLAN.md — Content-permission layer and the workout guidance catalog (§2 transcription)
- [x] 02-05-PLAN.md — `RithamService`: Go workout-plan service, stdlib-only, one loopback-bound
  endpoint (D-06/D-07)

- [x] 02-06-PLAN.md — Phase 2 navigation contract and the interim home hub; makes Settings (and
  DIET-01's diet plan) reachable for the first time (D-05)

- [x] 02-07-PLAN.md — Nutrition guidance catalog (§3) plus dietary swaps and nutrient-education
  blocks (DIET-02/DIET-03)

- [x] 02-08-PLAN.md — Complete Phase 2 persistence surface: session/set records and every new
  `HealthDataStore` accessor

- [x] 02-09-PLAN.md — Cardio capture adapters: manual stopwatch, first-class GPS session,
  foreground-only motion auto-detect

- [ ] 02-10-PLAN.md — Cardio UI: activity picker, live session with visible confidence, history,
  opt-in single-user route comparison

- [ ] 02-11-PLAN.md — Strength logging UI: set entry with auto-fill, plate/1RM calculator,
  superset building

- [ ] 02-12-PLAN.md — Guidance UI: inline adjusted guidance at logging time plus the dedicated
  guidance screen (HEALTH-03/04, DIET-02/03)

- [ ] 02-13-PLAN.md — Recommendations surface, the triggered walk-or-light-lift pre-assessment,
  and the Go plan client (ONBOARD-01)

- [ ] 02-14-PLAN.md — Settings: visible always-free list and the weekly workout-frequency
  preference (MONETIZE-01)

- [ ] 02-15-PLAN.md — Strength history: movement-pattern filter, year-jump navigation, retroactive
  edit/merge/split (STRENGTH-04/05)

- [ ] 02-16-PLAN.md — Phase close-out: fix the `StepRegistry` cross-suite race, assert Phase 2 step
  coverage, on-device sensor and Go round-trip checkpoints, AX3/AX5 pass

**UI hint**: yes
**Backend**: Go (`RithamService/`) — new for this phase, workout-plan generation only. See
`PROJECT.md` Key Decisions and `02-CONTEXT.md` D-06/D-07 for scope and rationale (a job-search
decision, not a Ritham product requirement — iOS client stays Swift).

### Phase 3: Momentum & Recovery

**Goal**: Users build one fair, cross-modality weekly consistency habit that forgives real life — rest, injury, and bad sleep — without ever punishing them for it.
**Depends on**: Phase 2
**Requirements**: MOMENTUM-01, MOMENTUM-02, MOMENTUM-03, MOMENTUM-04, MOMENTUM-05, MOMENTUM-06, MOMENTUM-07, MOMENTUM-08, RECOVERY-01
**Success Criteria** (what must be TRUE):

  1. A qualifying cardio session (10+ continuous minutes, GPS or manual stopwatch) or a qualifying
     lift session (3+ working sets across 2+ exercises) counts equally toward one shared weekly
     Momentum target (default 3, adjustable 2-5); manually-entered sessions count but are visibly
     labeled distinct from sensor-verified ones, a user's first week starts pre-filled at 1/3 after
     their first logged session, and a milestone badge + bonus shield arrive at 4/12/26/52 weeks.

  2. A missed week (no shield) is restored via a single Comeback Session logged within 3 days,
     restoring the streak minus one (never to zero); a self-reported pain/injury flag can
     auto-freeze the streak automatically, and the weekly reset boundary is Monday 3am local time,
     not midnight Sunday.

  3. Shields accrue automatically (1 per 4 consecutive successful weeks, stacking up to 3) and can
     never be purchased; a user-initiated Recovery Week flag pauses that week's target without
     breaking the streak and is never triggered automatically by the app itself.

  4. A user who logs a sleep check-in (Great/OK/Poor) sees the day's suggested session shift
     lighter on a Poor night, but accepting the lighter session counts identically to any other
     qualifying session, declining it and doing the original session also fully qualifies,
     skipping the check-in has zero effect on streak or messaging, and no session is ever flagged
     for being "harder" or "easier" than suggested.

  5. No streak-loss animation or threat-framed message ever appears (a rebuilt streak is framed as
     "Week 1 of your rebuilt streak," never "reset to zero"), streak/shield visibility defaults to
     fully private with only opt-in household/accountability-contact sharing — never a public
     leaderboard — and a separate, optional Daily Movement Snapshot is available with no streak,
     shield, or target attached to it.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Household & Home

**Goal**: Families spanning generations share one app and one encouraging home screen — with comparison and ranking structurally impossible, not just discouraged.
**Depends on**: Phase 3
**Requirements**: HOUSEHOLD-01, CROSSGEN-01, CROSSGEN-04
**Success Criteria** (what must be TRUE):

  1. A user's home screen shows exactly 3 things by default — today's target, current streak,
     last session summary — with everything else exactly one tap deeper, identically for every
     age in the household.

  2. A user can group into a household (e.g., grandparent/parent/teen) where the only
     cross-member interaction is a fixed, non-ranked cheer ("nice work"/"keep going") — there is
     no shared leaderboard and no visible pace/weight comparison between members, structurally,
     not just by convention.

  3. For every social surface, a user picks a point on a visibility spectrum — private solo, or
     opt-in household sharing — never a binary public/private toggle, and nothing is shared by
     default until the user opts in. (The third rung, an opt-in friend-only accountability circle,
     arrives in v2 with HOUSEHOLD-02.)
**Plans**: TBD
**UI hint**: yes

### Phase 5: Launch Readiness (Legal & Clinical Review)

**Goal**: Ritham is cleared to submit publicly to the App Store — every piece of clinical/legal-sensitive content has been reviewed by the right professional, and the privacy review is complete.
**Depends on**: Phase 4
**Requirements**: LAUNCH-01, LAUNCH-02, LAUNCH-03, LAUNCH-04
**Success Criteria** (what must be TRUE):

  1. Counsel has reviewed the PAR-Q+-style gate-question wording before "PAR-Q+" is referenced by
     name anywhere in-product (or the app ships without the branded name until cleared).

  2. A clinician has confirmed the SCOFF eating-disorder screen's wording and scoring before
     public release.

  3. A registered dietitian has signed off on every protein-swap example-food entry flagged as
     Ritham's own construction (not directly sourced from ADA/NHLBI) before public release.

  4. A completed GDPR/CCPA privacy review covers all sensitive health data collected during
     intake (condition tags, SCOFF responses), and the app has the disclosures/consent flows
     required for public submission.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Onboarding & Safety Intake | 14/14 | Complete    | 2026-09-03 |
| 2. Core Tracking & Adjusted Guidance | 9/16 | In Progress|  |
| 3. Momentum & Recovery | 0/0 | Not started | - |
| 4. Household & Home | 0/0 | Not started | - |
| 5. Launch Readiness (Legal & Clinical Review) | 0/0 | Not started | - |

## Backlog

### Phase 999.1: Parent-facing kid ideas (food + movement content) (BACKLOG)

**Goal:** [Captured for future planning] A section within the existing adult/parent Ritham
account offering general, non-personalized food and movement ideas suitable for their own
under-13 child. The child never has a Ritham profile, login, or tracked data of their own — the
parent may optionally note an approximate child age to sharpen suggestions, but nothing about a
specific child is stored or tracked over time (no child weight, no growth curve, no session
history). This is parent-driven personalization on the parent's own account, not a child user of
the service, so it does not reopen Ritham's permanent 13+ age floor (see PROJECT.md Key Decisions
and `01-CONTEXT.md` D-14/D-15) or any COPPA concern — COPPA regulates collecting information from
a child interacting with the service, not information an adult voluntarily provides about their
own child for their own account's content.

Not in scope for Phase 1 (onboarding/safety intake) — depends on the nutrition-guidance system
that ships in Phase 2, and likely fits alongside Phase 4's household/cross-generational features.
Needs its own clinical review before shipping: current HEALTH-04 only covers guidance for the
app's own 13-17 user (general food-variety education, no weight-loss framing, per AAP guidance) —
content aimed at actual young children is a distinct, more sensitive pediatric nutrition/
youth-movement category and would need the same dietitian/clinical sign-off discipline
(LAUNCH-02/03) as SCOFF and the existing nutrition rule tables, not casually authored tips.

Originated from the 2026-08-24/25 session that also produced the permanent 13+ age floor decision
(GitHub issue #1, closed) and a still-open, not-yet-captured device-continuity/account-sync idea.

**Requirements:** TBD
**Plans:** 14/14 plans complete

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.2: Optional cross-device account/sync (email login) (BACKLOG)

**Goal:** [Captured for future planning] An optional email-based login letting a user see their
own data (workout history, streaks, etc.) on a different device — not required to use the app,
core tracking stays fully functional with zero login. This is the surviving half of GitHub issue
#1 (closed 2026-08-24): its original motivation was parental-consent state surviving a device
change, which no longer applies now that Ritham has a permanent 13+ age floor with no consent
flow of any kind — but the general "does a user's training data survive a device change" question
was never resolved and remains open for every user, any age. Tracked in GitHub issue #2.

Aligns with PROJECT.md's existing (unlocked) Key Decision — "local-first data storage; cloud sync
is backup, not source of truth" — implemented as an opt-in account rather than a mandatory one, so
it doesn't collide with the "core tracking free forever, no account required" promise or Apple's
App Store Guideline 5.1.1(v) (no account requirement for features that don't need one). Not in
scope for Phase 1 — there is no trackable data to sync until Phase 2 (Core Tracking) and Phase 3
(Momentum) ship; may extend Phase 4's existing "household accounts" concept rather than being a
wholly new one. Open question, not yet decided: auth method (email+password, Sign in with Apple,
or both).

**Requirements:** TBD
**Plans:** 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.3: Onboarding visual polish, round 2 (RESOLVED 2026-09-02)

**Goal:** [Captured for future planning] A grab-bag of live-review feedback from the 2026-08-29
session, given explicitly as "write these down, don't implement now" — surfaced here so
`/gsd-progress` picks it up as the starting point for a future session, not lost in chat history.
All four items below were resolved via targeted fixes rather than a formal plan; no promotion to
requirements/plans needed.

1. ~~**A "plain terms" concern was re-raised for onboarding question copy.**~~ **RESOLVED
   2026-09-02.** Confirmed (b): the opening disclaimer and gate section headlines read as
   deliberately simplified. Already addressed by `936f25b` (reword the opening disclaimer headline
   as a lead-in, not a label) and `6e8ec7f` (add a headline, tighten the intro paragraph, compact
   the emergency notice on the gate section screen) — product owner confirmed current wording
   looks good. No further action.

2. ~~**Calibration should state up front how long the walk/lift session will take**, and its
   in-session progress indicator should change from a straight-line/linear bar to a circular,
   clock-like radial timer.~~ **RESOLVED**, prior to this session, by `e522390` ("radial session
   timer, upfront duration, and live-review copy fixes") — `RadialSessionTimer.swift` and
   `CalibrationSessionView` now cover this; the decorative ring-and-dot motif (`RingAndDot.swift`)
   was left untouched as intended.

3. ~~**`ScreeningOpeningDisclaimerView` has a large empty charcoal area above its text block.**~~
   **RESOLVED**, prior to this session, by `5cbf5c4` ("add a headline and header decoration to the
   opening disclaimer screen") — its own commit message explicitly resolves this item's flagged
   tension: verified against `ScreenHeader.swift`'s enumerated nine-screen flat-locked list that
   `screeningOpeningDisclaimer` isn't one of them (it collects no data itself), so switching to
   `.boundedHeaderOnly` (band motif + ring-and-dot, same treatment as Privacy Explainer) doesn't
   touch the locked set. Uses band motif + ring rather than the literally-requested arcs, but
   fills the empty space as asked.

4. ~~Possible related concern: the disclaimer screen "not scrolling up or down."~~ **RESOLVED
   2026-09-02**, confirmed non-issue: `RithamScreen` wraps all content in a `ScrollView`
   unconditionally (`RithamScreen.swift:97`), so this screen always scrolls per contract — this
   was, as the original note itself predicted, the screen *feeling* dense (fixed by item 3's
   decoration) rather than an actual scroll failure.

   A related regression surfaced and was fixed in the same session: `546716b` (same-day, earlier)
   added a manual `collapsedHeaderTopInset` (110pt) to `RithamScreen`'s `ScrollView` to stop
   content from scrolling behind the floating back button on the condition checklist screen. Live
   review on the gate section screen showed this reintroduced a large dead gap above the headline
   on every flat-surface screen at rest. Verified empirically in the simulator (`GateSectionView`,
   screenshots at inset=110 vs. inset=0): with the custom inset removed entirely, content already
   sits with correct, comfortable clearance below the back button — `NavigationStack`'s own safe
   area handles this on its own, `546716b`'s inset was pure redundant double-reservation, not a
   real fix. Removed the whole mechanism (`collapsedHeaderTopInset`, `headerIsCollapsed`, the
   `.safeAreaInset` block) rather than re-tuning the constant, restoring `RithamScreen` to rely on
   the system's own back-button safe-area guarantee.

**Requirements:** N/A — resolved without a formal plan.
**Plans:** 0 plans

### Phase 999.4: Full app vision — recommendations, home summary, friend/family events (BACKLOG)

**Goal:** [Captured for future planning] A broader product vision described 2026-09-01, alongside
the decision to move calibration out of onboarding into a triggered exercise-recommendation
pre-assessment (see Key Decisions in `PROJECT.md` and Phase 2's provisional success criterion 8).
Explicitly captured rather than built now — most of it already fits the existing roadmap; one
piece is genuinely new and bigger. Not yet scoped into requirements or plans.

1. **A diet-plan section and an exercise-recommendations section.** Exercise recommendations is
   Phase 2's new provisional scope (criterion 8) — the pre-assessment trigger this same session
   moved out of onboarding. Diet-plan section maps to Phase 2's existing DIET-02/DIET-03 nutrition
   guidance (population-level reference figures, matched to dietary pattern). Likely no new
   requirement needed here beyond what Phase 2 already covers — confirm during Phase 2 planning
   rather than assuming a new section is required. `FoodAllergen` selections (RithamCore,
   `HealthDataStore.loadFoodAllergens`) are already captured and stored, framed alongside dietary
   pattern in Settings (2026-09-01) — this diet-plan work is what should actually read them; until
   then they are stored but unconsumed by anything.

2. **A home page showing steps taken, calories burned, and achievement badges** (e.g. for trying a
   new exercise type). Partially covered already: Phase 4's CROSSGEN-01 locks the home screen to
   exactly 3 things by default (today's target, streak, last session summary), and Phase 3's
   MOMENTUM-01 already has a milestone-badge mechanic (4/12/26/52 weeks). Steps/calories and a
   broader achievement system beyond streak milestones are not currently scoped — needs a decision
   on whether this extends CROSSGEN-01's "exactly 3 things" rule or adds a new progressive-disclosure
   layer beneath it, not a silent expansion of what the home screen shows by default.

3. **Friend/family event creation, invites, RSVP-by-availability, and event-completion badges**
   (e.g. "create a hike to this place, ask people to join, badge on completion"). This is the
   genuinely new, bigger piece — it goes past what's currently scoped anywhere in the roadmap.
   Phase 4 today only has a household group with a fixed, non-ranked "nice work" cheer (its own
   goal: "comparison and ranking structurally impossible, not just discouraged"). A real
   invite-only friend circle was already deliberately deferred to v2 as its own item
   (`HOUSEHOLD-02`, referenced in Phase 4's rung-3 note) — this idea should extend HOUSEHOLD-02
   rather than sit as a disconnected parallel feature, since they're the same underlying capability
   (a friend-level social graph beyond the household). Two locked decisions bear directly on
   design here, not just scope: nothing in the app may become comparative ("no comparison, ever"
   is the core value, not a guideline), and location sharing defaults to no-precision (modeled
   against the Strava heatmap incident, per `PROJECT.md`'s privacy commitments) — an event like
   "hike to this place" needs that design worked out before it's just a feature request.

**Requirements:** TBD
**Plans:** 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)
