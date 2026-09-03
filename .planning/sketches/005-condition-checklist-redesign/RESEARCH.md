# Research: Accessible Multi-Select Medical Checklist Patterns

Ran as a 4-way parallel research workflow before sketching (`condition-checklist-research`,
run `wf_f0bab74b-526`). 3 of 4 angles returned usable findings; disclosed below rather than
silently omitted.

## Angle: iOS-native idioms (Apple HIG) — succeeded

- **iOS/iPadOS has no native checkbox control.** Apple's Toggles page scopes the checkbox style
  (and radio buttons) to macOS only. A scan of Apple's HIG component directory (73 files) turns up
  no `checkbox.md`, `chips.md`, `tags.md`, or `selection-controls.md`. For multi-select, the
  native pattern is List rows with a trailing checkmark, not a checkbox glyph.
- Reserve `Toggle`/switch for a true binary state of *one* setting, never as a stand-in for one
  option among several — Apple's own guidance explicitly calls this out.
- The idiomatic multi-select pattern: a List/Form Section of option rows, each selected row shows
  a trailing checkmark (SF Symbol, accent-tinted), highlight is momentary not persistent
  (persistent highlighting is reserved for navigation rows). Generalizes cleanly by tracking a
  `Set<ID>` and toggling a row's checkmark on tap.
- Don't overload a row with both a disclosure chevron (drill into another screen) and a
  selection affordance — separate concerns, separate rows.
- Keep list item text short/single-line where possible; don't hardcode a fixed row height — let
  content + Dynamic Type drive it. The only hard number is the general 44×44pt minimum tap target.
- Segmented controls are for switching between views/filters, not for building a multi-select
  answer list — capped at ~5 segments, wrong shape for this screen regardless.
- No documented native idiom for "None of the above" specifically. Most defensible approach:
  make it one more row in the same option-list section (not a separate widget), enforce mutual
  exclusivity as app logic (selecting None clears the others and vice versa) — mirrors radio-button
  semantics even though radio buttons aren't a native iOS component either.
- Section headers/footers in a grouped/inset List are the right place for a question prompt
  (header) and scope/caveat text (footer) — current default styling is *not* uppercase/tracked;
  that's legacy plain-style-List behavior, don't hand-roll it.

## Angle: General UX literature on checkbox lists (NN/g, GOV.UK) — succeeded

- Checkboxes: independent 0-to-many selection, no immediate effect (fine for a form with a
  Continue/Save step, which this screen has).
- Toggles: only for a genuinely binary, immediate-effect setting — wrong shape for "which
  conditions apply."
- Render checkbox-equivalents as squares, never circles (circles read as radio/single-select).
- Word every option positively; avoid negations.
- Whole label (not just the glyph) must be the tap target, minimum ~1cm × 1cm (iOS's 44×44pt
  already meets this).
- List vertically, one per line, logical order — horizontal/chip layouts hurt scan speed for
  longer text. One usability comparison found single-column checkbox-list scanning ~30% faster
  than chip-based multi-select (6s vs. 9s) — directional, not peer-reviewed, but consistent with
  NN/g's general vertical-scan findings. Reserve chips for short labels/small option counts —
  not this screen's long medical condition names.
- Treat "none of the above" as a real, first-class, mutually-exclusive item — not "leave
  everything blank." GOV.UK: avoid the literal phrase "none of the above" since it presumes a
  visual "above" reference that doesn't hold for screen readers navigating linearly; restate the
  question instead if there's no adjacent visual heading to anchor it. Since this screen's "None
  apply" always sits directly under/beside a visible section heading, "None of these apply" is
  fine — the referent ("these") is a heading right there, not an abstract list position.
- 10+ item lists: progressive disclosure by exposing highest-priority items first (backed by
  usage data, not guesswork), cap disclosure at 2 levels, never hide a frequently-needed item
  purely for tidiness. (Not directly load-bearing here — no single category has 10+ items today,
  but relevant if a future category grows.)
- Break long lists into sections with visible subheadings; use whitespace ratio (tight within a
  group, distinctly larger between groups) so proximity alone signals structure — position each
  heading directly above its own option cluster.
- Icons alone don't reliably distinguish options (no standardized meaning); keep them secondary
  to text labels if used at all.

## Angle: Health-app-specific competitor patterns — no findings

Returned empty (`"findings": []`). No real competitor telehealth-intake/health-app examples
surfaced from this angle's searches. Nothing in this sketch's design decisions rests on a
health-app-specific claim — every rule above is general iOS platform guidance or general UX
literature, cited as such.

## Angle: Dedicated accessibility deep-dive — failed

Failed outright (`StructuredOutput retry cap (5) exceeded`) — no output recovered. Not re-run.
Accessibility-relevant findings that did surface came from the two successful angles above
(44×44pt minimum targets, VoiceOver row/state semantics implied by "one row = one selectable
element," "none" needing an announcement when it clears other rows). This is a real gap, not
silently backfilled — a dedicated WCAG/VoiceOver-specific pass would be worth running before
implementation, not just before this sketch.

## Synthesis (verbatim from the research workflow)

See the workflow's own synthesis for the full three-heading brief (Interaction pattern / Visual
treatment / Accessibility) this sketch was built from — reproduced in `.planning/sketches/`
workflow transcript `wf_f0bab74b-526`, journal.jsonl, agent `synthesize-brief`. Key points not
already listed above:

- Contrast is measured against Ritham's exact locked palette, not eyeballed: accent-on-charcoal
  = 6.2:1, primary text-on-charcoal = 17.2:1 — both already clear WCAG AA. Any *new* color
  introduced by a variant (a card tint, a divider color) needs its own contrast check — only the
  four existing palette tokens are pre-verified.
- Rationale/consent lines (pregnancy, eating-disorder history) must stay full body weight, never
  dimmed to fine-print — already a deliberate choice in the shipped app; dimming would
  misrepresent what's being consented to.
