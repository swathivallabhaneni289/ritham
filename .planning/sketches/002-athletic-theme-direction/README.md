---
sketch: 002
name: athletic-theme-direction
question: "Round 2 — after sketch 001 was rejected as basic/Duolingo-ish/wellness-coded, what does a genuinely athletic, trendy, premium direction look like?"
winner: null
status: superseded
tags: [theme, background, color, mascot, onboarding, phase-1, round-2]
---

# Sketch 002: Athletic Theme Direction (Round 2)

## Outcome: Superseded

No variant here was rejected outright — the user instead supplied their own exact composition
(diagonal bands, halftone, concentric arcs) which became [sketch 003](../003-band-motif-asset/README.md),
confirmed as the winner. The one durable decision from this round: orange/amber was dropped as the
UI accent entirely per direct feedback (Momo keeps his own ginger coat independent of the app's
functional accent color) — that finding carries forward regardless of this round not winning.

## Design Question
Sketch 001 (Ember Horizon / Quiet Confidence / Stone & Sage) was rejected: "really basic," one
read as Duolingo, one felt too plain, one didn't feel like a fitness app at all. The diagnosis
(see the per-variant annotation panels in the sketch) is structural, not just chromatic — all
three round-1 directions shared the same soft radius scale, `ui-rounded` numerals, and
color-as-decorative-wash pattern. This round changes structure per direction, grounded in
Nike Training Club / WHOOP / Peloton and current 2026 mobile design trends, not wellness apps.

## How to View
```
open .planning/sketches/002-athletic-theme-direction/index.html
```

## Variants
- **A: Afterburn** — near-black instrument-panel premium (WHOOP/Peloton family). Amber is a
  signal only — CTA, live data, progress fill — never a background wash. Momentum is a 3-slot bar
  strip. Momo sits in a bounded, warm-lit portrait card, not floated over live data.
- **B: Full Stride** — editorial/photographic premium (Nike family). Full-bleed hero imagery
  (placeholder here — real photography/render is a separate commission) with a bottom scrim,
  massive condensed display type, amber as solid shapes on top of the image. Momo gets full
  campaign-hero treatment — the direction where he integrates most naturally.
- **C: Hard Court** — bold graphic light mode. Near-white ground, hard-edged solid amber
  color-blocks, scoreboard-tile numerals. This is the real, equally-finished light mode a
  dark-first direction needs alongside it (Peloton shipped dark-only in Oct 2025 and reversed
  within 4 weeks after user backlash).

Hard rule across all three, stated in the research: **amber is a signal, never a decorative
surface.** No `ui-rounded`/SF Rounded numerals anywhere. No ring/badge/shield/bloom-shaped
Momentum indicator — round 1's arc, dots, and bloom were all reward-token/toy patterns; this
round uses data forms (bar strip, filmstrip, block grid) instead.

## What to Look For
- Does this actually read as a fitness/training app now, vs. round 1's wellness-app read?
- Does any of the three still feel gamified/toy-like, or does the structural change (radius,
  type, Momentum-as-data-not-badge) fix that?
- Momo placement: does he integrate naturally, or still feel pasted on? (Full Stride is expected
  to be the easiest case, Afterburn the hardest — per the research.)
- Try the Momentum "+" button in each — bar strip (A) vs. filmstrip (B) vs. block grid (C).
- Hard Court is deliberately light-mode — worth judging on its own terms, not just as "the pale
  one," since it may end up shipping alongside whichever dark direction wins.
