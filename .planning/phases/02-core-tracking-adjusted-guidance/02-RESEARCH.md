# Phase 2: Core Tracking & Adjusted Guidance - Research

**Researched:** 2026-08-28
**Domain:** Native iOS (SwiftUI/SwiftData/CoreLocation/CoreMotion) cardio + strength session logging, condition-tag-adjusted workout/nutrition guidance content, plate-math and superset domain logic
**Confidence:** MEDIUM — the RithamCore API surface this phase builds on (`ConditionTag`, `ClearanceGate`, `GateResolution`, `DietaryPattern`) was read directly from the committed source, not inferred (HIGH for that part specifically). The Apple-framework technical findings (CoreMotion auto-detect, CoreLocation accuracy/battery practice, Swift Charts, plate-math, grade-adjusted pace) are WebSearch cross-referenced across 2+ independent sources per finding (MEDIUM per the `classify-confidence` seam), not compiled/run this session — no MCP documentation providers (Context7, Ref, Exa) were available in this environment, so every non-codebase finding below is `[CITED: websearch]`, never `[VERIFIED]`.

> **No CONTEXT.md exists for this phase yet.** This research runs before `/gsd-discuss-phase 2` (per this task's own instructions, matching Phase 1's sequencing where `01-CONTEXT.md` preceded `01-RESEARCH.md`... actually the reverse here: Phase 2 has no discuss-phase output yet). There is therefore no `<user_constraints>` section — nothing has been locked by the user for this phase. Every gray area below is written up in **Open Questions for Discussion**, not decided. Do not read the absence of that section as an oversight.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CARDIO-01 | Activity-type selector (Run/Walk/Cycle/Hike/Swim/Elliptical, extensible), manual stopwatch, full history, free forever, local-first | New `CardioSession`/`ActivityType` RithamCore domain type (extensible enum, not the fixed `CalibrationMode.walk` used in Phase 1); `StopwatchSession` pattern reused conceptually, not literally, per Architecture Patterns below |
| CARDIO-02 | GPS pace/distance/elevation/splits/grade-adjusted pace with visible confidence indicator | CoreLocation accuracy-threshold filtering + `CLLocation.distance(from:)` accumulation (Standard Stack); GAP formula research (Common Pitfalls); confidence indicator is a UI requirement, not silently-varying numbers |
| CARDIO-03 | Route/segment comparison, opt-in only, no default leaderboard | MapKit (native) for route rendering; opt-in visibility model — see Open Questions; PROJECT.md's permanent "no cross-user aggregate location visualization" prohibition is a hard boundary this phase must respect |
| STRENGTH-01 | Set logging, auto-fill previous session's weight/reps | New `LiftSet`/`ExerciseLog` SwiftData model, queried by exercise identifier for "most recent" |
| STRENGTH-02 | Free plate calculator: barbell/EZ/trap/Smith/stack, nearest loadable weight | Pure-Swift greedy-algorithm `PlateCalculator` in RithamCore (Architecture Patterns) |
| STRENGTH-03 | Built-in supersets/circuits | Superset data-model pattern (Architecture Patterns) — a grouping key on sets, not a separate session type |
| STRENGTH-04 | Auto-tagged movement pattern (push/pull/squat/hinge/carry), filterable | Exercise-to-pattern lookup table in RithamCore; ambiguity (multi-pattern exercises) flagged as Open Question |
| STRENGTH-05 | Full retroactive editing, year-jump date picker, session merge/split | Data-model constraint, not just a UI feature — sets need stable identity independent of session, see Common Pitfalls |
| HEALTH-03 | Workout guidance adjusts per condition tag the moment logged/planned; required-blocking → generic + referral only | `GateResolution`/`ConditionTag`/`GateEscalation.baseGates` already fully implemented (Phase 1) and sufficient for gating; a **new** RithamCore content-permission type is needed for guidance *text* — see Architectural Responsibility Map and Pattern 4 |
| HEALTH-04 | Nutrition guidance adjusts per condition tag; population-level reference figures only, never individually calculated; Under-18 required-blocking for weight-management features | Same gate infrastructure; `.under18Minor` producer confirmed already wired (Phase 1, plan 01-06) — Phase 2 does not need to re-derive it, only read `HealthDataStore.activeConditionTags` |
| DIET-02 | Dietary-pattern-keyed food-swap table, only when nutrition gate is `none`/`recommended` | New RithamCore lookup keyed by `(nutrition row, DietaryPattern)` — gate-conditional, per `docs/dietary-pattern.md` §2's worked kidney-disease example |
| DIET-03 | Vegan/vegetarian nutrient-education blocks, shown identically regardless of condition tag | **Not** gate-conditional — must render even under a `required-blocking` nutrition gate, unlike DIET-02; see Common Pitfalls for the trap of conflating the two |
| MONETIZE-01 | Visible "always free" list in Settings, matching what's actually never paywalled | Pure content/Settings-screen addition; reuses `SettingsView` (Phase 1) as the host — no new gating architecture, since Phase 1/2 introduce no paywall infrastructure at all |
| CROSSGEN-02 | Passive-first capture: auto-detect walk/run from motion sensors, alongside full manual configuration | `CMMotionActivityManager` (new type, distinct from Phase 1's `CMPedometer`-based `PedometerSession`) — see Pattern 3 for why this is new code, not a refactor of Phase 1's calibration sensors |
</phase_requirements>

## Summary

Phase 2 is the first phase to write outside the onboarding/screening domain, and it lands on a genuinely solid foundation: `RithamCore`'s `ConditionTag` (31 cases), `ClearanceGate` (a structurally one-way `mostRestrictive` selector), `GateResolution.resolve`, and `GateEscalation.baseGates(for:)` already implement the *entire* per-tag, per-domain gate matrix from `docs/health-screening.md` §2/§3 — this was verified by reading the committed source, not inferred. **What Phase 2 actually needs to build is content, not gating logic.** `blocksPersonalization(in: .nutrition)` correctly tells a caller whether personalization is blocked, but the existing three-level `ClearanceGate` enum (`none`/`recommended`/`requiredBlocking`) cannot by itself distinguish "show zero content of any kind" (kidney disease, pregnancy-complicated, positive ED screen) from "show generic education, zero numbers" (Under-18, hypertension-uncontrolled, postpartum-uncomplicated) — `GateEscalation.swift`'s own comment on `hypertensionUncontrolledOrUnsure` names this exact gap as "content-layer, not gate-level." Phase 2's primary RithamCore addition is therefore a new content-permission type sitting downstream of `DomainGates`, plus the actual guidance-text catalog (workout adjustment copy, contraindicated lists, nutrition guidance copy, dietary-pattern food swaps) transcribed from `docs/health-screening.md` §2/§3 and `docs/dietary-pattern.md` §3/§4 — the same "transcribe verbatim, single source of truth" pattern Phase 1 already established for `ScreeningCopy`/`OnboardingCopy`.

The cardio/strength tracking half of this phase is standard, well-precedented native-iOS work: CoreLocation for GPS (accuracy-threshold filtering, not a hand-rolled Kalman filter), a new `CMMotionActivityManager`-based auto-detect type (genuinely new code, not a refactor of Phase 1's `CMPedometer`-based `PedometerSession`/`StopwatchSession`/`LocationEnrichment` — their contracts don't stretch to cover six extensible activity types or continuous background classification), Swift Charts for history/progress visualization, and a pure-Swift greedy-algorithm plate calculator. No third-party dependency is required for any of it — Phase 2 can match Phase 1's zero-third-party-package precedent.

**Primary recommendation:** Build a new `RithamCore` guidance module (working name `GuidanceCatalog`, mirroring `ScreeningCopy`'s "transcribed verbatim, single source of truth" pattern) that expresses a `ContentPermission` axis (`none` / `educationOnly` / `full`) per `(ConditionTag, GuidanceDomain)`, keep all sensor/GPS/motion code in `RithamApp` (never `RithamCore`, matching Phase 1's Foundation-only-core discipline), do not integrate HealthKit as the system of record (SwiftData/`HealthDataStore` stays authoritative, per PROJECT.md's locked local-first decision — HealthKit write-out, if ever wanted, is additive and out of Phase 2 scope), and do not introduce any third-party Swift package.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cardio session GPS/motion measurement | Client (CoreLocation + CoreMotion) | — | Native sensor frameworks; CARDIO-02 makes GPS a first-class, user-facing feature (unlike Phase 1's calibration, where GPS was enrichment-only) — see Pattern 3's scope-boundary note |
| Auto-detect walk/run classification | Client (CoreMotion `CMMotionActivityManager`) | — | On-device classifier, no network call, matches CROSSGEN-02's "passive-first capture" |
| Cardio/strength session domain logic (qualification math, plate calculator, superset grouping, movement-pattern tagging) | Client (pure Swift, `RithamCore`) | — | No sensor/UI import, unit-testable in isolation, same discipline as Phase 1's `GateResolution` |
| Condition-tag-adjusted guidance *gating* (which domain is blocked) | Client (pure Swift, `RithamCore` — already built in Phase 1) | — | `GateResolution`/`GateEscalation` already implement this; Phase 2 reads, does not rebuild |
| Condition-tag-adjusted guidance *content* (what text/figures render) | Client (pure Swift, `RithamCore` — new in Phase 2) | — | New content-permission type + transcribed copy catalog, offline, no live AI generation (HEALTH-01's standing constraint still applies) |
| Session persistence (cardio sessions, lift sessions, sets, supersets) | Client (SwiftData, local-first) | Cloud sync (backup only, per PROJECT.md Key Decision) | Extends `HealthDataStore`'s existing facade pattern; local-first is a project-wide locked decision |
| Route/segment map rendering | Client (MapKit) | — | Native, no third-party mapping SDK; CARDIO-03's opt-in visibility is enforced at the data-sharing layer, not the rendering layer |
| History/progress charts | Client (Swift Charts) | — | Native, ships with SwiftUI since iOS 16 |
| "Always free" Settings list | Client (SwiftUI, extends `SettingsView`) | — | Static content, no new gating/paywall infrastructure exists anywhere in this product to reconcile against |
| HealthKit | **Out of scope this phase** | — | See Open Questions — recommended default is no HealthKit integration in Phase 2 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CoreLocation | Ships with iOS SDK | GPS pace/distance/elevation/splits for cardio sessions (CARDIO-02) | `[CITED: websearch]` Already used in `RithamApp/Ritham/Calibration/LocationEnrichment.swift` for enrichment; Phase 2 promotes it to a first-class tracked-session source. **Scope note:** `LocationEnrichment`'s comment forbidding `requestWhenInUseAuthorization`/`requestAlwaysAuthorization` is scoped to *calibration* (D-02's no-blocking-prompt rule) — it does not apply to Phase 2's cardio session, where GPS is the feature itself and prompting for authorization is expected and correct. |
| CoreMotion (`CMMotionActivityManager`) | Ships with iOS SDK | Auto-detect walk/run from motion sensors (CROSSGEN-02) | `[CITED: websearch, cross-referenced 2 sources]` Distinct class from Phase 1's `CMPedometer`. `CMMotionActivity` exposes non-exclusive `walking`/`running`/`stationary`/`automotive`/`cycling` booleans plus a `.low`/`.medium`/`.high` `confidence` enum that ramps up over roughly 5-15s of sustained activity — this confidence signal is a natural fit for CARDIO-02's "visible confidence indicator" requirement applied to auto-detect specifically (distinct from GPS accuracy confidence). Requires the same `NSMotionUsageDescription` already declared in `Info.plist` since Phase 1 — no new usage-description string needed. |
| Swift Charts | Ships with iOS 16+ SDK | Workout history/progress visualization | `[CITED: websearch, cross-referenced 3 sources]` Native `Chart`/`LineMark`/`BarMark` declarative API, no third-party charting dependency required for CARDIO-01's "full training history" or STRENGTH-04's "filterable in history/progress charts." |
| MapKit | Ships with iOS SDK | Route rendering for CARDIO-03's opt-in route/segment comparison | `[ASSUMED]` Standard native choice for on-device map rendering; not independently researched this session since it's an uncontroversial default (Apple's own first-party map framework, already how every native iOS fitness app renders routes). Flagged `[ASSUMED]` rather than `[CITED]` because no search was run specifically confirming this over an alternative — there is no serious alternative for on-device iOS map rendering that isn't third-party, so this is very low risk. |
| SwiftData | Ships with iOS 17+ SDK (already in use) | Cardio/strength session persistence, extending `HealthDataStore` | `[CITED: Phase 1 precedent]` Already the project's locked persistence choice (`01-RESEARCH.md`); Phase 2 adds new `@Model` types and `HealthDataStore` methods following the exact same facade pattern, not a new persistence technology. |
| Swift Testing | Ships with Xcode 16+ | Unit tests for plate calculator, gate-content lookups, session qualification math | `[CITED: Phase 1 precedent]` Same testing framework already established; `RithamCore/Scripts/test-core.sh`'s toolchain-adaptive harness already exists and should be reused, not rebuilt. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `CLLocation.distance(from:)` | Ships with SDK | Cumulative distance from filtered GPS points | Standard API for point-to-point distance; accumulate across an accuracy-filtered stream rather than computing from raw unfiltered points (see Common Pitfalls) |
| `CMAltimeter` (`isRelativeAltitudeAvailable`) | Ships with SDK | Barometric relative-altitude stream, a candidate elevation source for grade-adjusted pace | `[ASSUMED]` — worth verifying during planning whether barometric altitude (already-declared Motion & Fitness authorization) is a better GAP input than `CLLocation.verticalAccuracy`/`.altitude`, which is materially noisier than horizontal GPS accuracy on iPhone. Not independently confirmed this session — flagged as an implementation detail for the planner, not a locked recommendation. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Swift Charts | DGCharts (formerly Charts, danielgindi) or a similar third-party charting library | Third-party library adds a dependency, a maintenance/security-review surface, and breaks Phase 1's zero-third-party-package precedent for no capability Swift Charts lacks for this phase's needs (line/bar charts over workout history). Only reconsider if a specific chart type genuinely isn't expressible in Swift Charts — not identified as a gap this session. |
| CoreLocation-native GPS smoothing (accuracy-threshold filtering) | A hand-rolled Kalman or Hampel filter over the raw location stream | `[CITED: websearch]` Kalman/Hampel filtering is a real numerical technique with genuine bug surface (tuning, edge cases, testing difficulty) and no first-party Apple implementation to lean on. CARDIO-02's own requirement — a **visible confidence indicator** instead of a silently-varying number — exists precisely so Ritham doesn't need to hide GPS noise behind a smoothing algorithm. Recommend accuracy-threshold filtering (discard points beyond a horizontalAccuracy threshold) + confidence-indicator UI instead; treat true Kalman-filtered smoothing as a v2 enhancement, not Phase 2 scope. |
| HealthKit as the system of record for workout data | Continue with SwiftData/`HealthDataStore` as sole store, optionally write-out to HealthKit later | See Open Questions — HealthKit adds an entitlement, additional usage-description strings, App Store privacy-nutrition-label disclosures, and expands LAUNCH-04's GDPR/CCPA review surface for no capability this phase's success criteria require (nothing in Phase 2's success criteria asks for cross-app HealthKit interoperability) |

**Installation:**
No package manager installation is required — every recommendation above ships with the Apple SDK. This phase can match Phase 1's precedent of zero third-party Swift packages.

**Version verification:** All frameworks above are Apple first-party, tied to the OS/Xcode SDK version rather than an independently versioned package (no `npm view`-equivalent registry check applies). The project's confirmed toolchain this session: Xcode 26.6, iOS 17.0 deployment target, Swift 6.0 with `SWIFT_STRICT_CONCURRENCY: complete` (`RithamApp/project.yml`, `RithamCore/Package.swift`) — unchanged from Phase 1, no upgrade needed for anything in this phase.

## Package Legitimacy Audit

**Zero third-party Swift packages are recommended for this phase**, matching Phase 1's iOS-target precedent (Phase 1's only third-party candidates were for a backend service that no longer exists post-D-14). Every capability CARDIO-01/02/03, STRENGTH-01 through 05, and the guidance-content catalog need is covered by first-party Apple frameworks (CoreLocation, CoreMotion, MapKit, Swift Charts, SwiftData) or pure Swift domain logic.

**Tooling limitation, stated explicitly:** the `gsd-tools query package-legitimacy check` seam supports only `npm`, `pypi`, and `crates` ecosystems — it has no Swift Package Manager (SPM) support. If the planner or a future phase does introduce an SPM candidate (e.g., a charting or mapping library), it **cannot** be machine-verified by this project's tooling; verification must be manual (GitHub repo activity, maintainer reputation, star count/issue responsiveness, license) and should still be gated behind a `checkpoint:human-verify` task per the spirit of the protocol, even though the automated seam can't produce a verdict.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| *(none)* | SPM | — | — | — | N/A | No third-party package recommended; all Phase 2 capability needs are covered by first-party Apple frameworks |

**Packages removed due to `[SLOP]` verdict:** none — no candidate packages were proposed.
**Packages flagged as suspicious `[SUS]`:** none.
**Candidate considered and rejected (not `[SLOP]`/`[SUS]`, a design choice):** DGCharts/Charts (third-party charting) — rejected in favor of Swift Charts; see Alternatives Considered above. Not run through the legitimacy seam since it was never a serious candidate.

## Architecture Patterns

### System Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────┐
│  iOS App (SwiftUI, local-first, works fully offline)                       │
│                                                                              │
│  ── Cardio session ─────────────────────────────────────────────────────   │
│  Activity-type picker (Run/Walk/Cycle/Hike/Swim/Elliptical/…)              │
│         │                                                                   │
│         ├─▶ Manual stopwatch (start/pause/stop) ──────────────┐            │
│         │                                                       │            │
│         ├─▶ CoreLocation GPS stream ──▶ accuracy-filter ──▶     │            │
│         │      distance(from:) accumulation ──▶ pace/splits ──▶│            │
│         │      grade-adjusted pace (± CMAltimeter input) ──────┤            │
│         │                                                       │            │
│         └─▶ CMMotionActivityManager (auto-detect) ──▶ confidence│            │
│                (walking/running, .low/.medium/.high) ───────────┤            │
│                                                                   ▼           │
│                                          CardioSession (RithamCore model)    │
│                                                   │                          │
│  ── Strength session ─────────────────────────────┤                        │
│  Exercise picker ──▶ auto-fill last weight/reps ──┤                        │
│         │                                          │                        │
│         ├─▶ PlateCalculator (pure Swift, RithamCore)                       │
│         │      barbell/EZ/trap/Smith/stack ──▶ nearest loadable weight     │
│         │                                          │                        │
│         ├─▶ Superset grouping (tap "add to superset")                      │
│         │                                          │                        │
│         └─▶ Movement-pattern auto-tag (push/pull/squat/hinge/carry) ───────┤
│                                                   ▼                          │
│                                          LiftSession (RithamCore model)     │
│                                                   │                          │
│  ── Guidance layer (reads Phase 1's screening output) ────────────────────  │
│  HealthDataStore.activeConditionTags(now:) ──▶ ConditionTag set            │
│         │                                                                   │
│         ▼                                                                   │
│  GateResolution / GateEscalation.baseGates (Phase 1, unchanged) ──▶         │
│         DomainGates (workout, nutrition)                                    │
│         │                                                                   │
│         ▼                                                                   │
│  NEW: GuidanceCatalog.contentPermission(for: tag, domain:) ──▶              │
│         ContentPermission (.none / .educationOnly / .full)                  │
│         │                                                                   │
│         ▼                                                                   │
│  NEW: GuidanceCatalog copy lookup (workout adjustment text,                 │
│         contraindicated list, nutrition guidance text) ──▶                  │
│         dietary-pattern-keyed food swap (DIET-02, gate-conditional)         │
│         + nutrient-education block (DIET-03, NOT gate-conditional) ──▶      │
│         Rendered guidance, always paired with the persistent disclaimer     │
│         tag (ConditionDisclaimerTag, reused from Phase 1)                   │
│                                                                              │
│  SwiftData write (CardioSession, LiftSession, LiftSet) via                  │
│  HealthDataStore's existing facade pattern ──▶ full local training history  │
└───────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
RithamCore/Sources/RithamCore/
├── Cardio/
│   ├── ActivityType.swift           # extensible enum: run/walk/cycle/hike/swim/elliptical/…
│   ├── CardioSession.swift          # duration, distance, splits, source (GPS/manual/auto-detected)
│   └── GradeAdjustedPace.swift      # pure math: grade % + pace → adjusted pace, per researched GAP curve
├── Strength/
│   ├── Equipment.swift              # barbell/EZ/trap/Smith/stack enum + known plate denominations
│   ├── PlateCalculator.swift        # pure Swift greedy algorithm, no UI/SwiftData import
│   ├── Superset.swift               # grouping key/model for STRENGTH-03
│   ├── MovementPattern.swift        # push/pull/squat/hinge/carry + exercise lookup table (STRENGTH-04)
│   └── LiftSession.swift            # sets, exercises, auto-fill lookup contract
├── Guidance/
│   ├── ContentPermission.swift      # NEW: .none / .educationOnly / .full, keyed per (ConditionTag, GuidanceDomain)
│   ├── WorkoutGuidanceCatalog.swift # transcribed verbatim from docs/health-screening.md §2 (HEALTH-03)
│   ├── NutritionGuidanceCatalog.swift # transcribed verbatim from §3 (HEALTH-04)
│   └── DietarySwapCatalog.swift     # transcribed from docs/dietary-pattern.md §3/§4 (DIET-02, DIET-03)
└── Tests/RithamCoreTests/
    ├── PlateCalculatorTests.swift
    ├── GuidanceCatalogTests.swift   # asserts every ConditionTag has a ContentPermission entry per domain
    └── ...

RithamApp/Ritham/
├── Cardio/
│   ├── GPSTrackingSession.swift     # CoreLocation wrapper, NEW type — first-class GPS, not enrichment-only
│   ├── MotionActivityDetector.swift # NEW type wrapping CMMotionActivityManager, distinct from PedometerSession
│   ├── StopwatchCardioSession.swift # manual fallback, same pattern as Phase 1's StopwatchSession but for CardioSession
│   └── Views/                       # activity picker, live session screen, route map (MapKit)
├── Strength/
│   ├── Views/                       # exercise picker, set logging, plate calculator UI, superset builder
├── Guidance/
│   └── Views/                       # workout/nutrition guidance screens, reusing Disclaimers/ components from Phase 1
├── Charts/
│   └── Views/                       # Swift Charts-based history/progress views
├── Persistence/
│   └── SwiftDataModels/             # CardioSessionRecord, LiftSessionRecord, LiftSetRecord (@Model, extends HealthDataStore)
└── Settings/
    └── AlwaysFreeListView.swift     # MONETIZE-01, extends existing SettingsView
```

### Pattern 1: Guidance content permission downstream of the existing gate

**What:** A new `ContentPermission` enum (`.none`, `.educationOnly`, `.full`) keyed per `(ConditionTag, GuidanceDomain)`, computed *after* `GateResolution`/`GateEscalation` have already run — never replacing them, never feeding back into them.

**When to use:** Every place Phase 2 renders workout or nutrition guidance text. This is the direct answer to whether the existing `ConditionTag`/`ClearanceGate`/`GateResolution` API surface is sufficient: **the gating logic is complete and correct as-is; only the content-selection layer is missing.**

**Why it's needed, not optional:** `GateEscalation.swift`'s own header comment on the `hypertensionUncontrolledOrUnsure` case states the gap directly: "the three-level gate has no narrower state than requiredBlocking to express 'no quantity, but generic education still allowed'; that nuance is content-layer, not gate-level." Concretely, `blocksPersonalization(in: .nutrition) == true` means two different things depending on the tag:
- Kidney Disease, Pregnancy — Complicated/Unsure, Eating Disorder History — Positive Screen → **zero** content of any kind, including general framework education (§3's own wording: "including general framework content")
- Under-18 (Minor), Hypertension — Uncontrolled/Unsure, Postpartum — Uncomplicated (for the weight-loss-goal feature specifically) → generic **education** permitted, only numeric quantities withheld

**Example:**
```swift
// RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift
// New in Phase 2 — sits downstream of DomainGates, never upstream.
public enum ContentPermission: Sendable, Equatable {
    case none            // zero content of any kind, generic-blocking message only
    case educationOnly   // generic education permitted, zero personalized numbers
    case full            // full personalized content per this tag's rule-table row
}

public enum GuidanceCatalog {
    // One entry per ConditionTag, per domain — transcribed from docs/health-screening.md
    // §2 (workout) / §3 (nutrition) Clearance Gate column PLUS the row's own prose,
    // which is where the none-vs-educationOnly distinction actually lives.
    public static func contentPermission(
        for tag: ConditionTag,
        domain: GuidanceDomain
    ) -> ContentPermission {
        // exhaustive switch, one case per ConditionTag — see Common Pitfalls for why
        // this must never derive mechanically from ClearanceGate alone
    }
}
```

### Pattern 2: Guidance-text catalog mirrors `ScreeningCopy`'s "transcribed verbatim" discipline

**What:** Every workout-adjustment sentence, contraindicated-activity list, nutrition-guidance sentence, and dietary-pattern food swap is transcribed **verbatim** from `docs/health-screening.md` §2/§3 and `docs/dietary-pattern.md` §3/§4 into a `RithamCore` catalog type — never paraphrased, never live-generated.

**When to use:** Any guidance text HEALTH-03/HEALTH-04/DIET-02/DIET-03 render. This is the same discipline `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift` and `OnboardingCopy.swift` already established in Phase 1 (their own header comment: "transcribed verbatim... pending LAUNCH-01/LAUNCH-02 review... ship as-is per the roadmap's own sequencing"). HEALTH-01's standing constraint — "never free text, never live AI-generated advice" — extends structurally to this content: it must be static, reviewable text, not generated per-user.

**Example:**
```swift
// RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift
// Source: docs/health-screening.md §2. Pending LAUNCH-01/02/03 review like ScreeningCopy —
// ships as-is per the roadmap's sequencing (Phase 5 gates the review, not Phase 2 build).
public enum WorkoutGuidanceCatalog {
    public static func adjustment(for tag: ConditionTag) -> String? { ... }
    public static func contraindicated(for tag: ConditionTag) -> String? { ... }
}
```

### Pattern 3: New sensor-adapter types for cardio, not a refactor of Phase 1's `CalibrationSession`

**What:** A new `MotionActivityDetector` (wrapping `CMMotionActivityManager`) and a new first-class `GPSTrackingSession` (wrapping `CLLocationManager`, promoted from Phase 1's enrichment-only `LocationEnrichment`) — both distinct types from Phase 1's `PedometerSession`/`StopwatchSession`/`LocationEnrichment`, not extensions or refactors of them.

**When to use:** All of CARDIO-01/02/03 and CROSSGEN-02's live cardio-session sensor code.

**Why duplication is correct here, not accidental:** Phase 1's `CalibrationSessionSource` protocol and `CalibrationProgress`/`CalibrationMode` types are shaped around a single yes/no completion question ("did 10+ continuous minutes or 3+ working sets happen") for exactly two modes (`.walk`, `.lift`). CARDIO-01 needs six *extensible* activity types with live pace/distance/elevation/splits — a materially different shape, not a natural extension of `CalibrationMode`. Similarly, `CMPedometer` (Phase 1) reports step count/distance for walking specifically; `CMMotionActivityManager` (Phase 2) classifies *which* activity is happening (walking vs. running vs. stationary vs. cycling) with a confidence level — a different CoreMotion API for a different question. **Do not** attempt to unify these under one shared sensor abstraction this phase; the completion-gate contract Phase 1 built (`CalibrationSessionSource`) is not the right shape for a live, multi-activity-type, GPS-enriched cardio session.

**What genuinely should be reused, not duplicated:**
- `CalibrationThreshold`'s constants (`qualifyingWalkDuration`, `qualifyingWorkingSets`, `qualifyingExercises`) — that file's own comment states "Phase 3's Momentum qualifying-session bar should reference these same constants rather than restating the numbers." Phase 2's `CardioSession`/`LiftSession` qualification math should be shaped so it can be evaluated against these same constants later, without duplicating the numbers.
- Phase 1's disclaimer components (`ConditionDisclaimerTag`, `RequiredBlockingMessageView`, `StandingFooterDisclaimer`) — reuse verbatim wherever Phase 2 renders adjusted guidance; do not rebuild disclaimer UI.
- The `HealthDataStore` facade pattern (one class, one `ModelContext`, typed error enum) — extend it with new methods for cardio/lift sessions, don't create a second store.

**Critical scope-boundary correction:** `LocationEnrichment.swift`'s comment ("must never call `requestWhenInUseAuthorization`") is scoped to *calibration's* D-02 no-blocking-prompt rule. It does **not** generalize to Phase 2. CARDIO-02 makes GPS a first-class, user-requested feature — Phase 2's `GPSTrackingSession` **is** expected to request location authorization (When In Use, at minimum) when the user starts a GPS-tracked session. The manual-stopwatch path is what preserves "the app is fully functional phone-only" (per PROJECT.md's monetization-boundary constraint), not a blanket ban on ever prompting for location.

### Pattern 4: Plate calculator as a pure-Swift greedy algorithm

**What:** `(targetWeight - barWeight) / 2` per side, greedily filled from the largest available plate denomination down to the smallest, rounding the target to the nearest achievable increment (2× the smallest available plate) when an exact match isn't loadable.

**When to use:** STRENGTH-02, across barbell/EZ bar/trap bar/Smith machine/stack-machine equipment types.

**Example:**
```swift
// Source: WebSearch, cross-referenced across multiple plate-calculator implementations
// (see Sources) — standard, well-precedented algorithm, no ambiguity in approach.
public struct PlateCalculator {
    public static func nearestLoadablePlates(
        target: Double,
        barWeight: Double,
        availablePlates: [Double] // sorted descending, e.g. [25, 20, 15, 10, 5, 2.5, 1.25]
    ) -> (plates: [Double], achievedWeight: Double) {
        let perSideTarget = max(0, (target - barWeight) / 2)
        var remaining = perSideTarget
        var used: [Double] = []
        for plate in availablePlates {
            while remaining >= plate {
                used.append(plate)
                remaining -= plate
            }
        }
        let achievedPerSide = used.reduce(0, +)
        let achievedWeight = barWeight + achievedPerSide * 2
        return (used, achievedWeight)
    }
}
```
**Equipment-specific note:** Smith machines and some trap bars have their own fixed bar weight and, per STRENGTH-02's "nearest loadable weight" requirement, stack machines don't take plates at all — they select from a fixed pin-weight increment list, which is a different (simpler) lookup, not a plate-greedy algorithm. The `Equipment` enum should model this distinction explicitly rather than forcing stack machines through the plate-math path.

### Anti-Patterns to Avoid

- **Deriving `ContentPermission` mechanically from `ClearanceGate`:** e.g. `none → .full, recommended → .full, requiredBlocking → .none` would be wrong for at least Under-18/Hypertension-Uncontrolled/Postpartum-Uncomplicated, whose `requiredBlocking` nutrition gate still permits generic education. `ContentPermission` must be its own per-tag lookup, transcribed from the rule tables' prose, not computed from the gate enum.
- **Treating DIET-02 and DIET-03 as equally gate-conditional:** DIET-02 (food-swap examples) renders only when the gate is `none`/`recommended`; DIET-03 (nutrient-education blocks) renders unconditionally, "identical regardless of any condition tag also present" per `docs/dietary-pattern.md` §4's own text and REQUIREMENTS.md's DIET-03 wording. A single `if gate == .requiredBlocking { hideEverything }` check would silently break DIET-03 for every user with any required-blocking nutrition tag.
- **Reusing `CalibrationSessionSource`/`CalibrationMode` for cardio sessions:** its two-case, single-completion-boolean shape doesn't extend to six activity types and live multi-metric tracking. See Pattern 3.
- **Applying `LocationEnrichment`'s no-authorization-request rule to Phase 2's GPS tracking:** that rule is calibration-scoped (D-02), not product-wide. See Pattern 3's scope-boundary note.
- **Value-typed `LiftSet` children with no independent identity:** STRENGTH-05 requires merging and splitting sessions after the fact — sets need stable identity (a SwiftData `@Model` with its own persistent identifier) that can be reparented to a different session, not a value type embedded inline in a session's array.
- **A single `movementPattern: MovementPattern` (singular) property on an exercise:** real exercises are frequently multi-pattern (a thruster is squat+push; a deadlift is hinge, arguably also carry-adjacent). Modeling this as a single case will misfile filterable-history queries for any compound movement — see Open Questions.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GPS noise smoothing | A custom Kalman or Hampel filter over the raw location stream | Accuracy-threshold filtering (discard points beyond a horizontalAccuracy threshold) + `CLLocation.distance(from:)` accumulation + a visible confidence indicator | `[CITED: websearch]` Kalman filtering has real tuning/testing complexity and no first-party implementation; CARDIO-02's own requirement (a visible confidence indicator, not a silently-varying number) is specifically designed to avoid needing this. Revisit as a genuine v2 enhancement only if user feedback demands tighter smoothing. |
| Workout history charts | Custom `Canvas`-drawn line/bar charts | Swift Charts (`Chart`/`LineMark`/`BarMark`) | Native framework built exactly for this, zero dependency cost |
| Plate-math nearest-loadable-weight calculation | Reach for a third-party fitness-calculator package | Hand-rolled greedy algorithm (Pattern 4) | This one is *correctly* hand-rolled — it's genuinely simple, well-understood domain logic (bounded loop over a sorted plate list), not a case where a library saves meaningful complexity or risk. Listed here to make the distinction explicit: "don't hand-roll" doesn't mean "never write simple domain logic yourself." |
| Guidance-content permission/copy lookup | A rules engine or JSON-driven content system | A plain Swift `enum`/switch catalog, transcribed verbatim (Pattern 1/2) | HEALTH-01's constraint (never live-generated, never free text) is best satisfied by code that's compiled, reviewable, and diffable — a data-driven rules engine adds indirection with no corresponding benefit for a fixed, ~31-tag, 2-domain matrix that changes only via a real code review (and per-tag content is exactly what Phase 5's LAUNCH-01/02/03 legal/clinical review needs to review against a diff). |

**Key insight:** Nearly everything client-side in this phase has a first-party Apple framework or a genuinely simple, bounded piece of domain logic behind it — same pattern Phase 1 found. The one place real engineering judgment is needed is the guidance content-permission layer, precisely because it's new domain modeling on top of an already-correct gate layer, not a "grab a library" problem.

## Common Pitfalls

### Pitfall 1: Conflating `ClearanceGate` with the content-permission axis Phase 2 needs

**What goes wrong:** An engineer reads `blocksPersonalization(in: .nutrition) == true` and hides all content for that tag, breaking DIET-03 (which must still render) and under-serving Under-18/Hypertension-Uncontrolled/Postpartum users who are entitled to generic education under a `requiredBlocking` nutrition gate.
**Why it happens:** `ClearanceGate` has only three cases and reads as if it should directly gate content visibility; the "no quantity, but generic education still allowed" nuance is documented only in `GateEscalation.swift`'s comments and the rule tables' prose, not in the type system.
**How to avoid:** Build the new `ContentPermission` type (Pattern 1) as its own per-tag, per-domain lookup, transcribed from the rule tables directly — never derived by a formula from `ClearanceGate`.
**Warning signs:** Any code that computes guidance visibility as `gate == .requiredBlocking ? hideAll : showAll`.

### Pitfall 2: Silently under-restricting the Under-18 nutrition block by using a stale in-memory age instead of the stored, re-derived condition tag

**What goes wrong:** Phase 1's `TagDerivation.deriveTags` already derives `.under18Minor` correctly from `answers.age < 18` at every screening/re-screening event (confirmed in the committed source, plan 01-06 closed this exact gap) and persists it as a `ConditionTagRecord` subject to the same 12-month expiry/D-08 "keep applying while overdue" logic as every other tag. Phase 2 code that reads `profile.age` directly and re-derives Under-18 status itself (instead of reading `HealthDataStore.activeConditionTags`) risks drifting from the single source of truth and double-implementing logic that already exists.
**Why it happens:** It's tempting to think "age is a simple number, I can just check `< 18` inline" without realizing the tag's lifecycle (expiry, D-08's stale-but-still-applied rule, re-derivation at re-screen) is already fully modeled elsewhere.
**How to avoid:** Phase 2's guidance layer should always read condition tags via `HealthDataStore.activeConditionTags(now:)`, never re-derive age-based tags independently.
**Warning signs:** Any Phase 2 file importing `UserProfile.age` directly to make a guidance decision, rather than going through the tag layer.

### Pitfall 3: HealthKit treated as a persistence layer instead of a data source

**What goes wrong:** `[CITED: websearch]` HealthKit queries are asynchronous and relatively expensive; querying it on every view render (rather than treating it as a one-time-sync data source) is a documented, repeated production failure mode across HealthKit-integrated apps.
**Why it happens:** HealthKit's `HKWorkout` model looks like it could just *be* the app's workout store, since it's already there and free.
**How to avoid:** If HealthKit integration is ever added (recommended out of scope for Phase 2 — see Open Questions), the correct pattern is: query/observe HealthKit once, transform into the app's own domain model, persist that domain model in SwiftData, and render from the local store — never query HealthKit per-render.
**Warning signs:** Any SwiftUI view directly awaiting an `HKSampleQuery` in its body/`onAppear`.

### Pitfall 4: GPS battery drain from unnecessary continuous background tracking

**What goes wrong:** `[CITED: websearch]` `allowsBackgroundLocationUpdates` defaults to `false` and should stay `false` outside an actively-tracked session; leaving continuous high-accuracy location updates running (rather than scoping them to the duration of a tracked cardio session, with `pausesLocationUpdatesAutomatically = true` and `activityType = .fitness`) drains battery and risks App Store review pushback on background-location justification.
**Why it happens:** It's easy to request background updates "just in case" rather than scoping precisely to the tracked-session lifecycle.
**How to avoid:** Request location authorization and start updates only when a GPS-tracked cardio session begins; stop updates when the session ends or pauses; set `activityType = .fitness` and `pausesLocationUpdatesAutomatically = true`.
**Warning signs:** `CLLocationManager.startUpdatingLocation()` called anywhere outside an active session's start/stop lifecycle.

### Pitfall 5: Grade-adjusted pace confidence hidden behind a number instead of surfaced

**What goes wrong:** GAP's input is *grade* (elevation change over distance), which depends on `CLLocation.verticalAccuracy`/altitude — materially noisier on iPhone GPS than `horizontalAccuracy`. Silently computing and displaying a GAP number when the underlying elevation signal is low-confidence reproduces exactly the "silently varying number" problem CARDIO-02 exists to fix, just for grade instead of pace/distance.
**Why it happens:** It's easy to treat GAP as "just apply the formula to whatever altitude reading is available" without separately gating on elevation-signal confidence.
**How to avoid:** Track elevation-signal confidence independently from horizontal-position confidence (consider `CMAltimeter`'s barometric relative-altitude stream as a steadier input than `CLLocation.altitude`, per the Standard Stack note); suppress or clearly down-weight GAP display when elevation confidence is poor, rather than showing a number computed from noisy input.
**Warning signs:** A GAP value displayed with the same confidence badge as raw pace/distance, with no separate signal for elevation-data quality.

## Code Examples

See Architecture Patterns above for the four load-bearing patterns (content-permission layer, guidance-copy catalog, new sensor adapters, plate calculator) with inline source annotations.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `CMPedometer` for step/distance-based walk detection (Phase 1's calibration) | `CMMotionActivityManager` for live activity-type classification with a confidence level (Phase 2's auto-detect) | N/A — these are two different, coexisting CoreMotion APIs for two different questions, not a version succession | Phase 2 should not treat this as "the newer API" replacing Phase 1's choice; both remain correct for their respective use cases |
| Third-party charting libraries (DGCharts era) | Swift Charts (native, since iOS 16/WWDC22) | 2022, matured through 2024-2026 | Removes a dependency Phase 1's precedent already avoided elsewhere |
| Strava's undocumented, closed GAP formula | Published Minetti et al. (2002) cost-of-transport-vs-grade curve as the grounding research | Minetti's research is from 2002; Strava's public blog posts reference it without publishing exact coefficients | Ritham should build GAP from the published Minetti curve/approximation (uphill ~2.5%/1% grade, downhill ~1.5%/1% grade to about -10%, steepening past that), not attempt to reverse-engineer Strava's exact proprietary formula |

**Deprecated/outdated:** Nothing project-specific to flag here beyond what Phase 1 already noted (SwiftData over Core Data, `NavigationStack` over `NavigationView`) — both remain current and apply unchanged to Phase 2's new screens.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | MapKit is the correct native choice for CARDIO-03's route rendering, with no serious on-device alternative worth researching | Standard Stack | Very low risk — no credible non-third-party alternative exists for iOS map rendering; flagged `[ASSUMED]` only because it wasn't independently searched this session, not because there's real doubt |
| A2 | `CMAltimeter`'s barometric relative-altitude stream is a better GAP elevation input than `CLLocation.altitude`/`verticalAccuracy` | Standard Stack, Pitfall 5 | Medium — if wrong, the planner should default to `CLLocation`'s own altitude field and gate GAP display on `verticalAccuracy` directly instead; either way, the "don't show GAP without confidence gating" recommendation holds regardless of which elevation source wins |
| A3 | Zero third-party Swift packages are sufficient for every Phase 2 capability, matching Phase 1's precedent | Package Legitimacy Audit | Low — if a genuine gap emerges during planning (e.g., a chart type Swift Charts can't express), the fallback is manual SPM vetting per the stated tooling limitation, not a silent dependency addition |
| A4 | HealthKit integration is out of scope for Phase 2 and the recommended default is "don't build it this phase" | Architectural Responsibility Map, Open Questions | Medium — this is presented as a recommendation for discuss-phase to confirm, not a locked decision; if the user wants HealthKit write-out in Phase 2 specifically (e.g., for Apple Watch pairing down the line), this assumption should be revisited before planning locks in |
| A5 | Movement-pattern tagging (STRENGTH-04) needs a `Set<MovementPattern>` per exercise, not a single `MovementPattern`, to handle compound movements correctly | Anti-Patterns, Open Questions | Medium — if the product intent is genuinely single-pattern-per-exercise (simpler UX, accept some mis-filing on compound movements), this assumption over-engineers the model; flagged as an Open Question rather than decided here |

**If this table is empty:** N/A — see entries above; A1/A3 are low-risk and can proceed straight to planning; A2/A4/A5 should get at least a light confirmation pass during `/gsd-discuss-phase 2`.

## Open Questions for Discussion

1. **Should Phase 2 write workout data to HealthKit, or stay SwiftData-only?**
   - What we know: HealthKit is a shared data source with real cross-app-interoperability value (Apple Watch pairing, other fitness apps, Apple's own Fitness app), but it's architecturally a source to read from/write summaries to, not a replacement for the app's own domain-model store. Integrating it adds an entitlement, additional Info.plist usage-description strings, App Store privacy-nutrition-label disclosures, and expands LAUNCH-04's GDPR/CCPA privacy-review surface — the same category of cost that led to deferring menstrual cycle tracking to v2.
   - What's unclear: Whether the product roadmap wants HealthKit interoperability (e.g., for a future Apple Watch companion) sooner rather than later, which would argue for building the write-out path now while the session/set data model is being designed, even if the UI/toggle ships later.
   - Recommendation: Default to **no HealthKit integration in Phase 2** — SwiftData/`HealthDataStore` stays the sole system of record, consistent with PROJECT.md's locked "local-first, cloud sync is backup not source of truth" decision. Revisit as an explicit, opt-in v2/v3 feature. This should be confirmed, not assumed, before planning locks in the session data model (adding HealthKit write-out later is additive if the domain model doesn't already bake in a hard HealthKit dependency).

2. **Does GPS tracking require a blocking location-permission prompt before a cardio session can start, or must the manual stopwatch remain the zero-permission first-run path?**
   - What we know: PROJECT.md's monetization boundary states "the app must be fully functional and accurate phone-only" — the manual stopwatch must work standalone, matching Phase 1's D-02 pattern for calibration. CARDIO-02 makes GPS pace/distance/elevation a first-class feature, unlike Phase 1's GPS-as-enrichment-only design.
   - What's unclear: Whether the activity-type picker's default UX should route straight into a GPS permission prompt (with manual stopwatch as a fallback if denied) or present GPS as an opt-in toggle within a stopwatch-first flow. This is a product/UX decision, not purely technical.
   - Recommendation: Claude's Discretion during planning, informed by the constraint that manual stopwatch must never be blocked by a permission decision — but flag for `/gsd-discuss-phase 2` since it affects first-session UX materially.

3. **Does a single exercise get one `MovementPattern` or a `Set<MovementPattern>`?**
   - What we know: `docs/roadmap.md` reads singular ("push/pull/squat/hinge/carry"), but real compound exercises (a thruster: squat+push; a deadlift: hinge, arguably carry-adjacent) don't fit a single-pattern model cleanly, and STRENGTH-04 explicitly requires the tag to be "filterable in history" — a query like "how much have I pushed this month" needs every genuinely-push exercise correctly tagged, including compound ones.
   - What's unclear: Whether the product wants strict single-pattern simplicity (accepting some mis-filing) or multi-pattern accuracy (more complex filter UI: does a thruster count toward both "push" and "squat" totals?).
   - Recommendation: Lean toward `Set<MovementPattern>` per exercise for correctness, but this is a real UX tradeoff (filter-list complexity) worth a direct product decision, not silently decided by research.

4. **What counts as "route/segment comparison" for CARDIO-03, and how does its opt-in boundary avoid drifting toward the permanently-prohibited cross-user aggregate location visualization?**
   - What we know: CARDIO-03 requires route/segment comparison to be opt-in only, no default public leaderboard. PROJECT.md and ROADMAP.md both state, as a **permanent, milestone-independent product exclusion**: "Ritham will never build a cross-user aggregate location visualization (no heatmap, no 'most active area' feature)" — this is explicitly modeled against the real-world Strava heatmap incident.
   - What's unclear: The exact shape of "segment comparison" Phase 2 should build — a single user's own repeated-route history (clearly safe, single-user, no cross-user aggregation) vs. any feature that compares a user's segment time against other users' times on the same route (closer to Strava's segment-leaderboard model, which is explicitly named as the thing Ritham's product research reacted against: "Strava's segment-chasing culture is directly linked... to users quitting over it").
   - Recommendation: Scope Phase 2's CARDIO-03 implementation to **single-user route history only** (a user comparing their own past runs on a route they've repeated) unless `/gsd-discuss-phase 2` explicitly confirms a cross-user comparison feature is in scope — and if it is, that feature must be individually opt-in per comparison, never a standing aggregate/heatmap, and never default-visible.

5. **How does the guidance layer handle a user with zero condition tags (the "None of the Above / Baseline" case) vs. an unscreened user?**
   - What we know: Every screened user resolves to at least `noneOfTheAboveBaseline` if nothing else matched (per `docs/health-screening.md`'s condition checklist having a "None of the above" option), and `GateEscalation.baseGates(for: .noneOfTheAboveBaseline)` should return `.none`/`.none` (full personalization both domains) — this wasn't independently re-verified this session but follows directly from the rule table.
   - What's unclear: Whether Phase 2 needs to handle a state where `HealthDataStore.activeConditionTags` returns an *empty* set (e.g., a user who somehow reaches the cardio/strength screens before ever completing screening, if that's reachable given Phase 1's flow) distinctly from a user who completed screening and got `noneOfTheAboveBaseline`.
   - Recommendation: Verify during planning whether Phase 1's onboarding flow makes an empty-tag-set state reachable at all before Phase 2's tracking screens are accessible; if it is reachable, the guidance layer needs an explicit "no screening data" fallback distinct from "screened, baseline."

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / iOS SDK | Entire phase | ✓ | Xcode 26.6, iOS 17.0 deployment target, Swift 6.0 (confirmed this session via `xcodebuild -version`) | — |
| iOS Simulators | Local dev/test iteration | ✓ | Multiple iPhone 17-family simulators available (confirmed via `xcrun simctl list devices available`) | — |
| CoreLocation / CoreMotion frameworks | CARDIO-02, CROSSGEN-02 | ✓ | Ships with SDK; `NSMotionUsageDescription`/`NSLocationWhenInUseUsageDescription` already declared in `Info.plist` since Phase 1 — no new usage-description string needed | — |
| Physical device for GPS/motion testing | CARDIO-02, CROSSGEN-02 | ✗ (not verified this session — no physical device confirmed connected) | — | iOS Simulator cannot produce real GPS movement or real `CMMotionActivityManager` classification (same Pitfall 4 limitation Phase 1's `01-RESEARCH.md` documented for `CMPedometer`) — on-device testing (or Xcode's GPX-file location simulation for basic GPS-path testing) is required before this phase can be considered validated, not just compiled |
| HealthKit entitlement/capability | Only if Open Question 1 resolves toward HealthKit integration | ✗ (not currently configured in `project.yml`/entitlements) | — | Default recommendation is no HealthKit this phase (see Open Questions) — if reversed, Wave 0 must add the capability, entitlement, and additional usage-description strings |

**Missing dependencies with no fallback:** None that block Phase 2 outright — the physical-device gap is a testing-completeness concern (same category Phase 1 already documented for `CMPedometer`), not a build blocker.

**Missing dependencies with fallback:** Physical-device GPS/motion testing — Simulator + GPX-file location simulation covers basic-path testing; full validation still needs a real device pass, same as Phase 1's calibration sensors.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16+) for unit/business-logic tests — same as Phase 1, no change |
| Config file | `RithamCore/Package.swift` (package tests), `RithamApp/project.yml` (app-target tests via xcodegen) — both already exist, no new scaffold needed |
| Quick run command | `RithamCore/Scripts/test-core.sh` for pure-Swift RithamCore logic (plate calculator, guidance catalog, movement-pattern lookup) — reuses Phase 1's toolchain-adaptive harness unchanged |
| Full suite command | `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,id=<simulator-UDID>'` — **note:** no `.xcscheme` file was found checked into the repo this session (`find` returned zero matches), so the exact scheme-resolution behavior should be confirmed via `xcodebuild -list -project RithamApp/Ritham.xcodeproj` during Wave 0 rather than assumed; a `name=iPhone 17` (or similar, from the confirmed-available simulator list) destination is a safer starting point than an unconfirmed scheme name |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRENGTH-02 | Plate calculator returns nearest loadable weight for barbell/EZ/trap/Smith/stack, exact and inexact targets | unit | `RithamCore/Scripts/test-core.sh` (targeting `PlateCalculatorTests`) | ❌ Wave 0 |
| STRENGTH-04 | Every seeded exercise resolves to at least one movement pattern; compound exercises resolve to multiple if `Set<MovementPattern>` is adopted (Open Question 3) | unit | `RithamCore/Scripts/test-core.sh` (targeting `MovementPatternTests`) | ❌ Wave 0 |
| HEALTH-03 | Every `ConditionTag` has a defined `ContentPermission` for the workout domain; no tag falls through to an implicit default | unit | `RithamCore/Scripts/test-core.sh` (targeting `GuidanceCatalogTests`, exhaustive-switch style like Phase 1's `GateResolutionTests`) | ❌ Wave 0 |
| HEALTH-04 | Every `ConditionTag` has a defined `ContentPermission` for the nutrition domain; Under-18 resolves to `.educationOnly` (never `.full`) for any weight-management-flavored content | unit | `RithamCore/Scripts/test-core.sh` (targeting `GuidanceCatalogTests`) | ❌ Wave 0 |
| DIET-02 | Food-swap table renders only when nutrition gate is `.none`/`.recommended`; renders nothing under `.requiredBlocking` | unit | `RithamCore/Scripts/test-core.sh` (targeting `DietarySwapCatalogTests`) | ❌ Wave 0 |
| DIET-03 | Nutrient-education block renders identically regardless of condition tag or gate state | unit | `RithamCore/Scripts/test-core.sh` (targeting `DietarySwapCatalogTests`) | ❌ Wave 0 |
| CARDIO-02 | Grade-adjusted pace is suppressed or clearly down-weighted when elevation-signal confidence is poor (Pitfall 5) | unit (pure math against synthetic confidence inputs) | `RithamCore/Scripts/test-core.sh` (targeting `GradeAdjustedPaceTests`) | ❌ Wave 0 |
| STRENGTH-05 | A `LiftSet` retains stable identity across a session merge/split operation | unit | `RithamCore/Scripts/test-core.sh` or app-target SwiftData test, depending on where merge/split logic lands | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted `RithamCore/Scripts/test-core.sh` run (or app-target `-only-testing:` run) for the module just touched
- **Per wave merge:** full `RithamCoreTests` suite + any newly-added `RithamTests` (app-target) suite covering this phase's guidance/session views
- **Phase gate:** full suite green before `/gsd-verify-work`, plus at least one on-device manual pass for GPS/motion sensor paths (Simulator cannot validate these, per Environment Availability)

### Wave 0 Gaps

- [ ] `RithamCoreTests/PlateCalculatorTests.swift` — covers STRENGTH-02
- [ ] `RithamCoreTests/MovementPatternTests.swift` — covers STRENGTH-04
- [ ] `RithamCoreTests/GuidanceCatalogTests.swift` — covers HEALTH-03, HEALTH-04 (recommend an exhaustive-switch-style test asserting every `ConditionTag` case has a defined `ContentPermission` per domain, mirroring Phase 1's `GateResolutionTests` discipline)
- [ ] `RithamCoreTests/DietarySwapCatalogTests.swift` — covers DIET-02, DIET-03
- [ ] `RithamCoreTests/GradeAdjustedPaceTests.swift` — covers CARDIO-02's confidence-gating behavior
- [ ] Confirm the actual Xcode scheme name / `-destination` string via `xcodebuild -list` before writing any plan's literal test-run commands — do not assume `-scheme Ritham` resolves without checking

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No login/account system exists anywhere in this product yet (matches Phase 1) |
| V3 Session Management | No | No session/login concept |
| V4 Access Control | Yes | The content-permission layer (Pattern 1) is a new access-control surface: a `ContentPermission.none`/`.educationOnly` gate must be enforced at the data/content-resolution layer (inside `GuidanceCatalog`), not only at the UI-rendering layer, so a view-level bug can't leak personalized content past a required-blocking gate — same discipline as Phase 1's Security Domain V4 recommendation for screening data |
| V5 Input Validation | Yes | Plate-calculator numeric inputs (target weight, bar weight) should be bounded to plausible positive ranges; GPS/motion sensor data should be sanity-bounded (e.g., implausible instantaneous speed/pace jumps discarded, not displayed as a real split) |
| V6 Cryptography | No new surface | No new secrets/tokens introduced this phase; SwiftData file-protection class already applied to the store in Phase 1 covers the new session/set records too, since they live in the same store |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| A view renders full personalized nutrition guidance for a tag whose `ContentPermission` should be `.educationOnly` or `.none`, due to a UI-level bug that bypasses the content-resolution layer | Elevation of Privilege / Information Disclosure | Enforce `ContentPermission` resolution inside `GuidanceCatalog` itself (a pure function every guidance view must call), never let a view compute its own visibility logic inline — same "data-layer gate, not just navigation-layer" principle Phase 1 already established for screening access |
| Spoofed/implausible GPS or motion-sensor data (e.g., a jailbroken device feeding fake location updates) inflating a session's distance/pace, which could later interact with Phase 3's Momentum streak qualification | Tampering | Out of primary scope for Phase 2 itself (Momentum ships in Phase 3), but Phase 2's session data model should record whether a session was sensor-verified vs. manually-entered (already a named requirement — ROADMAP.md: "manually-entered sessions... labeled distinctly from sensor-verified ones") since that distinction is Phase 3's foundation for any anti-gaming consideration, not something Phase 2 needs to solve itself |
| A user's precise route (GPS breadcrumb trail) leaking via an opt-in "route comparison" feature in a way that becomes a de facto location-sharing feature without the user realizing its scope | Information Disclosure | Per Open Question 4: scope CARDIO-03 conservatively (single-user route history) unless discuss-phase explicitly confirms cross-user comparison; any cross-user route-sharing surface must be individually opt-in per comparison, never a standing/default-visible aggregate — directly enforcing PROJECT.md's permanent no-heatmap prohibition |

## Sources

### Primary (HIGH confidence)
- `RithamCore/Sources/RithamCore/Screening/{ConditionTag,ClearanceGate,GateResolution,GateEscalation,DietaryPattern,TagDerivation}.swift`, `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift`, `RithamCore/Sources/RithamCore/Calibration/CalibrationBaseline.swift`, `RithamApp/Ritham/Calibration/{PedometerSession,LocationEnrichment,StopwatchSession}.swift`, `RithamApp/Ritham/Persistence/HealthDataStore.swift`, `RithamApp/Ritham/App/StepRegistry.swift`, `RithamApp/project.yml`, `RithamCore/Package.swift` — all read directly from the committed repository this session, not inferred. This is the sole source for every claim about "what RithamCore/RithamApp already provide."
- `docs/health-screening.md`, `docs/dietary-pattern.md`, `docs/roadmap.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` — read in full this session; sole source for every product-requirement claim (rule tables, monetization boundary, permanent location-visualization prohibition).

### Secondary (MEDIUM confidence)
WebSearch results cross-referenced across 2+ independent sources per `classify-confidence --provider websearch --verified`:
- `CMMotionActivity`'s non-exclusive walking/running booleans and `.low`/`.medium`/`.high` confidence property, and its ramp-up timing
- `CLLocationManager` horizontalAccuracy filtering thresholds (30-50m for pace-sensitive apps) and Kalman/Hampel smoothing as the general technique class (recommended out of scope, see Alternatives Considered)
- Swift Charts as the native, first-party choice for workout-history line/bar visualization
- HealthKit-as-data-source-not-persistence-layer architectural guidance, and the query-once-transform-persist-locally pattern
- `allowsBackgroundLocationUpdates` defaulting `false`, `pausesLocationUpdatesAutomatically`/`activityType` battery-conservation guidance
- Standard greedy-algorithm plate-calculator approach (largest-denomination-first, round to nearest achievable increment)
- Grade-adjusted pace grounded in Minetti et al. (2002)'s cost-of-transport-vs-grade curve, with practical uphill/downhill percentage approximations
- App Store Review Guideline 1.4.1 (medical-decision disclaimer reminder) and 5.1.1 (organizational-account requirement for highly-regulated health services)

### Tertiary (LOW confidence)
- MapKit as the recommended route-rendering framework (Assumption A1) — not independently searched this session, flagged `[ASSUMED]` on the strength of "no serious non-third-party alternative exists," not a researched comparison
- `CMAltimeter` barometric altitude as a better GAP input than `CLLocation.verticalAccuracy` (Assumption A2) — a plausible technical inference from the horizontal-vs-vertical GPS accuracy asymmetry finding, not independently confirmed against Apple documentation this session (no MCP documentation provider was available)

## Metadata

**Confidence breakdown:**
- Standard stack (CoreLocation, CoreMotion, Swift Charts, SwiftData extension): MEDIUM — WebSearch cross-referenced across multiple sources per finding, consistent with Phase 1's own confidence level for equivalent Apple-framework claims; no code sample was compiled/run this session
- Architecture (content-permission layer, guidance-copy catalog, new sensor adapters, plate calculator): HIGH for the "what already exists and what's missing" claims (read directly from committed source), MEDIUM for the recommended new-type shapes (design judgment grounded in that direct reading, not independently compile-verified)
- Pitfalls: Pitfalls 1-2 are HIGH confidence — drawn directly from this project's own committed source code and comments (`GateEscalation.swift`'s own gap admission, `TagDerivation.swift`'s own gap-closure comment), not generic web research. Pitfalls 3-5 are MEDIUM, standard WebSearch-sourced findings.
- Package Legitimacy Audit: N/A — no packages proposed; the "seam has no SPM support" finding is a direct tool-behavior observation from this session (`package-legitimacy check --ecosystem swift` returned a usage error), HIGH confidence.

**Research date:** 2026-08-28
**Valid until:** 30 days for the Apple-framework technical findings (stable, slow-moving guidance) — same as Phase 1's stated validity window. The App Store Review Guideline citations (1.4.1, 5.1.1) should be re-checked against the live `developer.apple.com/app-store/review/guidelines/` page closer to submission, since Apple revises these guidelines more frequently than framework APIs change; treat this research's guideline citations as directional, not a substitute for a pre-submission re-read.
