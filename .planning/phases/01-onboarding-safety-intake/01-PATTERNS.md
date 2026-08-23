# Phase 1: Onboarding & Safety Intake - Pattern Map

**Mapped:** 2026-08-23
**Files analyzed:** 19 (create) — see File Classification
**Analogs found in codebase:** 0 / 19 — **this is the first code in a greenfield native iOS project**

## Codebase Search Confirmation

Confirmed via `find . -iname "*.swift" -o -iname "*.xcodeproj"` from repo root: zero results. No
`.planning/codebase/*.md` maps exist. There is no existing Xcode project, no `Package.swift`, no
`.swift` file of any kind in this repository. This phase is establishing the project's first
patterns, not reusing existing ones. Everything below is sourced from `01-RESEARCH.md`'s
Architecture Patterns section (already vetted, cross-referenced against Apple docs/WebSearch) and
from `01-UI-SPEC.md`'s locked visual/copy contract — not from codebase analogs, because none exist.

Per the pattern-mapper's read-only/no-fabrication constraint: rather than inventing a plausible-
looking "closest analog," this document treats RESEARCH.md's three worked code examples (wizard
flow-state, custom Shape, CMPedometer session) as the canonical seed pattern for each respective
file category, and flags every other file as "no analog — first occurrence in project."

## File Classification

| New File (from RESEARCH.md's Recommended Project Structure) | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `App/RithamApp.swift` | config/entry-point | request-response (app lifecycle) | none | no analog — greenfield |
| `App/UniversalLinkHandler.swift` | event-driven handler | event-driven | none | no analog — greenfield |
| `Onboarding/OnboardingFlowState.swift` | store (`@Observable` state) | CRUD (in-memory, wizard answers) | RESEARCH.md Pattern 1 (worked example) | seed-pattern (research-sourced) |
| `Onboarding/Navigation/*.swift` | route/navigation | request-response | RESEARCH.md Pattern 1 (worked example) | seed-pattern (research-sourced) |
| `Onboarding/Steps/*.swift` (Welcome, Register, Age, Diet, Privacy, Calibration, ...) | component (SwiftUI View) | request-response | RESEARCH.md Pattern 1 (worked example, `WelcomeStepView`/`step.view(flow:)` shape) | seed-pattern (research-sourced) |
| `Screening/GateResolution/*.swift` | service (pure Swift, no UI/persistence import) | transform | none (deliberately isolated per RESEARCH.md Validation Architecture) | no analog — greenfield; test-first module |
| `Screening/Models/*.swift` (ConditionTag, ClearanceGate, SCOFFResult) | model | transform | none | no analog — greenfield |
| `Screening/Views/*.swift` (gate section, checklist, SCOFF, interstitials) | component | request-response | RESEARCH.md Pattern 1 (wizard step shape) | seed-pattern (research-sourced) |
| `Calibration/PedometerSession.swift` | service (sensor wrapper) | streaming (CMPedometer live updates) | RESEARCH.md Pattern 3 (worked example) | seed-pattern (research-sourced) |
| `Calibration/StopwatchSession.swift` | service | event-driven (manual start/stop) | none — RESEARCH.md flags as fallback path, no worked example given | no analog — greenfield |
| `Calibration/Views/*.swift` | component | request-response | RESEARCH.md Pattern 1 (wizard step shape) | seed-pattern (research-sourced) |
| `Consent/ConsentState.swift` | model (state machine enum) | event-driven (state transitions) | none — RESEARCH.md Conflict 2 explicitly specifies the enum shape (`pending → email_sent → link_clicked → confirmed`), no code sample given | no analog — greenfield; spec-defined shape |
| `Consent/Views/*.swift` (under-13 halt, 13-17 partial-gate notice) | component | request-response | RESEARCH.md Pattern 1 (wizard step shape) | seed-pattern (research-sourced) |
| `Persistence/SwiftDataModels/*.swift` (UserProfile, ConditionTagRecord, CalibrationBaseline, DietaryPattern) | model (`@Model`) | CRUD | none — RESEARCH.md "Don't Hand-Roll" table specifies `@Model` + computed `isExpired` against stored `expiresAt`, no full code sample given | no analog — greenfield; spec-defined shape |
| `DesignSystem/RithamColor.swift` | config/theme | transform | 01-UI-SPEC.md (theme-object requirement, not yet read in full — planner should pull exact token names from there) | no analog — greenfield |
| `DesignSystem/BandMotif.swift` | component (custom `Shape`) | transform (geometry) | RESEARCH.md Pattern 2 (worked example) | seed-pattern (research-sourced) |
| `Tests/GateResolutionTests/*.swift` | test | transform | RESEARCH.md Validation Architecture (Phase Requirements → Test Map table gives exact test names/behaviors) | seed-pattern (research-sourced) |
| Backend: parent-consent email service (token gen, send, verify) | service (server-side) | request-response + event-driven | none — separate runtime/language from iOS target, not in this repo yet | no analog — greenfield; infra to be provisioned in Wave 0 |
| Backend: Universal Link / `apple-app-site-association` hosting | config | request-response | none | no analog — greenfield; infra to be provisioned in Wave 0 |

## Pattern Assignments (Seed Patterns from RESEARCH.md)

Since no codebase analog exists, the following are the **project's first patterns**, extracted
verbatim from `01-RESEARCH.md`. The planner should cite these as the canonical shape for each file
category, and every subsequent phase's pattern-mapper will be able to point back at the *actual*
files these produce as real analogs going forward.

### Wizard step files (`Onboarding/Steps/*.swift`, `Screening/Views/*.swift`, `Calibration/Views/*.swift`, `Consent/Views/*.swift`)

**Seed source:** `01-RESEARCH.md` Pattern 1, "Wizard flow via `NavigationStack` + shared `@Observable` flow-state"

```swift
@Observable
final class OnboardingFlowState {
    var register: ExplanationRegister?
    var age: Int?
    var dietaryPattern: DietaryPattern?
    var consentTier: ConsentTier?          // computed from age once known
    var conditionTags: Set<ConditionTag> = []
    var scoffAnswers: SCOFFResponses?
    // ...

    /// Computes the next step given current answers — the single source of truth
    /// for branching, so no View makes its own routing decision.
    func nextStep(after current: OnboardingStep) -> OnboardingStep? { ... }
}

struct OnboardingRootView: View {
    @State private var flow = OnboardingFlowState()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStepView()
                .navigationDestination(for: OnboardingStep.self) { step in
                    step.view(flow: flow)
                }
        }
        .environment(flow)
    }
}
```

**Key rule to enforce across every step View:** no per-step local `@State` for wizard answers
(RESEARCH.md Anti-Patterns) — all branching-relevant state reads/writes go through the shared
`OnboardingFlowState`, injected via `@Environment`. This is what makes CROSSGEN-05 ("no age-gated
fork, only content differs within shared screens") achievable — `nextStep(after:)` is the single
place branching logic lives, never scattered per-View `if age < 13` checks.

**Apply to:** `Onboarding/Steps/*.swift`, `Screening/Views/*.swift`, `Calibration/Views/*.swift`,
`Consent/Views/*.swift` — every wizard-step View in this phase.

---

### `DesignSystem/BandMotif.swift`

**Seed source:** `01-RESEARCH.md` Pattern 2, "Custom `Shape` recomputing geometry from its own `rect`"

```swift
struct BandMotif: Shape {
    let angleDegrees: Double = 57 // fixed, matches sketch 003

    func path(in rect: CGRect) -> Path {
        // rect.width / rect.height ARE this call's real dimensions —
        // recompute left/right flat-margin fractions for THIS aspect ratio,
        // do not reuse sketch 003's 1440×720-solved ~25%/~20% figures.
        var path = Path()
        // ... edge-crossing computation per sketch 003's README "Geometry note",
        // re-derived against rect.width/rect.height, verified computationally.
        return path
    }
}

struct ScreenHeader: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !typeSize.isAccessibilitySize {
            BandMotif()
                .fill(RithamColor.hot)
                .frame(height: 250) // within UI-SPEC's 220-280pt recommendation
        }
        // else: header compresses out of layout entirely, content reflows onto flat charcoal
    }
}
```

**Critical anti-pattern to avoid** (RESEARCH.md Pitfall 1, already a verified bug in UI-SPEC):
never port sketch-003's 1440×720 SVG polygon coordinates directly — always recompute flat-margin
fractions from `rect.width`/`rect.height` at call time.

**Apply to:** `DesignSystem/BandMotif.swift` only (single file).

---

### `Calibration/PedometerSession.swift`

**Seed source:** `01-RESEARCH.md` Pattern 3, "Calibration walk via `CMPedometer`, no location prompt required"

```swift
import CoreMotion

final class PedometerSession {
    private let pedometer = CMPedometer()

    func start(onUpdate: @escaping (CMPedometerData) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            // Device has no pedometer hardware — fall back to manual stopwatch per D-02
            return
        }
        pedometer.startUpdates(from: Date(), withHandler: { data, error in
            guard let data else { return }
            onUpdate(data) // caller determines "10+ continuous minutes" completion
        })
    }

    func stop() { pedometer.stopUpdates() }
}
```

**Key rule:** CoreLocation/GPS is enrichment only, never the primary completion gate (D-02,
RESEARCH.md Anti-Patterns) — `Calibration/StopwatchSession.swift` (manual fallback) has no worked
example in RESEARCH.md; the planner/executor should design it as a simple start/stop/elapsed-time
struct satisfying the same "10+ continuous minutes" completion contract as `PedometerSession`, so
both paths can be interchangeable behind one `CalibrationSession` protocol/interface — this
interchangeability is Claude's Discretion, not specified, but follows directly from D-02's "fallback
must work standalone" requirement.

**Apply to:** `Calibration/PedometerSession.swift`, informs (but does not literally template)
`Calibration/StopwatchSession.swift`.

---

### `Screening/GateResolution/*.swift` (pure Swift module)

**No code sample in RESEARCH.md** — only a structural mandate. Extracted requirements the planner
must turn into the actual pattern:

- Must be a **pure Swift module with no SwiftUI or SwiftData import** (RESEARCH.md Recommended
  Project Structure comment: "PURE Swift module... HEALTH-06 escalation logic lives here,
  unit-testable in isolation").
- Input: condition-checklist answers + gate-section (G1-G7) answers + SCOFF responses. Output:
  `Set<ConditionTag>` + clearance/gate state.
- Must implement the 16 documented escalation rules in `docs/health-screening.md` §5, notably:
  "Not sure" → always resolves to the more cautious branch; 2+ red-flag tags → single most
  restrictive gate wins, never averaged (D-12: disclaimer tag still lists all matched conditions
  even when only one gate binds).
- Test names already specified in RESEARCH.md's Phase Requirements → Test Map table (e.g.
  `testNotSureResolvesCautious`, `testMultiTagMostRestrictiveWins`, `testSCOFFTrigger`) — the
  planner should treat these test function names as the acceptance contract for this module.

**Apply to:** `Screening/GateResolution/*.swift`, `Tests/GateResolutionTests/*.swift`.

---

### `Consent/ConsentState.swift`

**No code sample in RESEARCH.md** — only a required shape, specified in Conflict 2's
recommendation and restated in the Recommended Project Structure comment:

> Model parental consent as a state machine with a pluggable verification step
> (`pending → email_sent → link_clicked → confirmed` rather than `pending → confirmed` in one hop)

**Explicit anti-pattern** (RESEARCH.md Anti-Patterns, Pitfall 2): never use a `Bool` field for
consent status anywhere in the schema — "parent clicked the link" and "consent is legally valid"
must be distinguishable states, not conflated.

**Apply to:** `Consent/ConsentState.swift`, and the consent-record shape mirrored client-side in
`Persistence/SwiftDataModels/*.swift`.

---

### `Persistence/SwiftDataModels/*.swift`

**No full code sample in RESEARCH.md** — extracted requirements from "Don't Hand-Roll" table and
Security Domain section:

- Use SwiftData `@Model` macros (not Core Data, not raw `UserDefaults`/file-based stores).
- Condition-tag records need a computed `isExpired` check against a stored `expiresAt` date field
  (12-month expiry per HEALTH-02/D-07/D-08) — expiry is a query-time check, not a data-deletion
  event, and expired tags keep being applied (safer-default) rather than silently reverting to
  generic guidance.
- Apply an explicit file protection class (`NSFileProtectionComplete` or
  `NSFileProtectionCompleteUntilFirstUserAuthentication`) to the SwiftData store — condition tags
  and SCOFF-derived data are named as sensitive in scope (Security Domain, V6 Cryptography row).
- Open decision flagged for the planner (not resolved by research): persist only the derived SCOFF
  tag (`positiveScreen: Bool`) rather than the 5 raw ED-1..ED-5 booleans, per
  `docs/health-screening.md` §1.5's "never shown as a score/label" framing extended to storage.

**Apply to:** `Persistence/SwiftDataModels/UserProfile.swift`, `ConditionTagRecord.swift`,
`CalibrationBaseline.swift`, `DietaryPattern.swift`.

## Shared Patterns

### Wizard branching — single source of truth
**Source:** RESEARCH.md Pattern 1 (`OnboardingFlowState.nextStep(after:)`)
**Apply to:** every step View across `Onboarding/`, `Screening/`, `Calibration/`, `Consent/` —
no View computes its own next-step/branch logic locally.

### No boolean flags for multi-state concepts
**Source:** RESEARCH.md Anti-Patterns / Pitfall 2 (consent), extended by analogy to condition-tag
expiry (state: active / expired-but-still-applied / re-screened, not a simple `Bool`)
**Apply to:** `Consent/ConsentState.swift`, `Persistence/SwiftDataModels/ConditionTagRecord.swift`

### Gate enforcement at the data layer, not just navigation
**Source:** RESEARCH.md Security Domain, V4 Access Control row — "recommend gating at the
data-query layer (e.g., a computed `canAccessScreening` check consulted everywhere screening data
is read/written), not just at the UI navigation layer, so a bug in one screen's navigation logic
can't bypass the gate"
**Apply to:** `Persistence/SwiftDataModels/*.swift` (query-time guard), `Consent/ConsentState.swift`
(gate source of truth), any View reading screening/condition data.

### Custom `Shape` geometry always derived from `rect`, never hardcoded coordinates
**Source:** RESEARCH.md Pattern 2 + Pitfall 1
**Apply to:** `DesignSystem/BandMotif.swift` (only current consumer, but the rule generalizes to
any future custom `Shape` in this project)

## No Analog Found

Every file in this phase has no codebase analog (confirmed zero `.swift` files exist). Files with
**no RESEARCH.md code sample either** (fully greenfield, spec-only guidance) are listed here so the
planner treats them as needing an explicit implementation decision, not a copy-paste seed:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `App/RithamApp.swift` | config | request-response | Standard `@main` + `ModelContainer` boilerplate; RESEARCH.md names the responsibility but gives no sample — trivial, low-risk to originate |
| `App/UniversalLinkHandler.swift` | event-driven | event-driven | `.onOpenURL` handler for consent confirm links; only the AASA/QA1916 testing method is specified, not the handler code itself |
| `Screening/Models/*.swift` | model | transform | `ConditionTag`, `ClearanceGate`, `SCOFFResult` — plain enums/structs, shape implied by `docs/health-screening.md` §1-§5 but no Swift sample given |
| `Calibration/StopwatchSession.swift` | service | event-driven | RESEARCH.md explicitly calls this the fallback path with no worked example; must independently satisfy the same completion contract as `PedometerSession` |
| `Consent/ConsentState.swift` | model | event-driven | State-machine shape given in prose (Conflict 2), no code sample |
| `Persistence/SwiftDataModels/*.swift` | model | CRUD | `@Model` requirement + `isExpired`/file-protection constraints given, no full sample |
| `DesignSystem/RithamColor.swift` | config | transform | Referenced as "per UI-SPEC's theme-object requirement" — planner must pull exact token values from `01-UI-SPEC.md` directly, not from this document |
| Backend parent-consent service (all files) | service | request-response/event-driven | Entirely new infrastructure (language/runtime not yet chosen beyond "Supabase + Resend, tentative" — flagged `SUS`/false-positive in RESEARCH.md, needs `checkpoint:human-verify`); not part of the iOS target's codebase at all |
| Universal Link / AASA hosting config | config | request-response | Infra provisioning task, not application code |

## Metadata

**Analog search scope:** entire repository (`find . -iname "*.swift" -o -iname "*.xcodeproj"` from
repo root — zero matches)
**Files scanned:** 0 Swift source files exist; `01-CONTEXT.md`, `01-RESEARCH.md` read in full for
file-list extraction
**Pattern extraction date:** 2026-08-23
**Confidence note:** All "seed-pattern" entries above inherit RESEARCH.md's own MEDIUM confidence
(WebSearch cross-referenced, not compile-verified in an Xcode environment this session). Treat as a
strong starting shape, not a guaranteed-to-compile snippet — the planner/executor should
compile-check during Wave 0 rather than assume verbatim correctness.
