# Phase 2: Core Tracking & Adjusted Guidance - Pattern Map

**Mapped:** 2026-09-04
**Files analyzed:** ~30 (grouped by domain — RESEARCH.md's Recommended Project Structure is the
file-list source; CONTEXT.md's D-01–D-07 select which of those are truly in-phase-scope)
**Analogs found:** 24 / 30 (Swift side has strong analogs throughout; Go side has zero in-repo
analogs by design — first Go code in the repo — RESEARCH.md's "Go Backend Research" section is
cited instead, per the task's explicit instruction)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `RithamCore/Sources/RithamCore/Cardio/ActivityType.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` (`CalibrationMode`) | role-match |
| `RithamCore/Sources/RithamCore/Cardio/CardioSession.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` (`WalkProgress`/`CalibrationProgress`) | role-match |
| `RithamCore/Sources/RithamCore/Cardio/GradeAdjustedPace.swift` | utility | transform | *(none — pure new math, no in-repo analog)* | no-analog |
| `RithamCore/Sources/RithamCore/Strength/Equipment.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` (`CalibrationThreshold` enum-of-constants shape) | partial-match |
| `RithamCore/Sources/RithamCore/Strength/PlateCalculator.swift` | utility | transform | *(none — pure new algorithm, no in-repo analog; RESEARCH.md Pattern 4 is the spec)* | no-analog |
| `RithamCore/Sources/RithamCore/Strength/Superset.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Screening/ClearanceGate.swift` (small `Sendable`/`Hashable` value-type + wrapper struct shape) | partial-match |
| `RithamCore/Sources/RithamCore/Strength/MovementPattern.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Screening/ConditionTag.swift` (exhaustive lookup-table enum shape — not read in full this session but same established pattern as `GateEscalation.baseGates`) | role-match |
| `RithamCore/Sources/RithamCore/Strength/LiftSession.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` (`LiftProgress`) | exact |
| `RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift` | model | CRUD | `RithamCore/Sources/RithamCore/Screening/ClearanceGate.swift` | exact |
| `RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift` | service | request-response | `RithamCore/Sources/RithamCore/Screening/GateEscalation.swift` (`baseGates(for:)` exhaustive per-tag switch) | exact |
| `RithamCore/Sources/RithamCore/Guidance/NutritionGuidanceCatalog.swift` | service | request-response | `RithamCore/Sources/RithamCore/Screening/GateEscalation.swift` | exact |
| `RithamCore/Sources/RithamCore/Guidance/DietarySwapCatalog.swift` | service | request-response | `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift` / `OnboardingCopy.swift` (verbatim-transcribed copy catalog pattern) | exact |
| `RithamApp/Ritham/Cardio/GPSTrackingSession.swift` | service | streaming | `RithamApp/Ritham/Calibration/LocationEnrichment.swift` | role-match (scope differs — see note) |
| `RithamApp/Ritham/Cardio/MotionActivityDetector.swift` | service | event-driven | `RithamApp/Ritham/Calibration/PedometerSession.swift` | role-match |
| `RithamApp/Ritham/Cardio/StopwatchCardioSession.swift` | service | streaming | `RithamApp/Ritham/Calibration/StopwatchSession.swift` | exact |
| `RithamApp/Ritham/Cardio/Views/*` | component | request-response | `RithamApp/Ritham/Calibration/Views/CalibrationSessionView.swift` | role-match |
| `RithamApp/Ritham/Strength/Views/*` | component | CRUD | `RithamApp/Ritham/Screening/Views/ConditionChecklistView.swift` (form-entry pattern) | partial-match |
| `RithamApp/Ritham/Guidance/Views/*` | component | request-response | `RithamApp/Ritham/Disclaimers/ConditionDisclaimerTag.swift` + `RequiredBlockingMessageView.swift` | exact (explicitly reused per CONTEXT.md Claude's Discretion) |
| `RithamApp/Ritham/Charts/Views/*` | component | request-response | *(none — first Swift Charts usage in repo)* | no-analog |
| `RithamApp/Ritham/Persistence/SwiftDataModels/CardioSessionRecord.swift` | model | CRUD | `RithamApp/Ritham/Persistence/CalibrationBaselineRecord.swift` | exact |
| `RithamApp/Ritham/Persistence/SwiftDataModels/LiftSessionRecord.swift` / `LiftSetRecord.swift` | model | CRUD | `RithamApp/Ritham/Persistence/ConditionTagRecord.swift` (per-item record replace/query pattern in `HealthDataStore`) | exact |
| `RithamApp/Ritham/Persistence/HealthDataStore.swift` (extended) | service | CRUD | itself — extend in place, following its own established facade pattern | exact (extend, not new file) |
| `RithamApp/Ritham/Settings/AlwaysFreeListView.swift` | component | request-response | `RithamApp/Ritham/Settings/DietPlanView.swift` | role-match |
| `RithamApp/Ritham/Settings/SettingsView.swift` (extended — new entry points) | component | request-response | itself — extend in place | exact |
| New interim navigation hub view (D-05, e.g. `RithamApp/Ritham/Home/HomeHubView.swift`) + registration | component | request-response | `RithamApp/Ritham/Onboarding/Steps/HomeStepView.swift` (the `.home` stub this replaces) + `RithamApp/Ritham/Calibration/CalibrationRegistration.swift` (registrar pattern) | exact |
| Recommendations trigger surface (D-03, e.g. `RithamApp/Ritham/Recommendations/RecommendationsView.swift`) | component | request-response | `RithamApp/Ritham/Settings/DietPlanView.swift` (opened-as-own-screen-from-a-list pattern) | role-match |
| Workout-frequency Settings preference (Claude's Discretion) | component | CRUD | `RithamApp/Ritham/Settings/DietPlanView.swift`'s `persistDiet` (isolated preference write) | exact |
| `RithamService/cmd/ritham-service/main.go` | config/entrypoint | request-response | *(none — first Go file in repo)* | no-analog (Go stdlib) |
| `RithamService/internal/plan/generate.go` | service | request-response | *(none — first Go file in repo)* | no-analog (Go stdlib) |
| `RithamService/internal/httpapi/handler.go` | controller | request-response | *(none — first Go file in repo)* | no-analog (Go stdlib) |

## Pattern Assignments

### `RithamCore/Sources/RithamCore/Cardio/ActivityType.swift` / `CardioSession.swift` (model, CRUD)

**Analog:** `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift`

**Per D-02, this is a deliberately separate domain, not a reuse/extension** — copy the *shape*
of the analog, not its types. `CalibrationSession.swift` is the reference for how RithamCore
expresses this kind of session-progress domain: Foundation-only imports, `Sendable` value types,
named-constant enums, and progress structs with private(set) mutating methods.

**Foundation-only header discipline** (lines 1-8):
```swift
import Foundation

// RithamCore cannot import CoreMotion or CoreLocation — [domain] completion/measurement must
// never be gated on sensor availability or location authorization at this layer.
```

**Extensible enum pattern** (lines 10-14) — `CalibrationMode` is a closed 2-case enum; `ActivityType`
must instead be built as an **extensible** enum per RESEARCH.md's explicit note (CARDIO-01: "Run/
Walk/Cycle/Hike/Swim/Elliptical, extensible") — do not copy the closed-`enum` shape verbatim, only
the `String, CaseIterable, Sendable` conformance style:
```swift
public enum CalibrationMode: String, CaseIterable, Sendable {
    case walk
    case lift
}
```

**Named-constant enum pattern** (lines 16-34) — reused directly for
`CalibrationThreshold` cross-reference (D-02 requires `WorkoutSession` to reference these
constants, not restate them):
```swift
public enum CalibrationThreshold {
    public static let qualifyingWalkDuration: TimeInterval = 600
    public static let qualifyingWorkingSets: Int = 3
    public static let qualifyingExercises: Int = 2
}
```

**Progress-struct pattern** (lines 47-68, `WalkProgress`) — the shape to copy for `CardioSession`'s
live-measurement struct: private(set) stored properties, a plain `init`, and explicit mutating
methods rather than public setters:
```swift
public struct WalkProgress: Sendable, Equatable {
    public private(set) var continuousDuration: TimeInterval
    public private(set) var distanceMeters: Double
    public private(set) var wasInterrupted: Bool

    public init(continuousDuration: TimeInterval = 0, distanceMeters: Double = 0, wasInterrupted: Bool = false) {
        self.continuousDuration = continuousDuration
        self.distanceMeters = distanceMeters
        self.wasInterrupted = wasInterrupted
    }

    public mutating func recordInterruption() {
        continuousDuration = 0
        distanceMeters = 0
        wasInterrupted = true
    }
}
```

**Do not copy:** `CalibrationSessionSource` protocol (lines 157-160) — its single yes/no
completion-boolean contract is explicitly the wrong shape for a live, multi-metric cardio session
(RESEARCH.md Pattern 3 / Anti-Patterns). `CardioSession`/`LiftSession` need their own richer
contract.

---

### `RithamApp/Ritham/Cardio/StopwatchCardioSession.swift` (service, streaming)

**Analog:** `RithamApp/Ritham/Calibration/StopwatchSession.swift` (exact match — RESEARCH.md's
own Recommended Project Structure names this file "same pattern as Phase 1's StopwatchSession but
for CardioSession")

**Imports + class-shape pattern** (lines 1-19):
```swift
import Foundation
import SwiftUI
import RithamCore

@Observable
final class StopwatchSession: CalibrationSessionSource, @unchecked Sendable {
    let mode: CalibrationMode = .walk
    private nonisolated(unsafe) var recorded = WalkProgress()
    private nonisolated(unsafe) var currentStartedAt: Date?
    private let now: () -> Date
    init(now: @escaping () -> Date = Date.init) { self.now = now }
```

**start/pause/resume/stop + live-elapsed-time-on-top pattern** (lines 39-76) — copy this whole
shape for the manual cardio stopwatch, substituting `CardioSession`'s progress type for
`WalkProgress` and dropping the `CalibrationSessionSource` conformance (that protocol is
calibration-only, per Anti-Patterns above):
```swift
func start() {
    currentStartedAt = now()
}
func pause() {
    recorded = liveProgress()
    recorded.recordInterruption()
    currentStartedAt = nil
}
func resume() {
    currentStartedAt = now()
}
func stop() {
    recorded = liveProgress()
    currentStartedAt = nil
}
private func liveProgress() -> WalkProgress {
    guard let currentStartedAt else { return recorded }
    let elapsed = now().timeIntervalSince(currentStartedAt)
    return WalkProgress(
        continuousDuration: recorded.continuousDuration + elapsed,
        distanceMeters: recorded.distanceMeters,
        wasInterrupted: recorded.wasInterrupted
    )
}
```
**`@unchecked Sendable` rationale to preserve in the doc comment:** all mutation happens through
`start`/`pause`/`resume`, always called from the main-actor session view — access is serialized
in practice even though the compiler can't prove it statically for a plain reference type.

---

### `RithamApp/Ritham/Cardio/GPSTrackingSession.swift` (service, streaming)

**Analog:** `RithamApp/Ritham/Calibration/LocationEnrichment.swift` (role-match, NOT exact — scope
differs, read this carefully before copying)

**Critical scope correction (RESEARCH.md Pattern 3):** `LocationEnrichment.swift`'s rule
forbidding `requestWhenInUseAuthorization`/`requestAlwaysAuthorization` is scoped to *calibration's*
D-02 no-blocking-prompt rule. It does **not** generalize to Phase 2. `GPSTrackingSession` **is**
expected to request location authorization when the user starts a GPS-tracked cardio session — copy
`LocationEnrichment`'s `CLLocationManager` wrapper *structure* (delegate pattern, accuracy-threshold
filtering) but explicitly invert the authorization-request behavior. Flag this inversion in the new
file's own header comment so a future reader doesn't assume the old rule still applies.

---

### `RithamApp/Ritham/Cardio/MotionActivityDetector.swift` (service, event-driven)

**Analog:** `RithamApp/Ritham/Calibration/PedometerSession.swift` (role-match — same
CoreMotion-adapter role, but wraps a different class: `CMMotionActivityManager`, not `CMPedometer`)

**Why duplication, not reuse (RESEARCH.md Pattern 3):** `CMPedometer` reports step count/distance
for walking specifically; `CMMotionActivityManager` classifies *which* activity is happening with a
confidence level (`.low`/`.medium`/`.high`) — a different CoreMotion API for a different question.
Copy `PedometerSession`'s `@Observable`/actor-isolation-note structure (same file family as
`StopwatchSession.swift` above), not its CMPedometer-specific query logic. Requires the same
`NSMotionUsageDescription` already declared in `Info.plist` since Phase 1 — no new usage-description
string needed (per RESEARCH.md Standard Stack table).

---

### `RithamCore/Sources/RithamCore/Guidance/ContentPermission.swift` (model, CRUD)

**Analog:** `RithamCore/Sources/RithamCore/Screening/ClearanceGate.swift` (exact — this is the
type Phase 2's new type sits downstream of, and the file to copy the doc-comment/enum-ordering
discipline from)

**Full file** (58 lines) — copy the "define an ordering, no averaging operation exists" discipline
and the domain-keyed wrapper-struct pattern:
```swift
public enum ClearanceGate: Sendable, Comparable, CaseIterable {
    case none
    case recommended
    case requiredBlocking

    public static func mostRestrictive(_ gates: [ClearanceGate]) -> ClearanceGate {
        gates.max() ?? .none
    }
}

public enum GuidanceDomain: Sendable, CaseIterable {
    case workout
    case nutrition
}

public struct DomainGates: Sendable, Equatable {
    public var workout: ClearanceGate
    public var nutrition: ClearanceGate
    public init(workout: ClearanceGate, nutrition: ClearanceGate) {
        self.workout = workout
        self.nutrition = nutrition
    }
    public subscript(domain: GuidanceDomain) -> ClearanceGate {
        switch domain {
        case .workout: return workout
        case .nutrition: return nutrition
        }
    }
}
```

**Critical constraint (RESEARCH.md Pattern 1 / Anti-Patterns):** `ContentPermission` must be an
**independent per-`(ConditionTag, GuidanceDomain)` lookup**, never a formula derived from
`ClearanceGate` (e.g. `requiredBlocking -> .none` would be wrong for Under-18/Hypertension-
Uncontrolled/Postpartum-Uncomplicated, whose nutrition gate still permits generic education). The
sibling file `GateEscalation.swift`'s exhaustive per-tag switch (below) is the shape to copy for
*how* to build that lookup, not `ClearanceGate.swift` itself.

---

### `RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift` / `NutritionGuidanceCatalog.swift` (service, request-response)

**Analog:** `RithamCore/Sources/RithamCore/Screening/GateEscalation.swift` — specifically
`baseGates(for:)`, its exhaustive per-`ConditionTag` switch pattern.

**Header-comment discipline to copy** (lines 1-8) — explain *why* the exhaustive switch is
structurally safe, same rationale style:
```swift
// The sixteen numbered escalation triggers ... transcribed against the per-tag Clearance Gate
// columns of §2 (workout) and §3 (nutrition). ... enforced structurally: every escalation below
// folds a candidate gate in with `ClearanceGate.mostRestrictive`, which is a one-way
// (never-lowering) operation by construction ...
```

**Exhaustive per-tag switch pattern** (lines 17-109, `baseGates(for:)`) — copy this exact
shape for `GuidanceCatalog.contentPermission(for:domain:)` and for the workout/nutrition text
lookups: one `case` per `ConditionTag`, each with an inline comment citing the source doc-table
row, e.g.:
```swift
public static func baseGates(for tag: ConditionTag) -> DomainGates {
    switch tag {
    case .under18Minor:
        // §2: no exercise-specific restriction from age alone. §3: required-blocking for
        // any weight-management/calorie/portion feature, per AAP guidance against dieting
        // for minors.
        return DomainGates(workout: .none, nutrition: .requiredBlocking)
    ...
```

**A function this pattern must call, not reimplement** — `GateEscalation.weightLossFeatureGate`
already exists (lines 238-248) and its own doc comment states "Phase 2 calls this at goal-setting
time." Any weight-loss-goal-setting UI in Phase 2 must call this, not a new inline age check:
```swift
public static func weightLossFeatureGate(
    tags: Set<ConditionTag>,
    goalBelowHealthyBMIFloor: Bool
) -> ClearanceGate {
    if tags.contains(.under18Minor)
        || tags.contains(.eatingDisorderPositiveScreen)
        || goalBelowHealthyBMIFloor {
        return .requiredBlocking
    }
    return .none
}
```

---

### `RithamCore/Sources/RithamCore/Guidance/DietarySwapCatalog.swift` (service, request-response)

**Analog:** `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift` / `OnboardingCopy.swift`
(not read in full this session — file names and their own header-comment convention were
confirmed via `GuidanceCatalog`'s Pattern 2 description in RESEARCH.md, which explicitly cites
their "transcribed verbatim... pending LAUNCH-01/LAUNCH-02 review... ship as-is" header-comment
discipline). Every string here must carry that same "transcribed verbatim from
`docs/dietary-pattern.md` §3/§4, pending LAUNCH review" header comment — never paraphrased, never
live-generated (HEALTH-01's standing constraint).

---

### `RithamApp/Ritham/Guidance/Views/*` (component, request-response)

**Analog:** `RithamApp/Ritham/Disclaimers/ConditionDisclaimerTag.swift` +
`RequiredBlockingMessageView.swift` — reused **as-is**, not re-implemented, per CONTEXT.md's
Claude's Discretion ("reuses Phase 1's already-built, verified disclaimer-tag pattern rather than
inventing a new UI pattern").

**`ConditionDisclaimerTag` full pattern** (75 lines) — takes a `GateResolutionResult`, never a
single condition name (per D-12, lists every matched condition, not just the governing one):
```swift
struct ConditionDisclaimerTag: View {
    let result: GateResolutionResult
    @State private var isExpanded = false
    private var conditions: [String] { result.disclaimerConditionNames }
    // ... persistent, no dismiss, fineprint()-styled, coral accent bar
}
```

**`RequiredBlockingMessageView` full pattern** (28 lines) — a plain embedded card, never a
full-screen cover or modal, so the rest of the hosting screen stays usable:
```swift
struct RequiredBlockingMessageView: View {
    var body: some View {
        Text(.init(ScreeningCopy.requiredBlockingMessage))
            .font(RithamType.body)
            .foregroundStyle(RithamColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(RithamSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RithamColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }
}
```
Phase 2's Guidance views embed this in place of blocked content — a `GuidanceCatalog`-driven
message replaces `ScreeningCopy.requiredBlockingMessage`, same layout.

---

### `RithamApp/Ritham/Persistence/HealthDataStore.swift` (service, CRUD — extend in place)

**Analog:** itself. Follow its own established facade discipline exactly when adding
cardio/lift-session and frequency-preference methods:

**Class shape + doc-comment discipline** (lines 1-23):
```swift
import Foundation
import SwiftData
import RithamCore

@MainActor
public final class HealthDataStore {
    private let context: ModelContext
    private let calendar: Calendar
    public init(context: ModelContext, calendar: Calendar = .current) { ... }
```

**"Delete then reinsert full replace" pattern** (lines 280-292, `saveFoodAllergens`) — copy this
shape for any Phase 2 method that replaces a full set on each call:
```swift
public func saveFoodAllergens(_ allergens: Set<FoodAllergen>) throws {
    _ = try loadProfile()
    let existing = try context.fetch(FetchDescriptor<FoodAllergenRecord>())
    for record in existing { context.delete(record) }
    for allergen in allergens { context.insert(FoodAllergenRecord(allergenRaw: allergen.rawValue)) }
    try context.save()
}
```

**"Never absent, provisional fallback" pattern** (lines 318-327, `loadCalibrationBaseline`) —
directly relevant since Claude's Discretion says experience-level falls back to self-report when
calibration was skipped; copy this "never return a blank state" shape:
```swift
public func loadCalibrationBaseline() throws -> CalibrationBaseline? {
    let records = try context.fetch(FetchDescriptor<CalibrationBaselineRecord>())
    guard let baseline = records.first?.baseline else {
        return CalibrationBaseline.provisional(establishedAt: Date())
    }
    return baseline
}
```

**Error enum pattern** (lines 366-372) — extend `HealthDataStoreError`'s existing cases rather
than introducing a second error type:
```swift
public enum HealthDataStoreError: Error, Equatable {
    case profileMissing
    case ageBelowFloor
}
```

---

### `RithamApp/Ritham/Persistence/SwiftDataModels/CardioSessionRecord.swift` / `LiftSessionRecord.swift` / `LiftSetRecord.swift` (model, CRUD)

**Analog:** `RithamApp/Ritham/Persistence/CalibrationBaselineRecord.swift` (exact — `@Model`
shape) for `CardioSessionRecord`; the record's own `computed-property-back-to-domain-type` pattern
matters most:

**Full pattern** (46 lines):
```swift
import Foundation
import SwiftData
import RithamCore

@Model
public final class CalibrationBaselineRecord {
    public var slowestSecondsPerKm: Double
    // ... plain stored properties, no computed persistence tricks
    public init(...) { ... }

    /// `nil` rather than a trap when the raw value no longer matches a known case.
    public var baseline: CalibrationBaseline? {
        guard let source = BaselineSource(rawValue: sourceRaw) else { return nil }
        return CalibrationBaseline(...)
    }
}
```

**Critical STRENGTH-05 constraint (RESEARCH.md Anti-Patterns):** `LiftSetRecord` must be its own
`@Model` with independent persistent identity — never a value type embedded inline in a session's
array — because retroactive session merge/split requires reparenting individual sets to a
different session. `ConditionTagRecord` (referenced throughout `HealthDataStore`, not re-read in
full this session) is the existing precedent for "many independently-addressable child records
queried via `FetchDescriptor` and filtered/deleted individually," which is the shape `LiftSetRecord`
needs, not the single-row shape `CalibrationBaselineRecord` uses.

---

### Interim navigation hub (D-05) and Recommendations surface (D-03)

**Analog for the hub itself:** `RithamApp/Ritham/Onboarding/Steps/HomeStepView.swift` — this is
the **stub being replaced**. Read its header comment before building the hub: it explicitly says
this is NOT the product's real home screen and that a later phase (CROSSGEN-01) builds the
polished version. The new interim hub inherits this same "deliberately not the final design"
framing, but must add real, working navigation instead of `EmptyView()`.

**Registration pattern to copy exactly:**
`RithamApp/Ritham/Calibration/CalibrationRegistration.swift` (12 lines, full file):
```swift
@MainActor
enum CalibrationRegistration {
    static func registerAll() {
        StepRegistry.register(CalibrationIntroView.self)
        StepRegistry.register(CalibrationSessionView.self)
        StepRegistry.register(CalibrationCompleteView.self)
    }
}
```
Phase 2's new step views (hub, Recommendations trigger, etc.) get their own `*Registration.swift`
enum following this exact shape, then wired into the single bootstrap file
(`RithamApp/Ritham/App/StepBootstrap.swift`, not modified by this pattern map but the integration
point every registrar plugs into) — do not append to an existing registrar.

**Analog for the Recommendations surface as an opened-screen:**
`RithamApp/Ritham/Settings/DietPlanView.swift`'s pattern of "opened from a list entry point as its
own screen" — see `SettingsView.swift`'s `SecondaryCTAButton(title: "Diet plan") { isEditingDietPlan
= true }` + `.sheet(isPresented:)` pairing (lines 65-67, 87-89) as the concrete wiring to copy for
D-03's "dedicated Recommendations surface... explicit ask."

---

## Shared Patterns

### Condition-tag gate reads (read-only, do not rebuild)
**Source:** `RithamCore/Sources/RithamCore/Screening/GateResolution.swift` /
`GateEscalation.swift` / `ClearanceGate.swift`
**Apply to:** Every Guidance file, the weight-loss-goal-setting UI if built, the Go API's
`guidancePermission` field derivation.
Phase 2 reads `HealthDataStore.activeConditionTags(now:)` → `GateResolution.resolve(...)` →
`GateResolutionResult.gates.workout`/`.nutrition` — never re-derives gating logic. This is already
fully implemented and tested; Phase 2's only new RithamCore work in this area is the
`ContentPermission` content-layer addition (Pattern 1 above), never a gate-level change.

### Disclaimer/blocking UI (reuse verbatim)
**Source:** `RithamApp/Ritham/Disclaimers/{ConditionDisclaimerTag,RequiredBlockingMessageView,
StandingFooterDisclaimer}.swift`
**Apply to:** All Guidance views, any workout/nutrition suggestion surface during logging/planning
(HEALTH-03/04 surfacing, per Claude's Discretion).

### Persistence facade (extend, never duplicate)
**Source:** `RithamApp/Ritham/Persistence/HealthDataStore.swift`
**Apply to:** All new SwiftData model read/write needs (cardio sessions, lift sessions/sets,
frequency preference). One class, one `ModelContext`, typed error enum — never a second store.

### Settings-editable, gate-isolated preference (DIET-01's own pattern)
**Source:** `RithamApp/Ritham/Settings/DietPlanView.swift`'s `persistDiet` method (lines 155-162)
**Apply to:** The workout-frequency preference (Claude's Discretion: "set once as an editable
Settings preference, same pattern as DIET-01").
```swift
private func persistDiet(_ pattern: DietaryPattern) {
    let store = HealthDataStore(context: modelContext)
    guard let existingAge = try? store.loadProfile().age else { return }
    try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
}
```
Copy this isolation discipline exactly: the frequency write must never call
`GateResolution`/`saveScreeningResult` — it is a preference, not a screening answer.

### Verbatim-transcribed content catalogs (never live-generated)
**Source:** `RithamCore/Sources/RithamCore/Copy/{ScreeningCopy,OnboardingCopy}.swift` (Phase 1
precedent, cited via RESEARCH.md Pattern 2 — not re-read this session) +
`GateEscalation.swift`'s exhaustive-switch discipline
**Apply to:** `WorkoutGuidanceCatalog`, `NutritionGuidanceCatalog`, `DietarySwapCatalog` — every
string transcribed verbatim from `docs/health-screening.md` §2/§3 and `docs/dietary-pattern.md`
§3/§4, each carrying a "pending LAUNCH-01/02/03 review, ships as-is" header comment.

---

## No Analog Found

Files with no close match in the codebase — planner should use RESEARCH.md's cited patterns
instead:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `RithamCore/Sources/RithamCore/Cardio/GradeAdjustedPace.swift` | utility | transform | Pure new math (grade % + pace → adjusted pace); no prior numeric-transform utility exists in RithamCore. Use RESEARCH.md's GAP-formula citation (Standard Stack / `CMAltimeter` note) as the spec. |
| `RithamCore/Sources/RithamCore/Strength/PlateCalculator.swift` | utility | transform | Pure new greedy algorithm; RESEARCH.md Pattern 4 (lines with the full `nearestLoadablePlates` example) is the authoritative spec, cross-referenced from WebSearch, not a codebase analog. |
| `RithamApp/Ritham/Charts/Views/*` | component | request-response | First Swift Charts usage anywhere in the repo (Phase 1 has no history/progress visualization). Use RESEARCH.md's Standard Stack `Chart`/`LineMark`/`BarMark` citation directly; no in-repo `Chart` usage to copy indentation/structure from. |
| `RithamService/cmd/ritham-service/main.go` | config/entrypoint | request-response | **First Go file in the repo — no analog exists by design (D-06 is the first Go-backend decision in this project's history).** Follow RESEARCH.md's "Go Backend Research" §1 (`net/http` + Go 1.22+ enhanced `ServeMux`, no framework) and §2 (`cmd/ritham-service/main.go` wires router + `http.ListenAndServe`, per `golang-standards/project-layout`). |
| `RithamService/internal/plan/generate.go` | service | request-response | Same — no Go analog exists. RESEARCH.md §2/§3: pure function `plan.Generate(frequencyPerWeek, experienceLevel, guidancePermission)`, no HTTP concerns, unit-tested directly via table-driven `testing` (§6). |
| `RithamService/internal/httpapi/handler.go` | controller | request-response | Same — no Go analog exists. RESEARCH.md §3: single `POST /v1/workout-plan` handler — decode JSON request → call `plan.Generate` → encode JSON response, each step's error checked and responded to independently (§7 pitfall on error handling). Request/response JSON shape is spelled out in full in RESEARCH.md §3 (`frequencyPerWeek`/`experienceLevel`/`guidancePermission` in, `plan` object out) and the D-07 minimization rule (§4: never send raw `ConditionTag`s, only the pre-resolved three-value `guidancePermission` gate enum) governs what the request struct may contain. |
| `RithamService/internal/httpapi/handler_test.go` / `internal/plan/generate_test.go` | test | request-response | No Go test in repo to copy from. RESEARCH.md §6: standard library `testing` + `net/http/httptest` (`NewRequest`/`NewRecorder`), no `testify`/`ginkgo` — mirrors the Swift side's "native platform tooling only" discipline (XCTest / Swift Testing). |
| `RithamService/go.mod` | config | — | No Go module file in repo. Standard `go mod init` output; RESEARCH.md §7 notes there is no version field to fill in (Go versions via git tags, not `go.mod`). |

## Metadata

**Analog search scope:** `RithamCore/Sources/RithamCore/` (Calibration, Screening, Copy,
Onboarding), `RithamApp/Ritham/` (Calibration, Disclaimers, Persistence, Settings, Onboarding/Steps,
App), full recursive listing of both trees for file-existence confirmation.
**Files scanned directly (Read):** `CalibrationSession.swift`, `HealthDataStore.swift`,
`GateEscalation.swift`, `ClearanceGate.swift`, `DietPlanView.swift`, `SettingsView.swift`,
`ConditionDisclaimerTag.swift`, `RequiredBlockingMessageView.swift`,
`CalibrationBaselineRecord.swift`, `StopwatchSession.swift`, `HomeStepView.swift`,
`CalibrationRegistration.swift`, plus `OnboardingRouter.swift` (grepped for `.home` wiring).
**Go-side scope note:** `RithamService/` does not exist yet in this repo. Per the task's explicit
instruction, no Go analog search was performed — all Go pattern guidance above is sourced directly
from `02-RESEARCH.md`'s "Go Backend Research" appended section (§1–§7), which itself cites
WebSearch sources and directly-run `go doc`/`go version` output from this session's environment.
**Pattern extraction date:** 2026-09-04
