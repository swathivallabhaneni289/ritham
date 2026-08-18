# Ritham

A fitness app combining run/walk tracking, weightlifting tracking, and a single non-punishing cross-modality streak system ("Momentum") — designed to include features not found in current fitness/weightlifting apps and to appeal across all generations, from Gen Z to Baby Boomers.

This repo is currently pre-code: the project is in the feature-research and design phase. What's here so far is the research and design work that will drive implementation.

## Design docs

- [`docs/roadmap.md`](docs/roadmap.md) — the full feature roadmap: core features, novel differentiator features, cross-generational design strategy, the Momentum streak mechanic spec, and MVP/v2/moonshot prioritization. Also published as an interactive artifact: https://claude.ai/code/artifact/48e77539-1363-4beb-b69e-9bae8799b8b4
- [`docs/health-screening.md`](docs/health-screening.md) — the health-intake questionnaire and condition-based workout/nutrition personalization rules (age- and health-condition-aware suggestions, with safety gating for high-risk conditions). Also published as an interactive artifact: https://claude.ai/code/artifact/cc23b004-94e6-48e7-97de-7de55f438d84
- [`docs/weekly-timetable.md`](docs/weekly-timetable.md) — the under-18 and 65+ weekly workout + nutrition timetable design, built on top of `docs/health-screening.md`'s condition-adjustment rule tables.
- [`docs/dietary-pattern.md`](docs/dietary-pattern.md) — the vegan/vegetarian dietary-preference layer: a non-gating food-preference tag that swaps protein/food examples inside the existing nutrition rules without ever touching a clearance gate.
- [`docs/cycle-recovery.md`](docs/cycle-recovery.md) — opt-in menstrual cycle tracking (symptom-triggered, not phase-prescriptive — deliberately conservative given how contested "cycle syncing" claims are) and recovery-aware Momentum (sleep-informed intensity suggestions that never change what counts toward the streak).
- [`docs/group-events.md`](docs/group-events.md) — friends, closed groups, shared non-competitive goal-events (group 5K/hike/swim), privacy-first photo + location logging (built around the 2018 Strava heatmap lesson), a group-only feed, and a Ritham-branded finisher certificate with leak-safe external sharing.

## Status

- [x] Feature research and roadmap
- [x] Health-intake questionnaire and personalization rule design (draft — needs legal/clinical review before shipping, see the caveats in `docs/health-screening.md`)
- [x] Age-based (under-18 / 65+) weekly workout + nutrition timetable design (draft — same legal/clinical review caveat applies, see `docs/weekly-timetable.md`)
- [x] Vegan/vegetarian dietary-preference layer (draft — same legal/clinical review caveat applies, see `docs/dietary-pattern.md`)
- [x] Cycle tracking + recovery-aware Momentum design (draft — same legal/clinical review caveat applies, see `docs/cycle-recovery.md`)
- [x] Group Goal-Events social feature design (draft — needs privacy/legal review, e.g. GDPR/CCPA obligations for photo and location data, see `docs/group-events.md`)
- [ ] App implementation
