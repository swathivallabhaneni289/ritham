---
sketch: 004
name: welcome-hero-treatment
question: "Should the ring-and-dot ornament become a bigger decorative element instead of always relying on the diagonal band, and how do we stop short-content screens like Welcome from feeling empty below the CTA?"
winner: "Synthesis"
tags: [layout, hero, ring-and-dot, band-motif, welcome, phase-1, round-4]
---

# Sketch 004: Welcome Hero Treatment

## Design Question
Two related questions raised during Phase 1's human-review checkpoint, looking at the live app:
1. A lot of empty charcoal below the CTA button on short-content screens (Welcome specifically).
2. Whether the ring-and-dot ornament should become a real decorative element on more screens, instead of the diagonal band doing all the work.

Locked constraint from `01-UI-SPEC.md`'s Binding Rule: the ring-and-dot must stay **static and non-data-bearing** — "must never visually fill/progress" — specifically so it never reads as an Apple Activity Rings-style indicator. All three variants respect this (nothing here animates fill or represents data); Variant B pushes the size of that static ring further than anywhere it's been used before, which is worth a second look precisely because of that rule, not despite it.

## How to View
```
open .planning/sketches/004-welcome-hero-treatment/index.html
```

## Variants
- **A: Baseline** — what's live today. Small band, tiny corner ring-dot, empty space below. Shown for direct comparison, not a real option.
- **B: Ring-and-dot as the hero** — band dropped entirely, one large static ring-and-dot (plus two small echo rings) becomes the primary decorative mark.
- **C: Shortened band + reclaimed space** — band trimmed smaller, ring-dot modestly enlarged, and the freed vertical space is treated as real layout (a content block or tighter rhythm) rather than empty charcoal.
- **★ Synthesis (winner): band + big ring together, animated entrance, Welcome only** — combines A and B rather than choosing between them, per direct feedback: band and a large ring-and-dot both present, with a one-time staggered entrance (band slides in, ring scales in, text/button rise up) on first open. Settles to fully static after ~0.7s — nothing loops, so the locked "must stay static, never fill/progress" rule still holds once the entrance finishes; only the transient reveal moves.

Below the phone comparison, an **alternation strip** shows the follow-up decision: this full combo is Welcome-only. Later "bounded header only" screens (privacy explainer, calibration start/complete) alternate between a small ring-and-dot-only header and a small band-only header, both static — variety instead of repeating the big combo everywhere. Screens that are locked flat for screening-integrity reasons (age, gate section, checklist, SCOFF) are unaffected and stay fully flat with no motif.

## What to Look For
- Does B's large ring read as decorative, or does its size alone start to suggest "progress" even though nothing fills or animates? This is the one place a locked design rule is being tested at its edge.
- Does C actually feel less empty, or does it just move the emptiness around?
- Which one still feels like "Ritham" — matches the energetic/premium feel from the original sketch 002→003 direction, not a softer/calmer thing?
