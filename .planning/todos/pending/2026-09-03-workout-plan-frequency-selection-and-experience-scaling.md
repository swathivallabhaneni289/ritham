---
created: 2026-09-03T09:37:03.813Z
title: Workout plan frequency selection and experience scaling
area: planning
files: []
---

## Problem

Phase 2 (Core Tracking & Adjusted Guidance) needs to let a user pick a target workout
frequency — 3 days/week, 5 days/week, or 7 days/week — and the generated plan needs to scale
appropriately across experience levels, from a complete beginner up to someone who already
works out every day. Captured 2026-09-03 during Phase 1 closeout, before Phase 2 has been
discussed or planned — not to be built now.

Connects directly to `ONBOARD-01`'s triggered calibration pre-assessment (provisional Phase 2
scope, see ROADMAP.md's 2026-09-01 note and PROJECT.md Key Decisions): calibration is no longer
part of onboarding, and instead resurfaces later as a pre-assessment the moment a user requests
exercise recommendations. Calibration output (walk/lift performance) plus this frequency/
experience selection together are what should drive what the personalized plan actually looks
like — surface both together when Phase 2 gets discussed/planned rather than scoping them
separately.

## Solution

TBD — raise during `/gsd-discuss-phase 2`. Open questions for that discussion: does frequency
selection happen once (a setting) or per-plan-generation; how "beginner" vs. "daily exerciser"
gets classified (self-report vs. derived from calibration); and whether this needs its own
requirement ID or folds into the existing STRENGTH-0x/CARDIO-0x requirements already listed for
Phase 2 in ROADMAP.md.
