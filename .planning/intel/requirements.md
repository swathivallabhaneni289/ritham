# Requirements (PRDs)

Extracted from PRD-classified docs: docs/roadmap.md (high confidence), docs/cycle-recovery.md (medium confidence).

---

## From docs/roadmap.md

### REQ-cardio-activity-tracking
- **source:** docs/roadmap.md §1 "Cardio & Activity Tracking"
- **description:** Activity-type selector (Run/Walk/Cycle/Hike/Swim/Elliptical, extensible), manual stopwatch for non-GPS sessions, GPS pace/distance/elevation/splits/grade-adjusted pace, full training history — all free at launch, permanently. Local-first storage with cloud sync as backup only. Distance/pace shown with a visible accuracy/confidence indicator rather than a silently varying number. Route/segment comparison available but no public KOM/leaderboard by default.
- **acceptance criteria:**
  - GPS/heart-rate tracking, full training history, splits, and grade-adjusted pace are never behind a paywall (ties to REQ-monetization-boundary).
  - Manually-entered sessions (stopwatch) count toward Momentum, labeled distinctly from sensor-verified sessions.
  - Distance/pace calculation surfaces a confidence indicator (e.g., "high confidence" vs. "signal was weak").
  - Segment/route comparison visibility is opt-in, no default public leaderboard.
- **scope:** cardio tracking, GPS, manual stopwatch, data storage model, distance/pace confidence, route comparison

### REQ-strength-tracking
- **source:** docs/roadmap.md §1 "Strength Tracking"
- **description:** Set logging with auto-fill of previous session's weight/reps; free plate calculator (standard barbell, EZ bar, trap bar, Smith machine, stack machines) with nearest-loadable-weight display; built-in supersets/circuits; auto-tagged movement pattern (push/pull/squat/hinge/carry) filterable in history/progress; full retroactive editing with date-picker/year-jump and session merge/split.
- **acceptance criteria:**
  - Plate calculator, supersets, and movement-pattern tagging are never paywalled.
  - Retroactive editing supports year-jump navigation and session merge/split.
- **scope:** strength tracking, set logging, plate calculator, supersets, movement-pattern tagging, retroactive editing

### REQ-momentum-streak-system
- **source:** docs/roadmap.md §4 "Streak System Design" and §1 "Streak/Consistency System"
- **description:** Single cross-modality streak ("Momentum") treating a qualifying run/walk session and a qualifying lift session as equally valid toward one shared weekly (not daily) target.
- **acceptance criteria:**
  - Cadence is weekly, default target 3 qualifying sessions/week, user-adjustable 2–5.
  - Qualifying cardio session: continuous tracked movement, minimum 10 minutes (GPS or manual stopwatch).
  - Qualifying lift session: at least 3 working sets across 2+ exercises.
  - Manually-entered sessions count but are labeled distinctly from sensor-verified sessions.
  - Shields accrue automatically (1 per 4 consecutive successful weeks, stacking up to 3), never purchasable, auto-apply the moment a week is about to be missed.
  - Grace boundary: tracked week resets Monday 3am local time, not midnight Sunday.
  - Injury/Recovery Guardrail: user-initiated "Recovery Week" flag pauses the target without breaking the streak count; never auto-triggered.
  - Comeback repair: a missed week (no guardrail, no shield) is restored via a single "Comeback Session" within 3 days, restoring streak count minus one (not zeroing).
  - Milestone rewards at 4/12/26/52 weeks, each with badge + bonus shield.
  - Endowed-progress onboarding: first Momentum week starts pre-filled to 1/3 after the first logged session, not 0/3.
  - Framing is informational/competence-based, never threat-framed ("Week 1 of your rebuilt streak," never a deleted/reset-to-zero animation).
  - Visibility is private by default; only opt-in household/accountability-contact sharing; never a public leaderboard of streak length.
  - A separate, optional Daily Movement Snapshot exists with no streak/shield/target attached.
- **scope:** streak mechanics, qualification rules, shields, grace boundary, comeback repair, milestones, visibility, Daily Movement Snapshot
- **note:** cross-checked against docs/cycle-recovery.md §3.3 invariants (REQ-recovery-aware-momentum below) — the qualifying-session bar (10 min / 3 working sets) and the "Recovery Week is user-initiated only, never auto-triggered" rule are stated identically in both docs. No divergence found.

### REQ-monetization-boundary
- **source:** docs/roadmap.md §1 "The Monetization Boundary"
- **description:** A permanent, explicit line between what is never paywalled and what can eventually be charged for.
- **acceptance criteria:**
  - Never paywalled: core GPS/heart-rate tracking, full training history, plate/1RM calculators, superset support, movement-pattern tagging, all streak-forgiveness mechanics (shields, comeback repair, injury guardrail).
  - Fair to charge for: AI-generated adaptive programming, multi-wearable fusion dashboards, human-coach marketplace, advanced data exports.
  - The "always free" list must be stated visibly in-app (e.g., in Settings), not just as an internal policy.
- **scope:** monetization, pricing tiers, free-forever feature list

### REQ-cross-generational-design
- **source:** docs/roadmap.md §3 "Cross-Generational Design Strategy"
- **description:** One data model, one set of screens, one app across Gen Z–Boomer users via progressive disclosure, not mode-switching.
- **acceptance criteria:**
  - Home screen shows exactly 3 things by default: today's target, current streak, last session summary; everything else is one tap deeper.
  - Passive-first capture (auto-detect walk/run from motion sensors) with full manual configuration available for power users.
  - Privacy is opt-in and explained before requested, one screen, plain language; nothing shared/synced by default.
  - Visibility spectrum (not binary) per social surface: household circle, opt-in friend-only accountability circle, or fully private solo use.
  - Dual-register explanation layer applies across all screens (ties to REQ-dual-register-explanation).
  - Human-in-the-loop option: user can designate a real trainer/coach/family member as accountability contact instead of/alongside algorithmic nudges.
  - No paywall on anything in the Core Features section (restated from REQ-monetization-boundary).
  - No age gating anywhere in the product; no screen ever labeled "senior mode."
- **scope:** cross-generational UX, progressive disclosure, accessibility, privacy defaults, visibility spectrum

### REQ-household-accounts
- **source:** docs/roadmap.md §2 Feature 5 "Household accounts with non-comparative encouragement"
- **description:** Household grouping (e.g., grandparent/parent/teenager under one plan) with the only cross-member interaction being a fixed, non-ranked cheer set ("nice work"/"keep going") — no shared leaderboard, no visible pace/weight comparison.
- **acceptance criteria (MVP scope, per §5 Prioritization):** basic version ships in MVP — household grouping and fixed-cheer reactions only. Opt-in accountability-circle tier (beyond household, friend-only, Apple-Fitness-Competitions-style, never public) is v2.
- **scope:** household accounts, non-comparative social encouragement
- **note:** overlaps conceptually with docs/group-events.md's friends/groups model (SPEC) — see constraints.md. No contradiction found; group-events.md's "visibility ladder" (Only Me → Household → this specific group, no rung above) is consistent with roadmap.md's household + opt-in accountability-circle description.

### REQ-dual-register-explanation
- **source:** docs/roadmap.md §2 Feature 6
- **description:** Every technical term (1RM, HRV, grade-adjusted pace) is tap-to-expand into a plain-language or technical definition, based on a register the user picks once at onboarding and can change anytime.
- **acceptance criteria:** register is user-selected, not inferred from age; not a separate "senior mode."
- **scope:** onboarding, accessibility, copy/explanation layer
- **priority:** MVP (chosen at onboarding, per §5)

### REQ-interference-aware-scheduler
- **source:** docs/roadmap.md §2 Feature 2
- **description:** After a logged heavy leg day, flag the next day's planned run with a lighter-intensity suggestion and a one-line reason.
- **priority:** v2 (requires logged history across both modalities)
- **scope:** cross-modality scheduling suggestion

### REQ-injury-aware-auto-freeze
- **source:** docs/roadmap.md §2 Feature 3
- **description:** Streak freeze can trigger automatically off a self-reported pain/injury flag (MVP) or a detected performance-drop pattern, e.g. pace slowing at consistent effort (v2, still transparent/user-confirmed, never silently auto-triggered).
- **priority:** MVP (self-reported flag version); v2 (pattern-detected version)
- **scope:** injury-aware streak protection

### REQ-shields-earned-never-sold
- **source:** docs/roadmap.md §2 Feature 4
- **description:** Shields accrue automatically from consistency and can never be purchased.
- **priority:** MVP
- **scope:** streak forgiveness mechanics (duplicate detail also captured under REQ-momentum-streak-system)

### REQ-wearable-fusion
- **source:** docs/roadmap.md §2 Feature 7
- **description:** Device-agnostic wearable fusion — v2 target is ingesting Oura, WHOOP, Garmin, and Apple Watch simultaneously into one training-load view, no vendor lock-in.
- **priority:** v2
- **scope:** wearable integration
- **note:** cross-referenced by docs/cycle-recovery.md §3.1 ("v2 — wearable HRV/sleep-stage data, per Ritham's existing wearable-fusion roadmap item"). Consistent — cycle-recovery.md treats wearable data as augmenting, never replacing, self-report.

### REQ-first-session-onboarding
- **source:** docs/roadmap.md §2 Feature 8
- **description:** Session one is a short, guided walk-or-light-lift calibration (not a self-reported fitness-level dropdown) that sets the user's actual starting baseline.
- **priority:** MVP concept; v2 = auto-calibrated first-session baseline formally replacing self-reported fitness level at onboarding
- **scope:** onboarding, baseline calibration

### REQ-prioritization
- **source:** docs/roadmap.md §5 "Prioritization"
- **description:** MVP / v2 / Moonshot tiers for all features above.
- **acceptance criteria:**
  - MVP: full core cardio + strength tracking, complete Momentum streak system, cross-modality design (Feature 1), self-reported injury-aware auto-freeze (Feature 3) + earned shields (Feature 4), basic household accounts (Feature 5), dual-register layer (Feature 6, chosen at onboarding), cross-generational baseline (§3), full Monetization Boundary stated in-app.
  - v2: interference-aware scheduler (Feature 2), wearable fusion (Feature 7), auto-calibrated onboarding baseline (Feature 8), opt-in accountability-circle visibility tier, human-in-the-loop coach connection, pattern-detected injury guardrail, accessibility hardening (full screen-reader audit).
  - Moonshot: camera-based form correction, chronic-pain-aware pacing engine, perimenopause/hormonal-transition-aware programming track, VR/AR training mode, full AI fusion coaching.
- **scope:** release sequencing
- **note:** docs/cycle-recovery.md, docs/dietary-pattern.md, and docs/group-events.md (cycle tracking, Recovery-aware Momentum, dietary pattern preference, and group goal-events) are NOT assigned an MVP/v2/moonshot tier anywhere in docs/roadmap.md. This is a gap, not a contradiction — roadmap.md predates or was not updated to include these three later feature docs. Flagged here for `gsd-roadmapper` to resolve tier placement; not a conflict-engine BLOCKER/WARNING since no competing tier assignment exists to conflict with.

---

## From docs/cycle-recovery.md

### REQ-cycle-tracking
- **source:** docs/cycle-recovery.md §1
- **description:** Opt-in menstrual cycle tracking as an adaptive-suggestion layer, never a condition, never gated, never part of mandatory health intake.
- **acceptance criteria:**
  - Never presented at mandatory health intake; Settings-page opt-in only, off by default.
  - Enabling shows a consent screen (what's logged, that it drives suggestions only, that it defers to Pregnancy/Postpartum tags).
  - Carries no clearance gate at any tier.
  - Disabling asks whether to retain or delete logged cycle history.
  - Logs: period start dates (primary), optional average cycle length, optional daily symptom tags (the actual suggestion-adjustment trigger, not the phase label), optional contraceptive method category.
  - Phase estimate (menstrual/follicular/ovulatory/luteal) is presented as low-confidence, context-only — never asserted as fact, never used as the suggestion trigger (only logged symptoms trigger adjustments).
  - Confidence downgraded (and UI says so) for irregular cycle-to-cycle length, combined hormonal contraceptive use, or progestin-only pill/implant use; hormonal IUD use retains standard calendar-estimation confidence.
  - Cycles <21 or >35 days, or absent bleeding, trigger a purely educational note (not a gate, not tied to the condition-checklist system).
  - **Hard rule:** if a Pregnancy or Postpartum condition tag is added while cycle tracking is ON, cycle tracking auto-disables immediately (one-time notice shown); re-enabling after tag removal always requires a fresh explicit opt-in, never automatic.
- **scope:** cycle tracking, phase estimation, symptom logging, contraceptive-method confidence adjustment, Pregnancy/Postpartum interaction rule
- **cross_ref:** explicitly composes with, but never duplicates or overrides, the Pregnancy/Postpartum Condition Tags defined in docs/health-screening.md (SPEC) — see constraints.md.

### REQ-recovery-aware-momentum
- **source:** docs/cycle-recovery.md §3
- **description:** Sleep-input-driven adjustment of the day's suggested session (technique-light/lower-intensity vs. original plan), MVP self-report, v2 wearable HRV/sleep-stage augmentation.
- **acceptance criteria:**
  - MVP: daily self-report prompt (Great/OK/Poor + optional note) is the primary signal.
  - v2: wearable HRV/sleep-stage data augments but never replaces self-report; a single isolated HRV reading never drives the day's suggestion alone.
  - Poor-sleep signal shifts the suggested session toward technique-light/lower-velocity/lower-force/moderate-intensity work.
  - A single poor night is never presented as injury-risk messaging (that's reserved for chronic patterns, surfaced only as an educational note, never a gate).
  - **Invariants (must-hold, non-negotiable per the doc):**
    1. Qualification bar unchanged — sleep input never modifies the 10-minute/3-working-set bar.
    2. A lighter suggested session that meets the bar is a fully qualifying Momentum session, identical streak effect to any other qualifying session.
    3. Declining the lighter suggestion and doing the harder original session is always available and fully qualifies.
    4. Skipping the sleep check-in has zero effect — never a penalty, never an assumed "bad" state.
    5. The feature never auto-consumes a shield and never auto-triggers a Recovery Week (Recovery Week stays user-initiated).
    6. The weekly cadence target (default 3/week) is untouched; the feature cannot mark a day non-qualifying that would otherwise qualify.
    7. No penalty/asterisk/badge/messaging differentiates training harder than suggested vs. accepting the lighter option.
  - Composition with Cycle Tracking: if both features would suggest an adjustment the same day, they compose into a single most-conservative suggestion; neither ever gates the session.
- **scope:** sleep-based suggestion adjustment, wearable HRV fusion (v2), streak-neutrality invariants
- **note:** every invariant here is corroborated, not contradicted, by docs/roadmap.md §4's Momentum mechanic (qualifying session definition, shields, Recovery Week guardrail). Treated as one coherent requirement set across both PRDs, no competing-variant flag needed.
