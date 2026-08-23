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
**Requirements**: ONBOARD-01, EXPLAIN-01, HEALTH-01, HEALTH-02, HEALTH-05, HEALTH-06, MINOR-01, MINOR-02, DIET-01, CROSSGEN-03, CROSSGEN-05
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
  5. A user under 13 cannot use the app at all until a parent/guardian completes a verifiable
     consent step; a user aged 13–17 completes calibration, the explanation-register choice, and
     dietary pattern with zero parental involvement, and only the rest of the screening (gate
     questions, condition checklist, SCOFF) waits on a parent's approval — never the app as a
     whole. A user 18 or older is never gated.
  6. A user sets a dietary pattern (none/vegetarian/vegan) right after entering age, can edit it
     anytime in Settings, and it never changes a clearance-gate outcome.
  7. A user sees privacy/sharing explained on one screen, in plain language, before being asked to
     opt in — nothing is shared or synced with anyone by default.
**Plans**: 18 plans across 9 waves

Plans:
- [ ] 01-01-PLAN.md — RithamCore package, toolchain-adaptive test harness, and the single-source copy catalog
- [ ] 01-02-PLAN.md — Go consent service: crypto tokens, four-state consent machine, pluggable email sender
- [ ] 01-03-PLAN.md — Screening domain: condition tags, orderable clearance gates, fixed-choice answers, tag validity
- [ ] 01-04-PLAN.md — Consent domain: age-to-tier resolution, consent state machine, capability matrix
- [ ] 01-05-PLAN.md — Calibration domain: completion thresholds and baseline derivation
- [ ] 01-06-PLAN.md — Gate resolution: tag derivation plus the sixteen red-flag escalation rules
- [ ] 01-07-PLAN.md — Onboarding routing core and its no-age-fork guarantee
- [ ] 01-08-PLAN.md — Consent HTTP API, delayed second confirmation email, Apple association file
- [ ] 01-09-PLAN.md — Xcode install checkpoint, iOS app target, single shared navigation container
- [ ] 01-10-PLAN.md — Design system: palette, type scale, spacing, computed band motif geometry
- [ ] 01-11-PLAN.md — SwiftData persistence with file protection and the data-layer consent gate
- [ ] 01-12-PLAN.md — Shared UI components and the tap-to-expand glossary
- [ ] 01-13-PLAN.md — Welcome, explanation register, age, dietary pattern, privacy explainer
- [ ] 01-14-PLAN.md — Consent screens and the consent service client
- [ ] 01-15-PLAN.md — Calibration screens with pedometer and stopwatch sources
- [ ] 01-16-PLAN.md — The screening questionnaire: disclaimer, gate section, interstitials, checklist, follow-ups
- [ ] 01-17-PLAN.md — Disclaimer surfaces, health profile, Settings and re-screen
- [ ] 01-18-PLAN.md — Universal links, phase coverage assertions, end-to-end human verification
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
**Requirements**: LAUNCH-01, LAUNCH-02, LAUNCH-03, LAUNCH-04, LAUNCH-05
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
  5. A completed COPPA compliance review confirms the Under-13 verifiable-parental-consent method
     meets FTC-approved standards, with required parental disclosures in place, before public
     submission.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Onboarding & Safety Intake | 0/18 | Planned | - |
| 2. Core Tracking & Adjusted Guidance | 0/0 | Not started | - |
| 3. Momentum & Recovery | 0/0 | Not started | - |
| 4. Household & Home | 0/0 | Not started | - |
| 5. Launch Readiness (Legal & Clinical Review) | 0/0 | Not started | - |
