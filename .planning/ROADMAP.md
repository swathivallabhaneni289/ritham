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
- [x] **Phase 3: Momentum & Recovery** - A single fair, forgiving cross-modality weekly streak that adapts to sleep without ever punishing rest (completed 2026-09-06)
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
**Plans**: 15/16 plans executed

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

- [x] 02-10-PLAN.md — Cardio UI: activity picker, live session with visible confidence, history,
  opt-in single-user route comparison

- [x] 02-11-PLAN.md — Strength logging UI: set entry with auto-fill, plate/1RM calculator,
  superset building

- [x] 02-12-PLAN.md — Guidance UI: inline adjusted guidance at logging time plus the dedicated
  guidance screen (HEALTH-03/04, DIET-02/03)

- [x] 02-13-PLAN.md — Recommendations surface, the triggered walk-or-light-lift pre-assessment,
  and the Go plan client (ONBOARD-01)

- [x] 02-14-PLAN.md — Settings: visible always-free list and the weekly workout-frequency
  preference (MONETIZE-01)

- [x] 02-15-PLAN.md — Strength history: movement-pattern filter, year-jump navigation, retroactive
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

     *Household half deferred 2026-09-06 (see `03-CONTEXT.md` D-06): Phase 3 ships only the
     private-by-default half of MOMENTUM-06. Streak and shield state has no visibility surface
     beyond the user's own device this phase — no public leaderboard and no sharing of any kind,
     asserted at phase close by a structural no-sharing test. The opt-in household half is not
     built here because Household does not exist until Phase 4 (HOUSEHOLD-01) — there is nothing
     to opt into yet. Even once Phase 4 ships HOUSEHOLD-01, the accountability-contact tier
     specifically stays deferred: that is HOUSEHOLD-02, already out of scope to v2 per
     PROJECT.md. The Momentum data model carries a visibility scope from day one (D-07), so
     Phase 4 can add a household scope with no data migration.*
**Plans**: 10/10 plans complete

Plans:

- [x] 03-01-PLAN.md — Momentum domain foundations: DST-safe Monday-3am week boundary, weekly-target
  rules with D-10's endowed week-one head start, ledger value types

- [x] 03-02-PLAN.md — RECOVERY-01's sleep decision rule and the single-source Momentum/Recovery copy
  catalog with its banned-lexicon enforcement suite

- [x] 03-03-PLAN.md — The reconciliation fold: lazy, idempotent, append-only shields, milestones,
  comeback windows and guardrail precedence

- [x] 03-04-PLAN.md — Momentum SwiftData records, schema registration, and the `HealthDataStore`
  ledger facade with guard-and-throw target validation

- [x] 03-05-PLAN.md — Sleep check-in and snapshot persistence, plus `MomentumSummary` — the
  standalone reconciliation-on-read driver and the two user-initiated flag actions (D-08)

- [x] 03-06-PLAN.md — Momentum detail screen, progress/shield/milestone components, and this phase's
  first step case and aggregate registrar

- [x] 03-07-PLAN.md — Weekly-target picker in Settings and the Momentum summary section on the
  interim hub

- [x] 03-08-PLAN.md — Sleep check-in screen and RECOVERY-01's client-side lighter-plan adjustment,
  with one named test per invariant

- [x] 03-09-PLAN.md — Daily Movement Snapshot: opt-in Settings toggle and its own plain calendar
  screen, structurally free of Momentum state (MOMENTUM-07)

- [x] 03-10-PLAN.md — Phase close-out: step-coverage suite, no-sharing structural gate, MOMENTUM-06
  deferral annotation, full-target suite green

**UI hint**: yes

### Phase 4: Household & Home

**Goal**: Families spanning generations share one app and one encouraging home screen — with comparison and ranking structurally impossible, not just discouraged.
**Depends on**: Phase 3
**Requirements**: HOUSEHOLD-01, CROSSGEN-01, CROSSGEN-04
**Success Criteria** (what must be TRUE):

  1. A user's home screen is a real dashboard, identically for every age in the household — not
     a vertical list of buttons. Visible sections (not one tap deeper) include: logged
     exercise/activity, sleep check-in/logging, workout-plan recommendations, and diet-plan
     guidance.

     *Revised 2026-09-08 (see `REQUIREMENTS.md` CROSSGEN-01): supersedes this criterion's
     original "exactly 3 things by default, everything else one tap deeper" rule. Reason: user
     feedback during Phase 3 sign-off rejected the interim hub's button-list layout as not
     matching the intended product ("it should open a desktop... it should have all these many
     features"). Steps/calories tracking was also requested but has no data source wired up yet
     (no HealthKit/pedometer integration exists) — that is new data-ingestion scope, not a layout
     change, and needs its own decision before it is added to this criterion.*

  2. A user can group into a household (e.g., grandparent/parent/teen) where the only
     cross-member interaction is a fixed, non-ranked cheer ("nice work"/"keep going") — there is
     no shared leaderboard and no visible pace/weight comparison between members, structurally,
     not just by convention.

  3. For every social surface, a user picks a point on a visibility spectrum — private solo, or
     opt-in household sharing — never a binary public/private toggle, and nothing is shared by
     default until the user opts in. (The third rung, an opt-in friend-only accountability circle,
     was v2-scoped as HOUSEHOLD-02, but is now pulled into v1 — see Phase 4.1, reprioritized
     2026-09-09.)

     *Criteria 2 and 3 (HOUSEHOLD-01, CROSSGEN-04) deferred 2026-09-08 (see
     `04-CONTEXT.md`'s Phase Boundary): the first Phase 4 round ships only criterion 1's dashboard
     home screen (CROSSGEN-01), triggered directly by the same 2026-09-08 user feedback that
     revised criterion 1. Household grouping and the visibility spectrum are genuinely new
     multi-user/social scope, unrelated to the dashboard layout itself, and are picked up in a
     later Phase 4 round rather than blocking the dashboard on unrelated work.*
**Plans**: 3/3 plans complete (round 1 — criterion 1 / CROSSGEN-01 only)

Plans:

- [x] 04-01-PLAN.md — Extract the embeddable Recommendations and DIET-01-isolated diet content
  from their full-screen hosts, plus the project's first DIET-01 isolation gate (D-04/D-05)

- [x] 04-02-PLAN.md — Re-parent the Momentum summary under `Ritham/Momentum/` and rewrite
  `HomeHubView` as the sectioned dashboard (D-01/D-02/D-03/D-06/D-07)

- [x] 04-03-PLAN.md — Phase close-out: `Phase4CoverageTests` structural gates, full-suite green,
  Simulator verification checkpoint

*Round 1 scope, 2026-09-08: these three plans deliver criterion 1 (CROSSGEN-01) only. Criteria 2*
*and 3 (HOUSEHOLD-01, CROSSGEN-04) stay open per the dated annotation above and are planned in a*
*later Phase 4 round — the phase checkbox stays unticked until they ship.*

*Round 1 shipped 2026-09-08: criterion 1 (CROSSGEN-01) is complete — `04-01`-`04-03` deliver the*
*sectioned dashboard home screen with logged exercise, sleep check-in, workout-plan*
*recommendations, and diet-plan guidance all visible inline, plus `Phase4CoverageTests`'*
*structural gates and a green full-suite run. HOUSEHOLD-01 and CROSSGEN-04 (criteria 2 and 3)*
*remain open for a later Phase 4 round, per the dated annotation above — mirroring Phase 2*
*criterion 6's and Phase 3 criterion 5's existing annotation style.*
**UI hint**: yes

### Phase 04.1: Group Goal-Events & Accountability Circles (INSERTED)

**Goal:** Users can form small, invite-only friend groups (beyond household) and organize shared,
non-comparative goal-events with a group feed and a completion certificate — structurally
incapable of ranking, pace comparison, or precise-location exposure.
**Requirements**: ACCOUNT-01, HOUSEHOLD-02, GROUPEVENTS-01, GROUPEVENTS-02, GROUPEVENTS-03, GROUPEVENTS-04, GROUPEVENTS-05
**Depends on:** Phase 4 round 1 (the CROSSGEN-01 dashboard that hosts this phase's entry point —
NOT full Phase 4 closure; this phase's visibility ladder does not need HOUSEHOLD-01/CROSSGEN-04,
see criterion 1's note below)

  *Qualified 2026-09-09, per `04.1-RESEARCH.md` Open Question 2: was unqualified "Depends on:
  Phase 4," which read ambiguously as requiring Phase 4's full closure.*
**Success Criteria** (what must be TRUE):

  0. A user can create an optional, opt-in account via Sign in with Apple the first time they use
     a social feature — never mandatory, never required for core tracking (ACCOUNT-01). Signing
     in with the same Apple ID on a new device restores their friend graph, group memberships, and
     certificate archive.

  1. A user can build a friend-level accountability circle (HOUSEHOLD-02) distinct from household —
     mutual/request-based only, never one-directional follow — via contact matching (both-sides
     opt-in, off by default), an expiring invite link/QR, or in-person/direct share.

     *This phase ships a two-rung visibility ladder now (Only Me → this specific group), reserving
     an unimplemented `.household` case for HOUSEHOLD-01 to add later with no data migration —
     the same precedent `MomentumVisibility` set in Phase 3. See `04.1-CONTEXT.md`.*

  2. A user can create a small, closed, invite-only group with no public/joinable-by-anyone tier;
     any member can leave anytime with no ownership-transfer gate (GROUPEVENTS-01).

  3. A user can organize or join a Goal-Event — a shared, non-timed commitment with an activity
     type and optional target/date — where each person logs completion independently, own time is
     optional and off by default, and no ranking mechanism of any kind exists: no pooled total, no
     contribution ranking, no leaderboard, no score, no winner (GROUPEVENTS-02).

  4. Any shared photo has EXIF GPS/metadata stripped server-side unconditionally; any shared
     location defaults to a reverse-geocoded coarse place name, never coordinates/pin/address/radius;
     user-set Privacy Zones are generalized/suppressed everywhere (GROUPEVENTS-03).

  5. A group-only shared feed exists — not public, not discoverable, no generic shareable link —
     ordered chronologically, never showing pace, time-rank, "first to complete," a completion
     denominator, or precise location (GROUPEVENTS-04).

  6. On completion, a user can generate a digital certificate (Ritham branding, event name,
     participant's own name/date, own time only if opted in) that never exposes another member's
     name, photo, status, time, pace, distance, rank, or GPS/address (GROUPEVENTS-05).

     *Reprioritized 2026-09-09 (see `PROJECT.md` Key Decisions): this whole phase was previously
     v2-scoped specifically to keep Phase 5's pre-launch GDPR/CCPA privacy review narrow. The user
     explicitly chose to pull it into v1 knowing it widens that review's surface (photo/location
     data). `docs/group-events.md` is the full spec this phase plans against. Identity/account
     model (ACCOUNT-01, Sign in with Apple) absorbs Phase 999.2's backlog scope — see
     `REQUIREMENTS.md`'s "Account & Identity" section and Backlog below.*
**Plans**: 6/17 plans executed

Plans:

**Wave 1**

- [x] 04.1-01-PLAN.md — Persistence foundation: Postgres schema, `golang-migrate` setup, first real
  `go.mod` dependencies (ACCOUNT-01)

- [x] 04.1-02-PLAN.md — Domain vocabulary + single-source copy catalog in `RithamCore`
  (`GroupVisibilityScope`, `SocialCopy`) (HOUSEHOLD-02, GROUPEVENTS-01, GROUPEVENTS-02, GROUPEVENTS-04)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04.1-03-PLAN.md — Backend identity: Sign in with Apple token verification, opaque revocable
  session tokens (ACCOUNT-01)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04.1-04-PLAN.md — Server-side EXIF-strip photo pipeline (structural negative test, HEIC
  reject path) (GROUPEVENTS-03)

- [x] 04.1-05-PLAN.md — Client identity half: shared social API client, Keychain-backed sessions,
  Sign-in-with-Apple entry point (ACCOUNT-01)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 04.1-06-PLAN.md — Mutual friend graph + three closed-loop connection paths, server-side
  (HOUSEHOLD-02, GROUPEVENTS-01)

- [ ] 04.1-07-PLAN.md — Privacy Zones + the on-device capture→zone-check→geocode→discard sequence
  (GROUPEVENTS-03)

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 04.1-08-PLAN.md — Small, closed, invite-only groups + membership-scoping predicate, server-side
  (GROUPEVENTS-01, HOUSEHOLD-02)

- [ ] 04.1-09-PLAN.md — Friend-circle client surface: friends list, incoming requests, Add Friend
  screen (HOUSEHOLD-02, GROUPEVENTS-01)

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 04.1-10-PLAN.md — Goal-Events, RSVP, and completion logging — no clock, no ranking
  (GROUPEVENTS-02, GROUPEVENTS-01)

- [ ] 04.1-11-PLAN.md — Group client surface: create group, invite, view membership, remove member
  (GROUPEVENTS-01, HOUSEHOLD-02)

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 04.1-12-PLAN.md — Group-only feed, fixed cheer mechanic, export-consent gate, server-side
  (GROUPEVENTS-04, GROUPEVENTS-05)

- [ ] 04.1-13-PLAN.md — Goal-Event client surfaces (create/RSVP, separate from the completion feed)
  (GROUPEVENTS-02, GROUPEVENTS-05)

**Wave 8** *(blocked on Wave 7 completion)*

- [ ] 04.1-14-PLAN.md — Completion-logging screen: binary done + optional own-time/photo/location
  opt-ins (GROUPEVENTS-02, GROUPEVENTS-03)

**Wave 9** *(blocked on Wave 8 completion)*

- [ ] 04.1-15-PLAN.md — Group feed client surface: completion cards, every non-comparative rule
  enforced visually (GROUPEVENTS-04, GROUPEVENTS-02)

**Wave 10** *(blocked on Wave 9 completion)*

- [ ] 04.1-16-PLAN.md — Digital finisher certificate: auto-generated, server-stripped-photo-only,
  export consent + editable display name (GROUPEVENTS-05, GROUPEVENTS-03)

**Wave 11** *(blocked on Wave 10 completion)*

- [ ] 04.1-17-PLAN.md — Phase close-out: `SocialCoverageTests` structural gates (no ranking field,
  no denominator, `.household` unreachable, certificate never references the private original),
  full-suite green (ACCOUNT-01, HOUSEHOLD-02, GROUPEVENTS-01 through 05)

### Phase 5: Launch Readiness (Legal & Clinical Review)

**Goal**: Ritham is cleared to submit publicly to the App Store — every piece of clinical/legal-sensitive content has been reviewed by the right professional, and the privacy review is complete.
**Depends on**: Phase 4.1

  *Revised 2026-09-09: was "Depends on: Phase 4." Phase 4.1's group-events/photo/location data now
  widens LAUNCH-04's privacy-review surface, so the review must happen after 4.1 ships, not before.*
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
Phases execute in numeric order: 1 → 2 → 3 → 4 → 4.1 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Onboarding & Safety Intake | 14/14 | Complete    | 2026-09-03 |
| 2. Core Tracking & Adjusted Guidance | 15/16 | In Progress|  |
| 3. Momentum & Recovery | 10/10 | Complete   | 2026-09-06 |
| 4. Household & Home | 3/3 | In Progress (round 1 complete) | - |
| 4.1. Group Goal-Events & Accountability Circles | 6/17 | In Progress|  |
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

### Phase 999.2: Optional cross-device account/sync (email login) (PROMOTED 2026-09-09)

~~**Goal:** [Captured for future planning] An optional email-based login letting a user see their
own data (workout history, streaks, etc.) on a different device...~~

**Promoted 2026-09-09 into Phase 4.1** (Group Goal-Events & Accountability Circles), as
`ACCOUNT-01` in `REQUIREMENTS.md`'s "Account & Identity" section. Phase 4.1's need for mutual,
cross-device friend identity forced this decision sooner than expected — resolved as **Sign in
with Apple only**, not email+password (this backlog entry's original open question). No longer
tracked here.

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

3. ~~Friend/family event creation, invites, RSVP-by-availability, and event-completion badges~~ —
   **promoted 2026-09-09 to Phase 4.1** (Group Goal-Events & Accountability Circles), fully spec'd
   as HOUSEHOLD-02 and GROUPEVENTS-01 through 05 in `REQUIREMENTS.md`, planning against
   `docs/group-events.md`. No longer tracked here.

**Requirements:** TBD
**Plans:** 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)
