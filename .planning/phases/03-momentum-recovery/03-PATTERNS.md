# Phase 3: Momentum & Recovery - Pattern Map

**Mapped:** 2026-09-06
**Files analyzed:** 19 (new/modified files from RESEARCH.md's "Recommended Project Structure" plus UI-SPEC component inventory)
**Analogs found:** 19 / 19 (all files have at least a role-match analog; several have exact analogs already named verbatim in RESEARCH.md)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `RithamCore/Sources/RithamCore/Momentum/MomentumWeek.swift` | utility (pure domain) | transform | `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift` | exact |
| `RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift` | model (value type) | transform | `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift` (`ProfessionalClearance` struct shape) | role-match |
| `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift` | service (pure fold) | batch/event-driven | `RithamCore/Sources/RithamCore/Cardio/CardioSession.swift` (`CardioQualification.evaluate`) + `ConditionTagValidity.validity` | role-match |
| `RithamCore/Sources/RithamCore/Momentum/MomentumTarget.swift` | utility (validation) | transform | `RithamApp/Ritham/Persistence/HealthDataStore.swift` (`supportedWeeklyFrequencies` guard, lines ~ near `saveWeeklyFrequency`) | role-match |
| `RithamCore/Sources/RithamCore/Momentum/SleepAdjustment.swift` | utility (decision rule) | transform | `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift` (pure enum + static function shape) | role-match |
| `RithamApp/Ritham/Persistence/MomentumLedgerRecord.swift` | model (SwiftData `@Model`) | CRUD | `RithamApp/Ritham/Persistence/CardioSessionRecord.swift` / `HealthDataStore`'s `WorkoutPreferenceRecord` | exact (named directly in RESEARCH.md) |
| `RithamApp/Ritham/Persistence/SleepCheckInRecord.swift` | model (SwiftData `@Model`) | CRUD | `RithamApp/Ritham/Persistence/CardioSessionRecord.swift` (one-row-per-instance pattern) | exact |
| `RithamApp/Ritham/Persistence/MovementSnapshotRecord.swift` | model (SwiftData `@Model`) | CRUD | `RithamApp/Ritham/Persistence/CardioSessionRecord.swift` | exact |
| `RithamApp/Ritham/Persistence/HealthDataStore.swift` (extended) | service (persistence facade) | CRUD | itself — extend existing file, mirroring `loadCardioSessions(in:)`/`saveWeeklyFrequency` | exact |
| `RithamApp/Ritham/Momentum/Views/MomentumView.swift` | component (SwiftUI screen) | request-response | `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` (detail screen, Model/View split) | role-match |
| `RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift` | component (SwiftUI screen) | request-response | `RithamApp/Ritham/Settings/DietPlanView.swift` (`ChoiceQuestionView` chip pattern + optional note) | exact |
| `RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift` | component (SwiftUI screen) | request-response | `RithamApp/Ritham/Settings/WorkoutFrequencyView.swift` | exact (UI-SPEC names this directly) |
| `RithamApp/Ritham/Momentum/MomentumRegistration.swift` | config (StepRegistry registrar) | event-driven | `RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift` | exact |
| `RithamApp/Ritham/Momentum/MomentumSummary.swift` | service (standalone queryable read) | request-response | `RithamApp/Ritham/Persistence/HealthDataStore.swift` read accessors (e.g. `loadCardioSessions(in:)`) | role-match |
| `RithamApp/Ritham/Settings/MovementSnapshotView.swift` | component (SwiftUI screen) | request-response | `RithamApp/Ritham/Settings/DietPlanView.swift` (opt-in toggle pattern, `ChoiceQuestionView` Yes/No) | role-match |
| `RithamApp/Ritham/Recommendations/RecommendationsModel.swift` (modified) | service (view model) | transform | itself — existing file, add `SleepAdjustment.apply` post-processing step | exact |
| `RithamApp/Ritham/Home/HomeHubView.swift` (modified) | component (SwiftUI screen) | request-response | itself — existing file, add Momentum summary section | exact |
| `RithamApp/Ritham/Settings/SettingsView.swift` (modified) | component (SwiftUI screen) | request-response | itself — existing file, add Movement Snapshot toggle + Momentum target entries (same shape as existing `DietPlanView`/frequency entries) | exact |
| `RithamCore/Tests/RithamCoreTests/MomentumWeekTests.swift`, `MomentumReconciliationTests.swift` | test | batch | `RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift` / a hypothetical `ConditionTagValidityTests.swift`-style suite | role-match |
| `RithamApp/RithamTests/MomentumStoreTests.swift`, `MovementSnapshotTests.swift`, `RecoveryAdjustmentTests.swift` | test | batch | `RithamApp/RithamTests/HealthDataStoreTests.swift` | exact |

## Pattern Assignments

### `RithamCore/Sources/RithamCore/Momentum/MomentumWeek.swift` (utility, transform)

**Analog:** `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift`

**Imports pattern** (line 1):
```swift
import Foundation
```
No other imports — this is a pure `RithamCore` domain file with zero SwiftData/UIKit/network imports (confirmed rule: "Calling `Date()` or `Calendar.current` inside `RithamCore` ... every `RithamCore` Momentum function takes `calendar: Calendar` and, where relevant, `now: Date` as required (non-defaulted) parameters").

**Core pattern — injected-Calendar pure static function** (lines 38-45, 50-66):
```swift
public static func expiry(from recordedAt: Date, calendar: Calendar) -> Date {
    calendar.date(byAdding: .month, value: validityWindowMonths, to: recordedAt) ?? recordedAt
}

public static func validity(recordedAt: Date, now: Date, calendar: Calendar) -> TagValidity {
    validity(recordedAt: recordedAt, editedAt: nil, now: now, calendar: calendar)
}
```
Apply this exact shape to `MomentumWeek.weekStart(containing now: Date, calendar: Calendar) -> Date` (already sketched concretely in `03-RESEARCH.md`'s Week-Boundary Arithmetic section — reuse that implementation verbatim, it already follows this file's fail-safe/no-force-unwrap discipline).

**Error handling / fail-safe pattern** (lines 39-44, comment):
```swift
// `calendar.date(byAdding:)` only returns nil on an out-of-range overflow, which is
// not reachable for realistic recorded dates. If it ever were, falling back to
// `recordedAt` itself ... keeps the fail-safe direction consistent...
calendar.date(byAdding: .month, value: validityWindowMonths, to: recordedAt) ?? recordedAt
```
Momentum's boundary function must use the same "fail-safe, never crash, document the direction of the fallback" discipline — never `try!`/force-unwrap on `Calendar` optionals.

**Doc-comment convention** (lines 3-5, type-level header):
```swift
// HEALTH-02's twelve-month condition-tag validity rule (docs/health-screening.md §1.6), as a
// pure function of dates so it is testable before Xcode exists on this machine. The SwiftData
// model (plan 01-11) calls into these functions rather than reimplementing the rule.
```
`MomentumWeek.swift`'s header should follow the same "requirement ID + why pure + who calls it" three-part shape.

---

### `RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift` (model, transform)

**Analog:** `ConditionTagValidity.swift`'s `ProfessionalClearance` struct (lines 78-90)

**Core pattern — dated-grant value type, not a standing boolean** (lines 76-90):
```swift
public struct ProfessionalClearance: Sendable, Equatable {
    public var grantedAt: Date

    public init(grantedAt: Date) {
        self.grantedAt = grantedAt
    }

    public func needsReConfirmation(now: Date, calendar: Calendar) -> Bool {
        ConditionTagValidity.isReScreenDue(recordedAt: grantedAt, now: now, calendar: calendar)
    }
}
```
Mirror this for `MilestoneAward`, `ComebackWindow`, `RecoveryWeekPeriod`, `InjuryFreezePeriod` value types: `Sendable, Equatable` structs with dated fields and pure query methods (`isOpen(now:)`, `covers(weekStart:)`), never a computed boolean baked directly into a mutable class. `MomentumLedger` itself should be a `Sendable, Equatable` struct aggregating `currentStreak: Int`, `shieldCount: Int`, `lastReconciledWeekStart: Date`, plus `[MilestoneAward]`/`[ComebackWindow]` arrays — matching Data Model Shape from `03-RESEARCH.md`.

---

### `RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift` (service, batch/event-driven)

**Analog:** `CardioQualification.evaluate` (`RithamCore/Sources/RithamCore/Cardio/CardioSession.swift`) + `ConditionTagValidity.validity`

**Core pattern — pure enum-returning evaluator, reused not reimplemented**:
```swift
public enum CardioQualification: Sendable, Equatable {
    case incomplete
    case complete
    public static func evaluate(_ progress: CardioProgress) -> CardioQualification {
        progress.continuousDuration >= CalibrationThreshold.qualifyingWalkDuration ? .complete : .incomplete
    }
}
```
`MomentumReconciliation.reconcile(sessions:ledger:guardrails:now:calendar:) -> MomentumLedger` must call `CardioQualification.evaluate`/`LiftQualification.evaluate` directly — never re-derive the `>= 600` / `>= 3 sets, >= 2 exercises` thresholds. This is a **Don't Hand-Roll** requirement, not a style preference.

**Idempotence discipline** — no direct code analog exists in-repo (this is new mechanic surface), but the precedent for "pure fold, testable without a live clock" is `ConditionTagValidity.validity`'s three-parameter signature (`recordedAt`, `now`, `calendar`, no internal `Date()`); `MomentumReconciliation.reconcile` must follow the identical no-internal-`Date()` shape.

---

### `RithamApp/Ritham/Persistence/HealthDataStore.swift` (extended; service, CRUD)

**Analog:** itself, existing `loadCardioSessions`/`loadCardioSessions(in:)`/`saveWeeklyFrequency` methods

**Range-query pattern** (lines 352-365):
```swift
public func loadCardioSessions(in range: ClosedRange<Date>) throws -> [CardioSession] {
    let lowerBound = range.lowerBound
    let upperBound = range.upperBound
    let predicate = #Predicate<CardioSessionRecord> { record in
        record.startedAt >= lowerBound && record.startedAt <= upperBound
    }
    let records = try context.fetch(FetchDescriptor<CardioSessionRecord>(
        predicate: predicate,
        sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
    ))
    return records.compactMap(\.session)
}
```
New methods `loadSleepCheckIn(for:)`, `loadSnapshotEntries(in:)`, `loadMilestoneAwards()`, `loadComebackWindows()` must mirror this exact `#Predicate` + `FetchDescriptor` + `compactMap`/`.map` shape.

**Single-row upsert pattern** (referenced directly in RESEARCH.md, lines 344-353 of RESEARCH.md, sourced from `HealthDataStore.swift` lines 509-578):
```swift
public func loadWeeklyFrequency() throws -> Int {
    try loadWorkoutPreferenceRecord()?.weeklyFrequency ?? 3
}
public func saveWeeklyFrequency(_ frequency: Int) throws {
    guard Self.supportedWeeklyFrequencies.contains(frequency) else {
        throw HealthDataStoreError.unsupportedWeeklyFrequency
    }
    try upsertWorkoutPreference { $0.weeklyFrequency = frequency }
}
```
`saveMomentumTarget(_:)`/`loadMomentumTarget()` and the `MomentumStateRecord` scalar fields (`currentStreak`, `shieldCount`, `lastReconciledWeekStart`) must reuse this exact upsert-with-guard-and-throw shape, with a new `HealthDataStoreError.unsupportedMomentumTarget` case and `supportedMomentumTargets: Set<Int> = [2,3,4,5]` constant.

**Error handling pattern** (lines 371-377, 435-439):
```swift
public func deleteCardioSession(id: UUID) throws {
    guard let record = try fetchCardioSessionRecord(id: id) else {
        throw HealthDataStoreError.sessionNotFound
    }
    context.delete(record)
    try context.save()
}
```
All new Momentum store methods throw typed `HealthDataStoreError` cases rather than returning optionals/booleans for failure — same discipline throughout the file.

**Save pattern with delete-then-reinsert idempotence** (lines 390-406):
```swift
public func saveLiftSession(_ session: LiftSession) throws {
    if let existing = try fetchLiftSessionRecord(id: session.id) {
        context.delete(existing)
    }
    for record in try fetchLiftSetRecords(sessionID: session.id) {
        context.delete(record)
    }
    context.insert(LiftSessionRecord(...))
    for set in session.sets {
        context.insert(LiftSetRecord(set: set, sessionID: session.id))
    }
    try context.save()
}
```
Relevant for append-only `MilestoneAwardRecord`/`ComebackWindowRecord` writes if reconciliation ever needs to correct an in-flight (unclosed) comeback window record rather than a full duplicate — otherwise these are pure inserts, no delete-then-reinsert needed since they're append-only per Data Model Shape.

---

### `RithamApp/Ritham/Momentum/Views/MomentumTargetView.swift` (component, request-response)

**Analog:** `RithamApp/Ritham/Settings/WorkoutFrequencyView.swift` (full file, 97 lines — UI-SPEC Component 10 names this as a direct reuse-with-different-value-set)

**Imports pattern** (lines 1-2):
```swift
import SwiftUI
import RithamCore
```

**Core pattern — sheet-presented fixed-choice preference screen** (lines 38-78):
```swift
struct WorkoutFrequencyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<WeeklyFrequencyOption>
    @State private var showSaveError = false

    init(initialFrequency: Int) {
        _selection = State(initialValue: [WeeklyFrequencyOption(daysPerWeek: initialFrequency)])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Workout frequency") {
            Text("...")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            ChoiceQuestionView(
                prompt: "Weekly workout frequency",
                options: WeeklyFrequencyOption.all,
                mode: .single,
                selection: $selection,
                optionTitle: Self.optionTitle
            )

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: "Done") {
                dismiss()
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let chosen = newValue.first else { return }
            persist(chosen.daysPerWeek)
        }
    }
```

**Persistence-call pattern (error handling)** (lines 88-96):
```swift
private func persist(_ frequency: Int) {
    let store = HealthDataStore(context: modelContext)
    do {
        try store.saveWeeklyFrequency(frequency)
        showSaveError = false
    } catch {
        showSaveError = true
    }
}
```
`MomentumTargetView` copies this file nearly verbatim: rename `WeeklyFrequencyOption` → `MomentumTargetOption`, `[3, 5, 7]` → `[2, 3, 4, 5]`, `saveWeeklyFrequency` → `saveMomentumTarget`, prompt text per UI-SPEC's verbatim copy ("Weekly Momentum target" / helper text), surface stays `.flat`.

---

### `RithamApp/Ritham/Momentum/Views/SleepCheckInView.swift` / `MovementSnapshotView.swift` (component, request-response)

**Analog:** `RithamApp/Ritham/Settings/DietPlanView.swift` (not fully read this session, but confirmed by RESEARCH.md/UI-SPEC as the direct precedent for `ChoiceQuestionView` chip pattern with Yes/No or multi-option severity questions, and the opt-in-preference pattern)

**Core pattern (inferred from `WorkoutFrequencyView`'s shared `ChoiceQuestionView` usage, confirmed applicable per UI-SPEC Component 6/9):**
```swift
ChoiceQuestionView(
    prompt: "How did you sleep?",
    options: SleepQualityOption.all,   // Great / OK / Poor
    mode: .single,
    selection: $selection,
    optionTitle: Self.optionTitle
)
```
`MovementSnapshotView`'s Settings toggle uses the same `ChoiceQuestionView` with a two-option Yes/No-style set (UI-SPEC Component 9 explicitly rules out `SwiftUI.Toggle` — there is zero `Toggle` precedent anywhere in this codebase; reuse `ChoiceChip`/`ChoiceQuestionView` exclusively for this on/off state, labeled "On"/"Off").

---

### `RithamApp/Ritham/Momentum/MomentumRegistration.swift` (config, event-driven)

**Analog:** `RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift` (full file, 13 lines)

**Full pattern to copy directly:**
```swift
import SwiftUI
import RithamCore

@MainActor
enum RecommendationsRegistration {
    static func registerAll() {
        StepRegistry.register(RecommendationsView.self)
        StepRegistry.register(PreAssessmentView.self)
    }
}
```
`MomentumRegistration.registerAll()` registers `MomentumView.self`, `SleepCheckInView.self`, `MovementSnapshotView.self`, `MomentumTargetView.self` (whichever become new `OnboardingStep` cases per Pattern 4 in RESEARCH.md) — same `@MainActor enum`, single owner file, and its call **must** be added to `StepBootstrap.registerAllSteps()`'s list (Pitfall 4 — `PhaseCoverageTests.unregisteredStepsIsEmpty` is an existing, already-instrumented gate that fails the whole suite otherwise).

---

### `RithamApp/Ritham/Home/HomeHubView.swift` (modified; component, request-response)

**Analog:** itself (full file, 68 lines)

**Core pattern — `RithamScreen` + `flow.open(_:)` navigation, no second nav container** (lines 25-54):
```swift
var body: some View {
    RithamScreen(
        surface: DecorativeSurface.boundedHeaderOnly,
        headline: "Your interim home",
        bodyText: "..."
    ) {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            PrimaryCTAButton(title: "Track cardio") {
                flow.open(.cardioActivityPicker)
            }
            ...
        }
    }
    .sheet(isPresented: $isPresentingSettings) { SettingsView(...) }
}
```
Add a new Momentum summary section (per D-08) inside the existing `VStack`, below the header (never inside the header/`boundedHeaderOnly` decorative region — the `MomentumProgressBlocks` component from UI-SPEC must render here). Add a `PrimaryCTAButton`/`SecondaryCTAButton` pair routing via `flow.open(.momentum)` matching the existing `flow.open(.cardioActivityPicker)` shape — no new navigation container.

---

## Shared Patterns

### Injected-Calendar, no-`Date()`-in-RithamCore discipline
**Source:** `RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift` (whole file)
**Apply to:** `MomentumWeek.swift`, `MomentumReconciliation.swift`, `MomentumTarget.swift`, `SleepAdjustment.swift` — every `RithamCore` Momentum function takes `calendar: Calendar` and `now: Date` as required, non-defaulted parameters. Never `Calendar.current`/bare `Date()` inside `RithamCore`; only `RithamApp` call sites supply concrete `.current`/`Date()` arguments.

### Settings preference: guard against a fixed `Set<Int>`, throw a typed error
**Source:** `RithamApp/Ritham/Persistence/HealthDataStore.swift`, `saveWeeklyFrequency`/`supportedWeeklyFrequencies`
**Apply to:** `saveMomentumTarget`/`supportedMomentumTargets` — identical guard-and-throw shape, new `HealthDataStoreError` case, never silently clamp.

### Single persistence facade, extended not duplicated
**Source:** `RithamApp/Ritham/Persistence/HealthDataStore.swift` (whole file — `@MainActor`-isolated, `context: ModelContext` constructor injection)
**Apply to:** All new Momentum/Sleep/Snapshot read/write methods — added to this one file, never a second store type.

### StepRegistry registration + `PhaseCoverageTests` gate
**Source:** `RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift`
**Apply to:** Every new full-screen `OnboardingStep` case this phase adds (`MomentumView`, `SleepCheckInView`, `MovementSnapshotView`, `MomentumTargetView`) — new registrar file + call added to `StepBootstrap.registerAllSteps()` in the same commit that adds the `OnboardingStep` cases.

### `ChoiceQuestionView`/`ChoiceChip` as the sole binary/multi-option control
**Source:** `RithamApp/Ritham/Settings/WorkoutFrequencyView.swift` (`ChoiceQuestionView(prompt:options:mode:selection:optionTitle:)`), `DietPlanView.swift` (Yes/No precedent per UI-SPEC)
**Apply to:** Sleep check-in (Great/OK/Poor), Movement Snapshot on/off toggle, Momentum target (2/3/4/5) picker — never `SwiftUI.Toggle` (zero precedent, contrast-fails per UI-SPEC Component 9).

### `RithamScreen(surface: DecorativeSurface.flat, ...)` wrapper for health-adjacent screens
**Source:** `WorkoutFrequencyView.swift` line 49
**Apply to:** `MomentumView`, `SleepCheckInView`, `MovementSnapshotView`, `MomentumTargetView` — all `.flat` per UI-SPEC's Decorative Surface Assignments table.

### Inline save-error text pattern
**Source:** `WorkoutFrequencyView.swift` lines 63-68, reusing `OnboardingCopy.Errors.savingFailed`
**Apply to:** Every new Settings/Momentum screen with a persistence call — reuse the exact string, never draft a second error string (UI-SPEC's Copywriting Contract explicitly requires this).

## No Analog Found

None. Every file in the "Recommended Project Structure" and UI-SPEC's Component Inventory has at least a role-match analog in the existing codebase, largely because RESEARCH.md's own "Don't Hand-Roll" section already identifies exact reuse targets for the domain logic, and Phase 2 already established every UI/persistence shape this phase's new screens/records need to mirror.

## Metadata

**Analog search scope:** `RithamCore/Sources/RithamCore/{Screening,Cardio,Strength,Calibration}/`, `RithamApp/Ritham/{Persistence,Settings,Recommendations,Home,Cardio/Views}/`, `RithamApp/RithamTests/`, `RithamCore/Tests/RithamCoreTests/`
**Files scanned:** 15 direct reads/greps across the above directories, plus full reads of `03-CONTEXT.md`, `03-RESEARCH.md`, `03-UI-SPEC.md`
**Pattern extraction date:** 2026-09-06
