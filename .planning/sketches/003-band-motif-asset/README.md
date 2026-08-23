---
sketch: 003
name: band-motif-asset
question: "Build the exact diagonal-band background asset per the user's own technical spec — charcoal/coral/lime/off-white, safe zones, halftone, arcs, ring-and-dot."
winner: "default"
tags: [theme, background, svg, asset, phase-1, round-3]
---

# Sketch 003: Band Motif Background Asset ★

## Outcome: Winner — default palette

Confirmed as Ritham's visual direction after a trademark/brand-collision check (no brand owns
this combination; reads as generic 2025–2026 trend language — neo-brutalism + halftone revival +
Acid Graphics, not a copy of any specific competitor). Charcoal `#0E100D` / coral `#FF5C39` / acid
lime `#C6F24E` / off-white `#F5F3EC` is the palette going forward — the Cobalt/Crimson options in
the live switcher were unvetted demo variants only, not real alternatives, and are not in
contention.

Two open items carried forward, not blockers to planning:
- The ring-and-dot motif's Apple Activity Rings association is a deliberate design choice to make
  during UI-spec/implementation (differentiate it or lean into the familiarity on purpose).
- This SVG is a design spec, not a drop-in asset — Phase 1 implementation needs it re-expressed as
  native SwiftUI `Shape`/`Path` drawing with a Swift-side theme object, not CSS custom properties.

## What this is
Not another set of options — this is a direct build to the user's own precise spec (palette,
composition, and SVG technical requirements all specified explicitly), grounded in three
reference images they supplied. Deliverables:

- `background.svg` — the standalone asset.
- `theme.css` — the external override stylesheet (four classes, CSS custom properties).
- `index.html` — a live demo: landscape view, a portrait phone-frame crop (proving the
  `xMidYMid slice` behavior), a live palette switcher (proving the class/CSS-variable override
  actually works, not just declared), and the raw source for copy-paste.

## Geometry note
The bands sit at ~57° from horizontal, not a literal 45° — solved this way deliberately: at a
true 45° on a 1440×720 canvas, the diagonal's full-height horizontal travel (720px) doesn't leave
room for the band's own width *and* both the 25%-left / 20%-right flat margins at the same time.
Verified by computing exact edge-crossing x-positions at the visible top (y=0) and bottom (y=720)
in Python rather than eyeballing — both margins land at ~46–48px of clear flat charcoal, comfortably
inside the "~25%" / "~20%" targets. 57° still reads as "steep" (the spec's own word) and clearly
implies forward motion; if a shallower angle is wanted instead, the fix is a wider canvas, not a
thinner band.

## How to view
```
open .planning/sketches/003-band-motif-asset/index.html
```

## Checklist against the spec
- Flat fills only, no gradients/shadows/glow — confirmed, every fill/stroke is a plain hex value.
- Three bands, varied width (coral broadest, lime medium, off-white thin sliver) — confirmed.
- Left ~25% / right ~20% stay flat charcoal at every visible row — verified computationally, not
  just visually.
- Halftone dot pattern in one dark corner (top-right, coral-tinted) — confirmed.
- Concentric arcs bleeding off the right edge — confirmed (center sits exactly on the right edge).
- Small ring-and-dot motif in the flat zone — confirmed.
- Plain hex in presentation attributes, no `var()` inside the SVG — confirmed.
- Four themeable classes (`band-ink`/`band-hot`/`band-volt`/`band-paper`) + external CSS rule
  block driving both `fill` and `stroke` off custom properties — confirmed in `theme.css`.
  Stroke-only shapes (arcs, ring) guard against the class rule's `fill` with an inline
  `style="fill:none"`, which no external class selector can out-specificity.
- `preserveAspectRatio="xMidYMid slice"` on the root `<svg>` — confirmed.
- `role="img"` + descriptive `aria-label` — confirmed.
- Content wrapped in a `clipPath`; band polygons and arc circles deliberately overshoot the
  1440×720 canvas and get cropped cleanly by it — confirmed.
- No external references, no embedded fonts, no raster images — confirmed, pure inline vector.
