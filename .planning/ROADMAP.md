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

- [ ] **Phase 1: Onboarding & Safety Intake** - New users complete real calibration and a fixed-choice safety screening that gates every later feature's condition-aware guidance
- [ ] **Phase 2: Core Tracking & Adjusted Guidance** - Free-forever cardio and strength tracking, with condition-tag-adjusted workout/nutrition guidance and dietary-pattern swaps
- [ ] **Phase 3: Momentum & Recovery** - A single fair, forgiving cross-modality weekly streak that adapts to sleep without ever punishing rest
- [ ] **Phase 4: Household & Home** - Cross-generational households share one app with a simple home screen and structurally non-comparative encouragement
- [ ] **Phase 5: Launch Readiness (Legal & Clinical Review)** - Clinical and legal sign-off plus a completed privacy review, clearing the app for public App Store submission

## Phase Details

### Phase 1: Onboarding & Safety Intake

**Goal**: Every new user, regardless of age or health background, completes a real calibration session and a safety screening that will safely gate personalized guidance later — without ever being funneled into a separate "senior" or "kid" experience.
**Depends on**: Nothing (first phase)
**Requirements**: ONBOARD-01, EXPLAIN-01, HEALTH-01, HEALTH-02, HEALTH-05, HEALTH-06, MINOR-01, DIET-01, CROSSGEN-03, CROSSGEN-05
**Success Criteria** (what must be TRUE):

  1. A new user's first session is a guided walk-or-light-lift calibration (never a self-reported
     fitness-level dropdown), and the result sets their starting baseline.

  2. A user chooses an explanation register once at onboarding, can change it anytime, and every
     technical term elsewhere is tap-to-expand into that register's definition.

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
     they enter their age: calibration, tracking, Momentum, and the complete safety screening
     (gate questions, condition checklist, SCOFF) — no parental consent step, no partial gate, at
     any age from 13 up.

  6. A user sets a dietary pattern (none/vegetarian/vegan) right after entering age, can edit it
     anytime in Settings, and it never changes a clearance-gate outcome.

  7. A user sees privacy/sharing explained on one screen, in plain language, before being asked to
     opt in — nothing is shared or synced with anyone by default.
**Plans**: 7/14 plans executed

Plans:

- [x] 01-01-PLAN.md — RithamCore package, toolchain-adaptive test harness, and the single-source copy catalog
- [x] 01-03-PLAN.md — Screening domain: condition tags, orderable clearance gates, fixed-choice answers, tag validity
- [x] 01-05-PLAN.md — Calibration domain: completion thresholds and baseline derivation
- [x] 01-06-PLAN.md — Gate resolution: tag derivation plus the sixteen red-flag escalation rules
- [x] 01-07-PLAN.md — Onboarding routing core, the permanent 13+ age floor, and its no-age-fork guarantee
- [x] 01-09-PLAN.md — Xcode install checkpoint, iOS app target, single shared navigation container
- [x] 01-10-PLAN.md — Design system: palette, type scale, spacing, computed band motif geometry
- [ ] 01-11-PLAN.md — SwiftData persistence with file protection (no consent gate — see D-14)
- [ ] 01-12-PLAN.md — Shared UI components and the tap-to-expand glossary
- [ ] 01-13-PLAN.md — Welcome, explanation register, age, age-ineligible block, dietary pattern, privacy explainer
- [ ] 01-15-PLAN.md — Calibration screens with pedometer and stopwatch sources
- [ ] 01-16-PLAN.md — The screening questionnaire: disclaimer, gate section, interstitials, checklist, follow-ups
- [ ] 01-17-PLAN.md — Disclaimer surfaces, health profile, Settings and re-screen
- [ ] 01-18-PLAN.md — Step bootstrap, phase coverage assertions, end-to-end human verification

*2026-08-23: four plans removed entirely (01-02 Go consent service, 01-04 consent domain, 01-08*
*consent HTTP API, 01-14 consent screens/client) after D-14 replaced tiered parental consent with a*
*permanent 13+ age floor — see `01-CONTEXT.md` D-14/D-15 and `01-DISCUSSION-LOG.md`. Original count*
*was 18 plans across 9 waves; no wave was fully emptied, so the wave count is unchanged.*
**UI hint**: yes

### Phase 2: Core Tracking & Adjusted Guidance

**Goal**: Users can log every real training session — cardio or strength — and see safety-adjusted guidance the moment it applies, forever for free.
**Depends on**: Phase 1
**Requirements**: CARDIO-01, CARDIO-02, CARDIO-03, STRENGTH-01, STRENGTH-02, STRENGTH-03, STRENGTH-04, STRENGTH-05, HEALTH-03, HEALTH-04, DIET-02, DIET-03, MONETIZE-01, CROSSGEN-02
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

  6. In Settings, a visible "always free" list confirms that GPS/manual-stopwatch tracking
     (heart-rate display when a device is paired, never required), full history, plate/1RM
     calculators, supersets, and movement-pattern tagging are never paywalled — matching what's
     actually gated (or not) elsewhere in the app.
**Plans**: TBD
**UI hint**: yes

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
| 1. Onboarding & Safety Intake | 7/14 | In Progress|  |
| 2. Core Tracking & Adjusted Guidance | 0/0 | Not started | - |
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
**Plans:** 0 plans

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
