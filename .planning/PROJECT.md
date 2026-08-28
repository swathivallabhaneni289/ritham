# Ritham

## What This Is

Ritham is a cross-generational fitness tracking app (iOS native, Swift/SwiftUI) that lets one
household — from teenagers to grandparents — track cardio and strength training in a single app,
build one forgiving weekly consistency habit ("Momentum"), and receive safety-adjusted guidance
from a lightweight health screening. Core tracking is free forever; nothing is ever gated by age,
and nothing about a user's pace, weight, or streak length is ever exposed to comparison or ranking.

## Core Value

Every user 13 or older, any health background — can safely track real training and keep a fair,
forgiving consistency streak, with core tracking always free and never subject to comparison or
ranking.

## Business Context

- **Customer**: Individual and household fitness trackers spanning teens through older adults, via
  public App Store release.
- **Revenue model**: Freemium. Core tracking (GPS/manual-stopwatch, with heart-rate display when
  a device is paired — never required, since the app is fully functional phone-only — full
  history, plate/1RM calculators, supersets, movement-pattern tagging) and all streak-forgiveness
  mechanics (shields, comeback repair, injury guardrail) are permanently free. Future paid tiers — AI-adaptive programming,
  multi-wearable fusion dashboards, human-coach marketplace, advanced data exports — are v2+,
  not in v1 scope.
- **Success metric**: Public App Store launch readiness — all v1 requirements shipped, and
  pre-launch legal/clinical review (PAR-Q+ gate-question wording, SCOFF wording/scoring,
  protein-swap dietitian sign-off, GDPR/CCPA privacy review) complete.
- **Strategy notes**: Source material ingested from `docs/roadmap.md` (PRD), `docs/cycle-recovery.md`
  (PRD), `docs/health-screening.md`, `docs/dietary-pattern.md`, `docs/group-events.md` (SPECs), and
  `docs/weekly-timetable.md` (DOC). Full synthesis at `.planning/intel/SYNTHESIS.md`.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Cross-generational onboarding with a real walk-or-light-lift calibration session, one
      consistent explanation voice with tap-to-expand definitions, and fixed-choice safety
      screening (PAR-Q-style gates + SCOFF), never a "senior mode" or age-gated fork
- [ ] A 13+ age floor: age is self-attested at onboarding with no verification beyond entry;
      entering an age under 13 shows a plain blocking message and allows re-entry with a
      different age; no minor consent flow or parental gate anywhere in the product, and a
      13-17-year-old gets identical access to a 65-year-old from the moment they enter their age
- [ ] Free-forever cardio tracking (GPS + manual stopwatch, with a visible confidence indicator)
      and strength tracking (plate calculator, supersets, movement-pattern tagging) with full
      retroactive editing
- [ ] Condition-tag-driven workout and nutrition guidance, including dietary-pattern
      (vegetarian/vegan) swaps, where required-blocking domains show a referral message instead
      of any personalized number
- [ ] A single cross-modality weekly Momentum streak with automatic shields, comeback repair, and
      a user-initiated Recovery Week — competence-framed, never threat-framed, never public
- [ ] A self-report sleep check-in that adjusts the day's suggested session without ever
      penalizing rest, a declined suggestion, or a skipped check-in
- [ ] Household accounts with non-comparative fixed-cheer encouragement, and a 3-item default
      home screen with progressive disclosure for everything else
- [ ] An explicit, in-app "always free" monetization boundary
- [ ] Pre-launch legal/clinical review (PAR-Q+ wording, SCOFF wording, dietitian sign-off,
      GDPR/CCPA privacy review) complete before public App Store submission

### Out of Scope

- Menstrual cycle tracking — deferred to v2. It's opt-in but adds special-category health data
  (consent flow, symptom logs, contraceptive-method categories) to the pre-launch privacy review
  surface; deferring keeps v1's GDPR/CCPA review scoped and v1 shippable sooner.
- Friend/group goal-events, shared feeds, digital certificates — deferred to v2. `docs/roadmap.md`
  already tiers the opt-in accountability-circle (beyond household) as v2, and `docs/group-events.md`
  is that tier's SPEC.
- Weekly rhythm timetable (editable 7-day template with Under-18/65+ baseline variants) —
  deferred to v2. v1 ships the underlying condition-tag-driven workout/nutrition guidance without
  the dedicated weekly-grid rendering; the timetable is a UX layer on top, not new safety logic.
- Wearable fusion (Oura/WHOOP/Garmin/Apple Watch) and HRV-augmented Recovery suggestions — v2;
  self-report is the v1 signal for both Momentum qualification and Recovery-aware suggestions.
- Interference-aware scheduler, pattern-detected injury guardrail, auto-calibrated onboarding
  baseline, full screen-reader accessibility audit — v2.
- Cross-user aggregate location visualization (heatmap, "most active area feature") — never
  building this, permanent product-category exclusion regardless of milestone.
- Public leaderboards of streak length, pace, or weight lifted, anywhere in the app — structural
  design commitment; visibility is always private-by-default with opt-in circles.
- Insulin-dosing or medication-adjustment suggestions, for any user, any condition-tag
  combination — standing product-wide prohibition, no exception via any clearance toggle.
- Camera-based form correction, chronic-pain-aware pacing engine, perimenopause/hormonal-transition-aware
  programming track, VR/AR training mode, full AI fusion coaching — moonshot tier, no near-term plan.

## Context

- **Target runtime**: iOS native, Swift/SwiftUI (user-specified).
- **Origin**: Requirements synthesized from a 6-document ingest batch (2 PRDs, 3 SPECs, 1 DOC) —
  no ADRs existed in the batch, so several architecture-flavored statements are captured below as
  Key Decisions and flagged as candidates for promotion to formal ADRs.
- **Screening discipline**: The health-screening flow is fixed-choice only — never free text,
  never live AI-generated advice — across all 9 condition categories, per `docs/health-screening.md`.
- **Cross-doc conflict**: One narrowing inconsistency was found and auto-resolved during ingest —
  `docs/weekly-timetable.md`'s restatement of the Momentum qualifying-session bar dropped the
  manual-stopwatch path that `docs/roadmap.md` (PRD, higher precedence) explicitly includes. Since
  the timetable feature itself is deferred to v2, this correction rides along with that deferral
  (see REQUIREMENTS.md v2 section, TIMETABLE-01).
- **Gap resolved during roadmapping**: `docs/roadmap.md`'s original MVP/v2/moonshot tiers did not
  cover cycle tracking, Recovery-aware Momentum, dietary pattern, or group goal-events (all added
  after that roadmap was written). Tier placement for each was decided during this roadmap's
  creation — see REQUIREMENTS.md for the full v1/v2 split and reasoning.

## Constraints

- **Tech stack**: iOS native, Swift/SwiftUI — user-specified target runtime.
- **Compliance**: Public App Store launch requires PAR-Q+ gate-question wording counsel review,
  SCOFF wording/scoring clinician confirmation, protein-swap-table dietitian sign-off, and a
  GDPR/CCPA privacy review covering intake health data — before public submission, not deferred
  indefinitely (tracked as LAUNCH-01 through LAUNCH-04). No COPPA review is required: Ritham has
  a permanent 13+ age floor and collects no personal information from anyone who identifies as
  under 13.
- **Data collection discipline**: The screening questionnaire must remain fixed-choice only —
  never free text, never live AI-generated advice — per `docs/health-screening.md` §1.
- **Monetization boundary**: Core GPS/manual-stopwatch tracking, full training history,
  plate/1RM calculators, supersets, movement-pattern tagging, and all streak-forgiveness
  mechanics (shields, comeback repair, injury guardrail) are permanently free — never paywalled,
  and stated visibly in-app (Settings), not just as internal policy. Heart-rate display is shown
  whenever a Bluetooth strap or wearable is paired but is never required — v1 has no continuous
  HR sensing without a paired device, so the app must be fully functional and accurate phone-only.
- **Red-flag precedence**: When 2+ condition tags apply to the same guidance, the single most
  restrictive gate always wins — never averaged, never blended, never softened.

## Key Decisions

<!-- Architecture-flavored statements found in PRD/SPEC prose during ingest (no ADRs existed in
     the source batch). Not formally locked; flagged here as candidates for promotion to ADRs. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Local-first data storage; cloud sync is backup, not source of truth | Keeps a user's training data available offline and under their control; matches `docs/roadmap.md`'s storage model | — Pending |
| Ritham will never build a cross-user aggregate location visualization (no heatmap, no "most active area" feature) | Permanent privacy commitment from `docs/group-events.md` §3; protects users even after group features ship in v2 | — Pending |
| Server-side EXIF stripping is unconditional and never relies on client-side stripping alone | Photo-metadata location/identity leaks are a hard privacy failure mode; a server-side guarantee closes gaps a client bug could open | — Pending |
| Forgiveness mechanics (shields, comeback repair, injury guardrail) are never monetized, permanently | Keeps the Momentum streak's fairness promise credible — a purchasable shield would undermine "earned, never sold" | — Pending |
| `dietary_pattern` is strictly downstream of the Clearance Gate, never part of gate-resolution logic | Prevents a dietary preference from ever loosening a safety gate (e.g., a vegan tag never overriding a kidney-disease block) | — Pending |
| Ritham has a permanent 13+ age floor; under-13 users are never supported in any form (not even a reduced-functionality tier), and there is no minor-consent flow of any kind for any age | Reverses the 2026-08-22 tiered-consent design (D-05/D-06/D-13 in `01-CONTEXT.md`) after GitHub issue #1's device-continuity request traced back to that design's COPPA/App-Store cost; matches actual industry practice — Strava, Nike, Peloton, and MyFitnessPal all set a hard age floor (13 or 18) with self-attested age and no parental-consent machinery, rather than building real under-13 support | Decided |
| Ritham has no user-chosen explanation register (plain-language vs. technical); every user gets one consistently-written voice, with the tap-to-expand glossary mechanic kept but no register choice behind it | Reverses EXPLAIN-01's original dual-register design after direct Phase 1 sign-off feedback from the product owner: users don't want to choose a "register" for how the app talks to them, and one well-written definition can serve a non-technical and a technical reader at once without a second wording track to maintain or clinically review | Decided |

---
*Last updated: 2026-08-28 — removed the user-chosen dual-register explanation layer: Ritham now
speaks in one consistent voice with no register choice in onboarding or Settings, while the
tap-to-expand glossary mechanic itself is unchanged. See Key Decisions and this phase's
product-owner sign-off report for the full reasoning.*
