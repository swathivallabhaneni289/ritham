---
sketch: 001
name: app-theme-direction
question: "What background/theme direction should Ritham use app-wide, and how should Momo sit in it?"
winner: null
status: rejected
tags: [theme, background, color, mascot, onboarding, phase-1]
---

# Sketch 001: App Theme Direction

## Outcome: Rejected

All three variants were rejected by the user as "really basic" — Ember Horizon read as Duolingo
(warm amber wash on cream + soft rounded cards + `ui-rounded` numerals is toy-like/gamified
regardless of hue), Quiet Confidence read as too plain/boring, and Stone & Sage didn't read as a
fitness app at all (cream/sage/green is wellness/journaling-coded). Follow-up direction continues
in [sketch 002](../002-athletic-theme-direction/README.md), grounded in athletic/premium
references (Nike Training Club, WHOOP, Peloton) instead of wellness apps.

## Design Question
What should Ritham's app-wide background/theme look like — clean but not flat/boring, warm but not
childish, cross-generational, and compatible with Momo's semi-realistic painted mascot style —
and does that direction hold up differently on the safety-screening screen, which research says
should stay flat and restrained regardless of theme?

Grounded in a design-research pass (see workflow research on Calm/Headspace, Apple Fitness+/Health,
and AllTrails/Strava) rather than pure taste — each variant borrows specific, sourced techniques
and explicitly avoids specific, sourced risks. Full research + synthesis is summarized in the
per-variant annotation panels inside the sketch itself.

## How to View
```
open .planning/sketches/001-app-theme-direction/index.html
```

## Variants
- **A: Ember Horizon** — Soft cream→apricot daylight gradient; amber reserved for Momentum/live
  accents only (never a button, never a ring); Momentum renders as an open arc. Recommended
  direction from the research synthesis.
- **B: Quiet Confidence** — Near-colorless, Apple-native ground; warmth comes almost entirely from
  rounded numerals; Momo shrinks to a small glyph; Momentum renders as a dot row. Lowest-risk,
  most restrained.
- **C: Stone & Sage** — Earthy cream/sage/forest field with a hint of organic texture; amber spent
  sparingly, gated to "live right now"; Momentum renders as a growing bloom (petals accumulate,
  echoing growth-only/never-decaying framing).

Each variant shows two screens inside a phone frame: **Welcome** (onboarding, where Momo appears)
and **Safety Screening** (PAR-Q-style gate question — flat/restrained in all three variants by
deliberate design, per the research synthesis: none of the three sourced references put an
illustrated character on a health-screening-adjacent surface).

## What to Look For
- Does the background feel "interesting" without feeling busy or clumsy — the user's explicit ask?
- Does Momo (placeholder silhouette — final art is a separate illustration commission per
  `docs/mascot.md`) feel like part of the scene, or pasted on top?
- Does the safety-screening screen feel calm and private, not clinical — even without Momo or
  color there?
- Try the "+" button on the Momentum widget in each variant — does the arc / dots / bloom shape
  feel distinct and legible at a glance?
- Try the Simple/Detailed explanation-register toggle and the "i" info dots — this is the
  tap-to-expand pattern Phase 1 requires (EXPLAIN-01).
- Try selecting a screening answer and tapping Continue — Continue should stay disabled until an
  answer is picked (mirrors the real fixed-choice, no-free-text screening requirement).
