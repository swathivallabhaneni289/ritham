---
sketch: 005
name: condition-checklist-redesign
question: "How should the onboarding condition checklist (grouped multi-select, per-section 'none apply') look and behave, and does it need to move off a leading-checkbox pattern to a native iOS trailing-checkmark list?"
winner: "B"
tags: [checklist, forms, accessibility, onboarding, phase-1, screening]
---

# Sketch 005: Condition Checklist Redesign ★

## Outcome: Winner — B: Native iOS List

Picked over A (spacing-only refinement of the current pattern) and C (same as B but with
outlined cards per section). Rationale: B is the only variant that addresses both original
complaints, not just the visual one — "None apply" becomes an ordinary row inside the section's
own list instead of a small control bolted onto the header, which directly answers the
"confusing" feedback, while the trailing-checkmark row shape is the one grounded in the
strongest research finding (iOS has no native checkbox control at all). C's card boundaries were
rejected as too close to the "wall of boxes" chip-grid direction this same screen already tried
and reverted once.

## Design Question

The onboarding condition checklist (`RithamApp/Ritham/Screening/Views/ConditionChecklistView.swift`,
§1.3) groups conditions into 7 categories, each with its own "None of these apply" escape hatch.
Live-review feedback called the current version "clumsy." This is its **third** visual round —
a chip grid ("wall of boxes") and a tap-to-expand disclosure were both already tried and reverted
before landing on today's leading-checkbox rows. Does a genuinely different row/interaction
pattern read better, or does the current pattern just need better spacing/typography discipline?

## Research Grounding

Before sketching, ran parallel research across iOS-native idioms (Apple HIG), general UX
literature on checkbox lists (NN/g, GOV.UK), and health-app-specific patterns. Full findings:
`.planning/sketches/005-condition-checklist-redesign/RESEARCH.md`.

**Strongest finding:** iOS has no native checkbox or chip/tag control at all — Apple's own
component set has no `checkbox.md`/`chips.md`/`tags.md`. The idiomatic multi-select pattern
(Settings, Mail's mailbox picker, Reminders) is a plain list row with a *trailing* checkmark on
selection, not a leading checkbox glyph. The current implementation's leading-checkbox-square
pattern is closer to a web/Android form convention than a native iOS one — a real candidate for
why it reads as "clumsy" independent of spacing/polish.

**Gaps, disclosed rather than papered over:** the `health-app-patterns` research angle returned
zero findings (no real competitor health-app examples surfaced) — nothing in this sketch is
health-app-specific research, only general iOS/UX guidance. The dedicated `accessibility` research
angle failed outright (schema retry cap exceeded); accessibility findings below come from what
surfaced inside the iOS-native and UX-literature angles instead, which was still substantial
(touch targets, VoiceOver row semantics, "none" announcement requirements).

## How to View
```
open .planning/sketches/005-condition-checklist-redesign/index.html
```

## Variants

- **A: Refined Current** — keeps today's leading-checkbox glyph and per-header "None apply"
  control (same interaction model as shipped), but fixes the whitespace ratio: ~48px between
  sections vs. ~8-14px between rows within one, vs. today's near-uniform spacing. Isolates
  "does better spacing alone fix this" from "does the control shape need to change."
- **B: Native iOS List** — trailing checkmark instead of a leading checkbox, hairline row
  dividers, and "None of these apply" rendered as the *first row inside the section's own list*
  (mutually exclusive with the other rows) rather than a separate header-adjacent control — the
  literal HIG-derived pattern from the research.
- **C: Grouped Cards** — identical rows/checkmarks/None-as-row to B, but each section sits inside
  an outlined card (stroke only, no fill — avoids introducing an unverified new color pairing on
  a screen locked to flat charcoal) instead of relying on whitespace/dividers for chunking.

All three render the real 7 categories and real (verbatim) condition labels from
`RithamCore/Sources/RithamCore/Screening/ScreeningAnswers.swift`, including the two rationale
lines (pregnancy, eating-disorder history) and the longest label ("Heart disease (including a
prior heart attack…)") specifically to stress-test wrapping and icon/checkmark alignment.

## What to Look For

- Does B/C's trailing-checkmark pattern read as more "native iOS" and less "clumsy," or does the
  difference feel negligible next to A's spacing-only fix?
- Does "None apply" work better as its own row inside the list (B/C) or as a compact control next
  to the section header (A)? Tap it in each variant and watch the other rows in that section clear.
- B vs. C: does the card boundary in C help you parse where one section ends and the next begins
  across a long 7-section scroll, or does it just look boxed-in again (echo of the rejected chip
  grid)?
- Try the longest label ("Heart disease…", "A prior injury or surgery…") in each variant — does
  the checkmark/checkbox stay aligned to the first line, and does row height grow cleanly?
- Use the "Reset selections" button in the bottom-right toolbar to try the flow fresh.

## Open Questions for Implementation (not resolved by this sketch)

- A real build needs a VoiceOver announcement when "None" clears other rows in its section — a
  silent state change would leave a screen-reader user unaware other selections just cleared.
- Each "None" row's accessibility label should name its section explicitly ("None of these
  Cardiovascular conditions apply"), not a generic string repeated across all seven sections.
