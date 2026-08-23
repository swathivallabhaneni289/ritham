# Sketch Manifest

## Design Direction
Ritham's app-wide visual theme, explored before Phase 1 (Onboarding & Safety Intake) UI work.
Requirements from the user: clean but not flat/plain/boring, visually interesting without being
busy or clumsy, cross-generational (teens through grandparents — not childish, not clinical), and
must complement Momo, the semi-realistic painted cat mascot (see `docs/mascot.md`). Grounded in a
design-research pass comparing Calm/Headspace, Apple Fitness+/Health, and AllTrails/Strava before
any HTML was built, rather than starting from taste alone.

## Reference Points

**Round 1 (rejected)** — Calm/Headspace, Apple Fitness+/Health, AllTrails/Strava. All
wellness/outdoor-coded; none actually "energetic fitness app" coded. Result: felt basic, one
variant read as Duolingo, none read as a fitness app. Full writeup in
[001's README](001-app-theme-direction/README.md#outcome-rejected).

**Round 2** — Nike Training Club, WHOOP, Peloton (athletic/premium visual language) +
current 2026 mobile UI trends + Apple's Liquid Glass material system. Hard rule carried forward:
the accent is a signal (CTA/live-data/progress), never a decorative wash; no `ui-rounded`
numerals; no ring/badge/bloom-shaped progress indicator (round 1's arc/dots/bloom were all
reward-token/toy patterns). Orange itself was later dropped as the accent per direct feedback —
sketch 002 now ships a live Blue/Red/Violet accent picker; Momo keeps his own ginger coat
independent of whichever accent is chosen.

**Round 3 — WINNER** — user supplied their own exact composition: a diagonal-band motion graphic
(charcoal `#0E100D` / coral `#FF5C39` / acid lime `#C6F24E` / off-white `#F5F3EC`, steep ~57° bands,
halftone/arcs/ring-dot secondary texture) with a full SVG technical spec. Sketch 003 was a direct,
precise build to that spec, checked for brand/trademark collision (none found — reads as generic
2025–2026 trend language: neo-brutalism + halftone revival + Acid Graphics), and confirmed by the
user as Ritham's visual direction with the default palette.

## Decision

**Ritham's app-wide visual theme is the sketch 003 band-motif system, default palette.** Rounds 1
and 2 are kept as record of what was tried and rejected/superseded, not live options. Two design
decisions carried forward into UI-spec/implementation, not yet resolved:
- Ring-and-dot motif's Apple Activity Rings association — differentiate deliberately or lean in.
- Momo's placement/style against this specific background hasn't been re-tested since round 2's
  Momo work predates this palette — worth a pass when Phase 1 UI-spec is written.

## Sketches

| # | Name | Design Question | Winner | Tags |
|---|------|----------------|--------|------|
| 001 | app-theme-direction | What background/theme direction should Ritham use app-wide, and how should Momo sit in it? | rejected | theme, background, color, mascot, onboarding, phase-1 |
| 002 | athletic-theme-direction | Round 2 — genuinely athletic/trendy/premium direction after round 1's rejection | superseded | theme, background, color, mascot, onboarding, phase-1, round-2 |
| 003 | band-motif-asset | Round 3 — direct build of the user's own diagonal-band SVG spec | ★ default palette | theme, background, svg, asset, phase-1, round-3 |
