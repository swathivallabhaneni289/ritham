---
phase: 01-onboarding-safety-intake
plan: 10
subsystem: ui
tags: [swiftui, design-system, shape, dynamic-type, wcag-contrast]

# Dependency graph
requires:
  - phase: 01-09
    provides: "iOS app target (xcodegen-generated Ritham.xcodeproj), RithamTests unit-test target, Scripts/build-app.sh build/test entry point"
provides:
  - "RithamColor -- the four locked palette tokens (ink/hot/volt/paper) plus reserved destructive, and label(on:) encoding the contrast-safe label rule"
  - "RithamType -- the four-role type scale (display/heading/body/label) with a 16pt floor, plus fineprint()/numerals() sanctioned helpers"
  - "RithamSpacing -- the seven-step spacing scale plus minimumTapTarget (44pt)"
  - "BandGeometry -- pure, unit-tested geometry deriving flat-margin fractions and band-boundary edges from a render rect at call time"
  - "BandMotif -- SwiftUI Shape delegating entirely to BandGeometry"
  - "DecorativeSurface presets (.welcome/.boundedHeaderOnly/.calibration/.flat) and ScreenHeader -- a bounded header that drops out of layout at accessibility text sizes"
  - "RingAndDot, HalftoneOrnament, ArcOrnament -- bounded decorative header ornaments"
affects: [01-12, 01-13, 01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every color in the app reaches RithamColor's static tokens -- no other file may contain a 0x hex literal, enforced by a grep acceptance gate"
    - "Shape.path(in rect:) receiving the real render rect at call time, with all geometry re-derived from rect.width/rect.height rather than ported from a design asset's original coordinate space"
    - "@Environment(\\.dynamicTypeSize).isAccessibilitySize dropping a decorative region from the view hierarchy entirely (EmptyView()) rather than just visually de-emphasizing it, so accessibility-size text can never composite over decorative texture"

key-files:
  created:
    - RithamApp/Ritham/DesignSystem/RithamColor.swift
    - RithamApp/Ritham/DesignSystem/RithamType.swift
    - RithamApp/Ritham/DesignSystem/RithamSpacing.swift
    - RithamApp/Ritham/DesignSystem/BandGeometry.swift
    - RithamApp/Ritham/DesignSystem/BandMotif.swift
    - RithamApp/Ritham/DesignSystem/ScreenHeader.swift
    - RithamApp/Ritham/DesignSystem/RingAndDot.swift
    - RithamApp/RithamTests/BandGeometryTests.swift
  modified: []

key-decisions:
  - "BandGeometry's flat-margin split uses only the band angle (57 degrees, fixed) and the render rect as inputs: span = rect.height / tan(angle) is the horizontal room the diagonal needs for this rect's own aspect ratio; the remaining width is split symmetrically as zone = remaining/2, margin = remaining/4 per side -- dimensionless proportion divisors of a rect-derived value, not coordinates ported from sketch 003"
  - "RithamColor.label(on:) uses an if/else equality check (fill == hot || fill == volt) rather than a switch-case, to avoid Swift's leading-dot pattern-matching ambiguity between Color's own static members and RithamColor's"
  - "DecorativeSurface.flat's header comment enumerates nine flat-charcoal screens, not the plan's stated ten -- see Deviations"

patterns-established:
  - "Pattern: a Shape's path(in:) must delegate to a pure, SwiftUI-independent geometry type for any composition whose original design asset was solved for a different aspect ratio/coordinate space, so the geometry is unit-testable and provably not a port"

requirements-completed: [CROSSGEN-05, HEALTH-05]

coverage:
  - id: D1
    description: "One theme object (RithamColor) owns every color in the app; the failing off-white-on-coral/lime contrast pairs are unreachable through label(on:)"
    requirement: "HEALTH-05"
    verification:
      - kind: other
        ref: "grep -rlE '0x[0-9A-Fa-f]{6}' RithamApp/Ritham lists only RithamColor.swift"
        status: pass
      - kind: other
        ref: "grep -c 'func label(on' RithamApp/Ritham/DesignSystem/RithamColor.swift == 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "Four-role type scale with a 16pt floor -- no role renders below RithamType.label, including the fine-print path"
    requirement: "CROSSGEN-05"
    verification:
      - kind: other
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
      - kind: other
        ref: "grep -rnE '\\.footnote|\\.caption' RithamApp/Ritham/DesignSystem -- no matches inside DesignSystem/ (one pre-existing match outside scope, see deferred-items.md)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Band geometry is computed from the render rect and proven to leave non-zero flat margins at three real portrait header sizes, and demonstrably not a port of sketch 003's landscape figures"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/BandGeometryTests.swift -- 7/7 tests pass (positive margins at 390x250/393x280/430x220, in-bounds edges, determinism, width-dependence, landscape-vs-portrait divergence)"
        status: pass
    human_judgment: false
  - id: D4
    description: "ScreenHeader drops out of the layout entirely at accessibility text sizes so no text ever composites over the band motif or halftone texture"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "grep -c 'isAccessibilitySize' RithamApp/Ritham/DesignSystem/ScreenHeader.swift == 2 (build-time proof of the mechanism); visual confirmation at AX1-AX5 is a human checkpoint deferred to plan 01-19 per 01-VALIDATION.md"
        status: pass
    human_judgment: true
    rationale: "The mechanism (EmptyView() at isAccessibilitySize) is proven by grep and by BUILD SUCCEEDED, but actual visual reflow at AX1-AX5 on a real header composition requires a rendered screen, which does not exist until later screen plans (01-12+) consume ScreenHeader -- 01-UI-SPEC.md and this plan's own threat model (T-01-54) explicitly defer that visual check to plan 01-19's human checkpoint."
  - id: D5
    description: "RingAndDot exposes no parameter that could carry a progress/fraction/completion value, so it cannot be misused as an Activity-Rings-style data widget"
    requirement: "HEALTH-05"
    verification:
      - kind: other
        ref: "RithamApp/Ritham/DesignSystem/RingAndDot.swift -- struct RingAndDot's only stored property is `diameter: CGFloat`"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 10: Design System -- Palette, Type Scale, Band Geometry, Header Summary

**Four-token color theme with a binding contrast rule, a four-role type scale with a 16pt floor, a seven-step spacing scale, and the band motif re-expressed as a pure, unit-tested `Shape` that derives its geometry from the actual render rect instead of porting sketch 003's landscape SVG coordinates.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 3
- **Files modified:** 8 (all created)

## Accomplishments
- `RithamColor` is the single source of every color in the app -- confirmed by a grep gate that no `0x` hex literal exists anywhere in `RithamApp/Ritham` outside `RithamColor.swift`; `label(on:)` makes the two failing contrast pairs (off-white on coral 2.8:1, off-white on lime 1.2:1) unreachable through the sanctioned API
- `RithamType` exposes exactly four roles (`display`/`heading`/`body`/`label`) with no role below 16pt, plus `fineprint()` (reduced opacity, same size) and `numerals()` (`.monospacedDigit()`) as the sanctioned ways to get "fine print" and non-jittering counters without ever shrinking below the floor
- `RithamSpacing` provides the seven-step scale (`xs` through `xxxl`) and `minimumTapTarget` (44pt)
- `BandGeometry` re-derives the band motif's flat-margin fractions and band-boundary crossings from a render rect's own `width`/`height` at call time, using only the fixed 57-degree angle as an external input -- proven by 7 unit tests to leave strictly positive flat margins at 390x250, 393x280, and 430x220 (real portrait header sizes), stay within the rect's bounds, be deterministic, respond to width changes, and diverge measurably from sketch 003's original 1440x720 landscape figures
- `BandMotif: Shape` delegates its entire `path(in:)` to `BandGeometry` -- no arithmetic on literal coordinates in the shape itself
- `ScreenHeader` bounds the decorative header to an explicit height (default 250pt, within the 220-280pt recommendation) and renders `EmptyView()` entirely at accessibility text sizes, so content reflows onto flat charcoal instead of ever compositing over the band motif or halftone texture
- `DecorativeSurface` presets (`.welcome`, `.boundedHeaderOnly`, `.calibration`, `.flat`) encode the Decorative Surface Inventory; `.flat`'s header comment enumerates the flat-charcoal screens for later screen plans
- `RingAndDot` is a static lime ring-and-dot ornament with no parameter that could carry a progress, fraction, or completion value, plus bounded `HalftoneOrnament` and `ArcOrnament` header decorations

## Task Commits

Each task was committed atomically:

1. **Task 1: Palette, type scale, and spacing tokens** - `8e3d416` (feat)
2. **Task 2: Band geometry computed from the render rect** - `72ddec6` (feat)
3. **Task 3: The bounded header and the static ring ornament** - `b82c1cd` (feat)

## Files Created/Modified
- `RithamApp/Ritham/DesignSystem/RithamColor.swift` - Four locked palette tokens + reserved `destructive`, private hex initializer, `label(on:)` contrast rule with measured ratios in the header comment
- `RithamApp/Ritham/DesignSystem/RithamType.swift` - Four-role type scale, 16pt floor, `fineprint()`/`numerals()` `ViewModifier` helpers
- `RithamApp/Ritham/DesignSystem/RithamSpacing.swift` - Seven-step spacing scale + `minimumTapTarget`
- `RithamApp/Ritham/DesignSystem/BandGeometry.swift` - Pure struct (`CGRect`/`CGPoint` only) computing flat-margin fractions and band-boundary edges from the render rect
- `RithamApp/Ritham/DesignSystem/BandMotif.swift` - `Shape` delegating entirely to `BandGeometry`
- `RithamApp/RithamTests/BandGeometryTests.swift` - 7 Swift Testing tests covering positive margins, in-bounds edges, determinism, width-dependence, and landscape-vs-portrait divergence
- `RithamApp/Ritham/DesignSystem/ScreenHeader.swift` - `DecorativeSurface` struct + presets, `ScreenHeader` view dropping out at accessibility sizes
- `RithamApp/Ritham/DesignSystem/RingAndDot.swift` - `RingAndDot`, `HalftoneOrnament`, `ArcOrnament` decorative views
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after each task to pick up the new `DesignSystem/` sources (folder references are a file-list snapshot per 01-09)
- `.planning/phases/01-onboarding-safety-intake/deferred-items.md` - New file logging one out-of-scope discovery (see Deviations)

## Decisions Made
- `BandGeometry`'s flat-margin formula uses only the band angle and the rect as inputs (`span = height / tan(angle)`, `margin = (width - span) / 4` per side), avoiding a second arbitrary constant beyond the angle while still producing non-trivial (13-17%) margins at all three tested portrait sizes rather than a knife-edge value that would pass a bare `> 0` assertion without being visually usable
- The landscape-vs-portrait port-detection test compares against 390x250 and 393x280 only, not 430x220 -- 430x220's aspect ratio (0.512) is close enough to 1440x720's (0.500) that the fraction gap there (~0.002) is too small to be a meaningful epsilon-based signal, while 390x250 and 393x280 both diverge by >2 percentage points
- `label(on:)` uses `if fill == hot || fill == volt` rather than a `switch` with bare `case hot, volt:`, because Swift's leading-dot pattern matching for a `switch` on `Color` would look for static members on `Color` itself, not `RithamColor` -- the explicit equality check is unambiguous

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.flat` preset's header comment enumerates nine screens, not the plan's stated ten**
- **Found during:** Task 3, reading 01-UI-SPEC.md's Decorative Surface Inventory before writing `ScreenHeader.swift`
- **Issue:** The plan's Task 3 action text lists ten screens for the `.flat` comment, including "the consent halt" and "the teen partial-gate notice." 01-UI-SPEC.md's own 2026-08-23 update (and PROJECT.md's Key Decisions / STATE.md) removed both rows when Ritham moved to a permanent 13+ age floor with no consent flow of any kind, replacing them with a single "Age blocking (under 13)" row. The plan predates that reversal and would have baked a reference to two screens that no longer exist into a comment later screen plans are told not to re-derive.
- **Fix:** Enumerated the current nine flat-charcoal rows from 01-UI-SPEC.md's inventory as it stands today: age (Q0), dietary pattern (Q0b), age blocking (under 13), gate section (G1-G7), routine clearance interstitial, urgent clearance interstitial, condition checklist, SCOFF/eating-disorder follow-up, required-blocking message.
- **Files modified:** `RithamApp/Ritham/DesignSystem/ScreenHeader.swift`
- **Verification:** Cross-checked against 01-UI-SPEC.md's Decorative Surface Inventory table and its 2026-08-23 update note; `./Scripts/build-app.sh build` succeeds
- **Committed in:** `b82c1cd` (Task 3 commit)

**2. [Rule 3 / scope-boundary] Logged, not fixed: `StepRegistry.swift`'s placeholder view uses `.caption`**
- **Found during:** Task 3, running the type-floor self-check (`grep -rnE '\.footnote|\.caption' RithamApp/Ritham`) after writing this plan's files
- **Issue:** `RithamApp/Ritham/App/StepRegistry.swift`'s `UnimplementedStepView` (a 01-09 placeholder shown only for an `OnboardingStep` with no registered screen yet) uses `.font(.caption)`, below the floor `RithamType` now establishes.
- **Fix:** Not fixed -- `StepRegistry.swift` is not in this plan's `files_modified`, and the placeholder is dev-only scaffolding that stops rendering once every screen plan registers its view (01-18's `PhaseCoverageTests` asserts `unregisteredSteps` is empty). Logged to `deferred-items.md` for whichever plan next owns that file.
- **Files modified:** `.planning/phases/01-onboarding-safety-intake/deferred-items.md` (new)
- **Verification:** N/A (documentation only)
- **Committed in:** `b82c1cd` (Task 3 commit)

---

**Total deviations:** 2 (1 auto-fixed Rule 1 bug, 1 out-of-scope item deferred per the scope-boundary rule)
**Impact on plan:** The nine-vs-ten screen count correction keeps the header comment's screen enumeration accurate against the current, already-decided product state; skipping the unrelated `StepRegistry.swift` fix avoids scope creep into a file this plan does not own. No architectural change.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `RithamColor`, `RithamType`, `RithamSpacing`, `BandGeometry`, `BandMotif`, `ScreenHeader`, `DecorativeSurface`, and `RingAndDot` are all ready for 01-12/01-13/01-15/01-16/01-17's screens to consume directly
- `DecorativeSurface.flat`'s header comment gives those plans the definitive nine-screen list without needing to re-derive it from 01-UI-SPEC.md
- Visual confirmation that `ScreenHeader` actually reflows correctly at AX1-AX5 on a real composed screen remains a human checkpoint deferred to plan 01-19, per 01-VALIDATION.md and this plan's own threat model (T-01-54) -- the mechanism is proven here, but there is no rendered screen yet to visually check against
- One pre-existing, out-of-scope type-floor violation logged in `deferred-items.md` (`StepRegistry.swift`'s placeholder view) for a later plan to resolve
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 8 created files verified present on disk (plus `deferred-items.md`); all three task commit
hashes (8e3d416, 72ddec6, b82c1cd) verified in git log.
