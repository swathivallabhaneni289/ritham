# Ritham Feature Roadmap

Ritham combines run/walk tracking, weightlifting tracking, and a consistency system in one app, designed against two constraints the research makes unavoidable: (1) every major competitor eventually monetizes trust away from its users, and (2) streak mechanics that work for a 5-minute language lesson can get someone hurt when the tracked behavior is a run or a heavy squat. Every section below is written against those two constraints, not around them.

Published as an interactive artifact: https://claude.ai/code/artifact/48e77539-1363-4beb-b69e-9bae8799b8b4

---

## 1. Core Features (Table Stakes)

### Run/Walk Tracking

| Element | Ritham's approach | Why |
|---|---|---|
| GPS pace/distance/elevation/splits, grade-adjusted pace, full training history | Free at launch, permanently | Strava moved Year in Sport and API access behind paywalls in 2025–2026; Runkeeper gates its Goal Coach and training plans. The single most-repeated complaint across the cardio dossier is monetization creep on previously-free basics — Ritham doesn't create that resentment in the first place. |
| Data storage model | Local-first, with background cloud sync as backup, not source of truth | Nike Run Club (forced sign-outs, lost watch→phone syncs), Runkeeper (post-update history loss), and Jefit (bogus 70+ hour sessions from failed cloud sync) all lose user data at the sync layer. Local-first means a bad network day can't erase a workout. |
| Distance/pace calculation | One consistent, smoothed GPS algorithm with a visible accuracy indicator (e.g., "high confidence" vs. "signal was weak") rather than a silently varying number | Adidas Running shows up to 0.4-mile variance on identical routes; Nike Run Club has reported 15–20% overcounting after updates. Surfacing confidence instead of hiding variance turns a trust problem into a transparent one. |
| Route/segment comparison | Available, but no public KOM/leaderboard by default — visibility is opt-in per Section 3 | Strava's segment-chasing culture is directly linked in reviews to "dopamine-seeking" comparison behavior and users quitting over it. |

### Strength Tracking

| Element | Ritham's approach | Why |
|---|---|---|
| Set logging | Auto-fills the previous session's weight/reps per exercise, editable inline | This is Strong's best-reviewed mechanic — keep it, and don't gate it. |
| Plate calculator | Free, day one. Supports standard barbell, EZ bar, trap bar, Smith machine, and stack machines; shows nearest loadable weight when an exact target isn't achievable | Strong gates its calculator behind paid tier and doesn't support specialty bars; Fitbod's version (broad bar/machine coverage) is the better model — Ritham adopts Fitbod's coverage without Fitbod's price. |
| Supersets/circuits | Built into the base logging flow — tap "add to superset" on any two consecutive exercises, no separate creation step | Strong paywalls supersets entirely; Fitbod's superset builder is called out for drag errors and forcing "create new" instead of rename/save. |
| Exercise organization | Every exercise auto-tagged by movement pattern (push / pull / squat / hinge / carry), filterable in history and progress charts | Named directly as a gap in Strong's own reviews — users can't currently see "how much have I pulled this month" across exercise-name variants. |
| Retroactive editing | Full date-picker with year jump; can merge or split sessions after the fact | Fixes two named, specific complaints: Strong's limited retroactive editing and Hevy's missing year-dropdown when editing an old workout date. |

### Streak/Consistency System

A single, cross-modality streak ("Momentum") that treats a qualifying run/walk session and a qualifying lift session as equally valid toward one shared weekly target, rather than Strava's running-only weekly-upload streak or Strong's total absence of one. The full mechanic — cadence, qualification rules, forgiveness, and framing — is specified in Section 4, because getting this wrong is the fastest way to reproduce Habitica's "punished during my most productive week" failure mode or the Snapchat "streak-snap" empty-content problem.

### The Monetization Boundary

Because paywall creep is the single most cross-app-replicated complaint in this research (Strava, Runkeeper, Adidas Running, Strong, StrongLifts all named specifically), Ritham draws one explicit, permanent line:

**Never behind a paywall, ever:** core GPS/heart-rate tracking, full training history, the plate and 1RM calculators, superset support, movement-pattern tagging, and every streak-forgiveness mechanic (shields, comeback repair, the injury guardrail). Forgiveness mechanics specifically are never monetized — this is the direct fix for the tension identified in Duolingo's own system, where the tool that relieves streak anxiety (Auto Streak Repair) is partly gated behind a subscription.

**Fair to eventually charge for:** AI-generated adaptive programming, multi-wearable fusion dashboards, a human-coach marketplace, and advanced data exports. The dividing line is "does this feature exist to keep a user's data and consistency intact" (free, always) vs. "does this feature add new capability on top of an already-complete core" (can be paid).

---

## 2. Novel Differentiator Features

Each entry below passed a specific test: does an existing app in the research already ship this? Where a close analog exists, it's named along with the one-clause difference that makes Ritham's version distinct.

1. **Momentum — one streak, two modalities.** Closest analog: Strava's weekly-upload streak (running only) and Runkeeper's Streak Calendar (also single-modality). Ritham's streak accepts either a qualifying run/walk *or* a qualifying lift session toward the same weekly target, with the qualification rules published and visible to the user — ending the "juggle two apps, two separate consistency systems" pattern the hybrid-training research names as the biggest cross-app gap.

2. **Interference-aware weekly scheduler.** Closest analog: Edge, a niche app that programs strength and cardio as one interconnected system. No mainstream app (Strava, Peloton, Strong) does this — after a logged heavy leg day, Ritham flags the next day's planned run with a lighter-intensity suggestion and a one-line reason ("yesterday was heavy squats — here's an easier pace range today"), rather than treating the two logs as unrelated data streams the user has to reconcile themselves.

3. **Injury-aware auto-freeze.** Closest analog: Duolingo's streak freeze, which is a manually-spent or purchased buffer against *any* missed day. Ritham's freeze can also trigger automatically off a self-reported pain/injury flag or a detected performance-drop pattern (e.g., pace slowing at consistent effort), directly targeting the failure mode a run-streaking study documented: runners continuing to train through injury, and some doctor-shopping for permission to keep a streak alive, specifically to avoid losing the count.

4. **Shields that are earned, never sold.** Closest analog: Duolingo's streak freeze economy, where the strongest protection (Auto Streak Repair) sits behind the paid Super Duolingo tier. Ritham's shields accrue automatically from consistency (see Section 4) and can never be purchased — removing the specific tension the psychology research flags, where the system causing loss-aversion stress and the system relieving it aren't fully separable from revenue.

5. **Household accounts with non-comparative encouragement.** Closest analog: Apple Fitness's Activity Sharing circle and Peloton's "Here Now" — both are friend-tier and stats-forward. A Ritham household groups a grandparent, a parent, and a teenager under one plan where the only cross-member interaction is a fixed set of non-ranked cheers ("nice work" / "keep going") — no shared leaderboard, no visible comparison of pace or weight lifted, because the generational research shows Boomers value family connection but not being measured against a 16-year-old's mile split.

6. **Dual-register explanation layer.** No app in the research does this — SilverSneakers and the UX-for-seniors literature address layout (font size, contrast) but not adaptive copy. Every technical term (1RM, HRV, grade-adjusted pace) is tap-to-expand into either a plain-language explanation or the technical definition, based on a register the user picks once at onboarding and can change anytime — not inferred from age, and not a separate "senior mode."

7. **Device-agnostic wearable fusion.** Closest analog: SensAI and similar apps that ingest one or two wearable ecosystems (usually Oura- or WHOOP-first). The emerging-trends research names true cross-device fusion without vendor lock-in as still unsolved; Ritham's v2 target is ingesting Oura, WHOOP, Garmin, and Apple Watch simultaneously into one training-load view, so a user isn't forced to pick a "winner" ecosystem to get recovery-informed programming.

8. **A first session that can't be failed.** No app in the research solves this well — the beginner-onboarding research found 73% of 50 analyzed apps fail beginners, most commonly via no fitness assessment and mislabeled "beginner" content. Session one in Ritham is a short, guided walk-or-light-lift calibration (not a self-reported fitness-level dropdown) that sets the user's actual starting baseline, so the first thing a brand-new user does is complete something rather than guess at a number that mislabels their program from day one.

---

## 3. Cross-Generational Design Strategy

**Stated principle:** one data model, one set of screens, one app — appeal across Gen Z through Boomers comes from **progressive disclosure**, not mode-switching into four different experiences. Defaults are tuned for the least tech-confident user in the room; power features are *additive* on top of that default, never hidden behind a separate "advanced" app. Accessibility (text scaling, contrast, labeled icons, screen-reader support) is the base layer everyone gets, not an accommodation toggled on. There is no age gating anywhere in the product and no screen is ever labeled "senior mode" — users self-select complexity, generation never selects it for them.

Concrete implementation:

- **Home screen shows exactly three things by default:** today's target, current streak, and last session summary. Everything else (trend charts, volume graphs, movement-pattern breakdowns) is one tap deeper, not absent — this satisfies the "uncluttered, single-task screen" requirement the senior-UX research names as a hard requirement for Boomers, while Millennials who want the deep data (66% want stored history, 85% want heart-rate metrics per the generational research) reach it in one tap, not zero.
- **Passive-first capture, manual-rich for those who want it.** A walk or run can auto-detect and start logging from phone motion sensors with no tap required — Boomers specifically favor automatic/passive tracking over apps requiring manual entry, and manual nutrition-style logging is the single biggest drop-off point for older users. Power users can still start a session manually with full metric configuration (splits, cadence targets, custom intervals).
- **Privacy is opt-in and explained before it's requested**, one screen, plain language: what's being asked for, and the specific benefit it unlocks. Gen X is the most privacy-concerned cohort in the research (30% of non-adopters cite privacy) and trusts slowly but stays once trust is earned — nothing is shared or synced by default.
- **A visibility spectrum, not a binary.** Every social surface — household circle (Feature 5), an opt-in small accountability circle modeled loosely on Apple Fitness Competitions (friend-only, not public), or fully private/Strong-style solo use — is a per-feature choice the user makes, never a default. This directly avoids reproducing Strava's public-comparison stress (named repeatedly as a reason longtime users quit) while still giving Gen Z the community layer they rate as core to fitness identity (58% per the generational research).
- **The dual-register copy layer (Feature 6)** does real cross-generational work here: it's how the same screens serve Gen X's stated preference for credible, jargon-explained content and Boomers' need for plain language without ever forking the UI.
- **A human-in-the-loop option**, not just an AI layer: a user can designate a real trainer, coach, or family member as their accountability contact for the Momentum streak instead of (or alongside) the algorithmic nudges. This answers two generations at once — Gen Z's stated want for support that "feels personal rather than automated," and Gen X/Boomers' documented preference for human-backed advice over screen-first content.
- **No paywall on anything in Section 1** (restated from the Monetization Boundary) — this is itself a cross-generational design choice, since cost is a named barrier specifically for Gen X (39% of non-adopters) and compounds for fixed-income Boomers.

---

## 4. Streak System Design

**The tension, stated plainly:** an anti-gaming streak needs a meaningful bar to clear, so it can't be satisfied the way Snapchat "streak-snaps" or GitHub's midnight empty-commit farming satisfy a proxy metric without doing the underlying thing. But a *high, punishing, daily* bar is exactly what the run-streaking research (n=21, streak lengths 100–4,500+ days) found pushes people to train through injury and, in some cases, doctor-shop for permission to keep running instead of resting. Duolingo can afford a hard daily bar because a missed day of language practice costs nothing physically; Ritham cannot use the same design, because a missed day of a heavy squat session is a completely different risk profile.

**The resolution Ritham uses:** put the anti-gaming logic in *what counts as a session* (a real, specific, published qualification bar), and put all the forgiveness in *cadence and recovery mechanics* (a weekly, not daily, target; a low per-session floor; free shields; an explicit injury guardrail). Rigor and compassion don't have to fight over the same lever if they're assigned to different ones.

### Momentum — the mechanic

- **Cadence:** weekly, not daily. Default target is 3 qualifying sessions per week (user-adjustable, 2–5), because the research is explicit that daily cadence is only defensible for actions completable on a bad day — exercise, especially anything carrying injury risk, should not be.
- **Qualifying session (published, transparent, not hidden fraud-detection):**
  - Run/Walk: continuous GPS-tracked movement, minimum 10 minutes.
  - Lift: a completed session logging at least 3 working sets across 2 or more exercises.
  - Manually-entered sessions (no GPS/sensor data) still count, but are labeled distinctly from sensor-verified ones in the history view — this preserves trust and transparency without turning the app into a surveillance layer that cross-checks the user, which would directly contradict the privacy-first stance in Section 3.
- **Shields (earned, never purchased):** one shield accrues automatically for every 4 consecutive successful weeks, stacking up to 3. A shield auto-applies the moment a week is about to be missed — no purchase, no currency, no subscription gate. This is a direct fix for the tension the research flags in Duolingo's own system, where the strongest anti-anxiety mechanic is partly monetized.
- **Grace boundary:** the tracked week resets Monday at 3am local time, not midnight Sunday, to absorb travel, time-zone shifts, and late/irregular schedules without a false break.
- **Injury/Recovery Guardrail:** a user can flag a "Recovery Week" (injury, illness, travel, major life event) that pauses the target without breaking the streak count. This is the mechanic most directly informed by the run-streaking research's central finding — it gives an explicit, built-in permission structure to stop, so a user never has to choose between the physical signal to rest and the psychological cost of losing months of progress. It's also the direct antidote to Habitica's documented failure mode (Diefenbach & Müssig, 2019): a gamified system that punishes users precisely during the real-world weeks they're least able to check boxes, even when — especially when — those are weeks the app's own goal (health) is already being served by rest.
- **Comeback repair:** if a week is missed outright (no guardrail flag, no shield available), a single "Comeback Session" completed within 3 days restores the streak count minus one, rather than zeroing it. This implements BJ Fogg's "never miss twice" principle directly: one miss is recoverable by design, not a cliff.
- **Milestone rewards, non-linear:** meaningful markers at 4, 12, 26, and 52 weeks, each unlocking a badge plus a bonus shield — mirroring the escalating-reward curve behind Duolingo's 7/30/100/365-day Streak Society tiers, which the psychology research notes sustains engagement better than an identical flat reward every week (variable/escalating reinforcement resists extinction better than fixed).
- **Endowed-progress onboarding:** a brand-new user's first Momentum week starts pre-filled to 1/3 after their very first logged session, not 0/3 — a direct, deliberate application of the Nunes & Dreze (2006) car-wash field experiment, where a card seeded with a head start produced 34% completion versus 19% from a blank start, despite identical remaining effort.
- **Framing is informational, not controlling (SDT-consistent):** milestone copy reads "You've built a real 12-week habit" rather than "Don't lose your streak!"; a broken streak is shown as "Week 1 of your rebuilt streak," never as a deleted number or a reset-to-zero animation. This follows the research's clearest actionable finding on Self-Determination Theory — mechanics framed as feedback on competence sustain intrinsic motivation, while threat-framed mechanics (which is where streaks sit by default) actively undermine it.
- **Visibility is private by default.** Momentum is visible to the user and, only if explicitly opted in, their household circle or accountability contact (Section 3) — never a public leaderboard of streak length. This avoids manufacturing the social-obligation pressure documented in Snapchat streaks (breaking a streak read as a personal snub) and the "streak snap" goal-displacement pattern (empty content sent purely to survive the clock) — Ritham's streak has no second party to perform for.
- **A separate, optional Daily Movement Snapshot** exists for users who want a daily log without gamified stakes — a plain calendar of activity with no streak, no shield, no target attached. This decouples "I like tracking every day" from "I need a consistency game," which the research treats as two different user needs that current apps conflate.

---

## 5. Prioritization

### MVP (v1)

- Full Section 1 core: run/walk tracking, strength tracking (auto-fill, free plate calculator, free supersets, movement-pattern tagging, retroactive editing), and the complete Momentum streak system from Section 4 (cadence, qualification rules, shields, grace boundary, comeback repair, milestone rewards, private-by-default visibility) — this is table stakes per the task brief, not a stretch feature.
- Feature 1 (Momentum's cross-modality design) — inseparable from the streak system itself, ships with it.
- Feature 3 (injury-aware auto-freeze, self-reported flag version) and Feature 4 (earned shields) — both are core to Momentum, not separable add-ons.
- Feature 5 (household accounts, non-comparative encouragement) — basic version: household grouping and fixed-cheer reactions only.
- Feature 6 (dual-register explanation layer) — chosen at onboarding.
- Cross-generational baseline from Section 3: progressive-disclosure home screen, passive-first capture, accessibility as base layer, opt-in privacy screen, the full visibility spectrum, no paywall anywhere in Section 1.
- The full Monetization Boundary, stated in-app (e.g., a visible "always free" list in settings), not just a policy.

### v2

- Feature 2: interference-aware weekly scheduler (requires enough logged history across both modalities to be useful — a natural v2 dependency on v1's data).
- Feature 7: device-agnostic wearable fusion (Oura, WHOOP, Garmin, Apple Watch ingested simultaneously).
- Feature 8: auto-calibrated first-session baseline, replacing self-reported fitness level at onboarding.
- The opt-in accountability-circle tier of the visibility spectrum (beyond household) — small, friend-only, Apple-Fitness-Competitions-style, never public.
- The human-in-the-loop coach/trainer connection option.
- Injury guardrail upgraded from self-flagged only to pattern-detected (e.g., consistent pace decline at matched effort), still transparent and user-confirmed, never silently auto-triggered.
- Accessibility hardening: full screen-reader audit and assistive-device compatibility pass, closing the gap the disability-fitness research names as still inconsistent industry-wide.

### Moonshot

- Multi-angle, low-light-tolerant camera form correction that goes beyond current pose-estimation limits (squat depth, knee valgus, rounded back under real gym lighting, not a demo studio) — no app in the research has solved this yet.
- A chronic-pain-aware pacing engine built into the mainstream app itself (adjusting volume/intensity around flare-ups) rather than funneling those users out to a separate clinical platform like Sword Health or Hinge Health, closing the specific gap the emerging-trends research names.
- A perimenopause/hormonal-transition-aware programming track (energy, joint sensitivity, symptom tracking tied to training load) — named repeatedly as underserved even by 2025–2026 new entrants.
- A VR/AR training mode that solves the motion-sickness barrier (currently affecting up to 80% of users) well enough for mainstream, not enthusiast-only, adoption.
- Full AI fusion coaching that combines recovery data, strength progression, cardio load, and the Momentum streak into one adaptive program — deliberately last, because the research is consistent that AI-advisor layers (Oura Advisor, WHOOP AI Coach, Peloton IQ) are still unvalidated engagement features, not proven health tools, and Ritham's differentiation case rests on the mechanics above working well without needing an unproven AI layer to be worth using.
