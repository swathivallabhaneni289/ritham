# Phase 4: Household & Home - Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 6
**Analogs found:** 6 / 6 (all analogs are the files being modified themselves — this is a
re-parenting refactor, not new-feature construction; 04-RESEARCH.md already identifies the
extraction targets verbatim. This document supplies exact line-numbered excerpts for the planner.)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `RithamApp/Ritham/Home/HomeHubView.swift` (rewritten body, same type/file) | component (screen composition) | request-response (reads on `.onAppear`, pushes via `flow.open`) | itself (current version, pre-rewrite) | exact — same file, body-only rewrite |
| `RithamApp/Ritham/Momentum/Components/MomentumDashboardSection.swift` (new) | component | CRUD (read-only) | `HomeHubView.swift`'s current `momentumSection` computed var (lines 152-190) | exact — verbatim extraction |
| `RithamApp/Ritham/Recommendations/Views/RecommendationsSectionContent.swift` (new) | component | request-response (async plan fetch) | `RecommendationsView.swift`'s current `content`/`idleContent`/`planContent`/`errorContent` (lines 161-251) | exact — verbatim extraction |
| `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` (modified) | component (thin screen wrapper) | request-response | itself (current version) — becomes `RithamScreen` + delegate to extracted content | exact — same file, thinned |
| `RithamApp/Ritham/Settings/DietPlanSectionContent.swift` (new) | component | CRUD (local persist only, DIET-01-isolated) | `DietPlanView.swift`'s current diet-pattern/allergen picker block (lines 62-70, 88-96, 109-113, 118-121, 158-171) | exact — verbatim extraction, screening checkbox excluded (Pitfall 3) |
| `RithamApp/Ritham/Settings/DietPlanView.swift` (modified) | component (thin Settings-presented screen) | CRUD + event-driven (screening re-resolve) | itself (current version) — keeps screening checkbox/severity/`dismiss()`, delegates diet-pattern/allergen UI to extracted content | exact — same file, thinned |

## Pattern Assignments

### `RithamApp/Ritham/Home/HomeHubView.swift` (rewritten body)

**Analog:** itself, current version at same path (read in full above).

**Imports pattern** (lines 1-2, unchanged):
```swift
import SwiftUI
import RithamCore
```

**State/onAppear read pattern to preserve verbatim** (lines 33-46, 113-128):
```swift
@State private var momentumSummary: MomentumSummary?
@State private var momentumLoadFailed = false
@State private var isMovementSnapshotEnabled = false
// ...
.onAppear {
    let store = HealthDataStore(context: modelContext)
    let reader = MomentumSummaryReader(store: store, calendar: .current)
    do {
        momentumSummary = try reader.summary(now: Date())
        momentumLoadFailed = false
    } catch {
        momentumSummary = nil
        momentumLoadFailed = true
    }
    isMovementSnapshotEnabled = (try? store.loadMovementSnapshotOptIn()) ?? false
}
```
This entire block moves into the rewritten `HomeHubView.body`/`onAppear` unchanged — only the
`RithamScreen` headline/bodyText and the content closure's contents change. Do not move this state
loading into `MomentumDashboardSection` itself (D-08/03-CONTEXT precedent: no dashboard-specific
aggregate view model — `HomeHubView` still owns and passes `momentumSummary`/`momentumLoadFailed`
down to the new component as parameters).

**Screen scaffold to preserve, headline/bodyText to change** (lines 48-53):
```swift
RithamScreen(
    surface: DecorativeSurface.boundedHeaderOnly,
    headline: "Your interim home",              // REPLACE: e.g. "Home" — never "temporary"/"interim"
    bodyText: "This is a temporary hub..."        // DELETE entirely, per UI-SPEC
) {
    VStack(alignment: .leading, spacing: RithamSpacing.md) { /* sections here */ }
}
```

**Pure-derivation pattern to preserve and update** (lines 198-220):
```swift
extension HomeHubView {
    nonisolated static func showsMovementSnapshotEntry(optIn: Bool) -> Bool {
        optIn
    }
    nonisolated static func routingSteps(movementSnapshotOptIn: Bool) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .sleepCheckIn, .cardioActivityPicker, .cardioHistory,
            .strengthSession, .strengthHistory, .guidance, .recommendations,
        ]
        if showsMovementSnapshotEntry(optIn: movementSnapshotOptIn) {
            steps.append(.movementSnapshot)
        }
        return steps
    }
}
```
**Required edit (04-RESEARCH.md Pattern 3):** remove `.recommendations` from the `steps` array —
the dashboard no longer calls `flow.open(.recommendations)` from a button once D-04 embeds the plan
inline. Keep the `extension HomeHubView { ... }` declaration and the exact preceding
`MARK: - D-08's Momentum summary section` comment string (see Shared Patterns → Test-Coupled
Markers below) even though the `momentumSection` var itself moves out of this file.

**Entry-point buttons to relocate (not delete) into the new exercise section** (lines 75-92):
```swift
PrimaryCTAButton(title: "Track cardio") { flow.open(.cardioActivityPicker) }
SecondaryCTAButton(title: "Cardio history") { flow.open(.cardioHistory) }
PrimaryCTAButton(title: "Log strength") { flow.open(.strengthSession) }
SecondaryCTAButton(title: "Strength history") { flow.open(.strengthHistory) }
```
Move these (unchanged) inside the exercise/logged-activity Dashboard Section Card (UI-SPEC section
3), adjacent to `MomentumSummary.recentSessions` rendering — not as a leftover vertical stack.

**Sleep entry point, unchanged, D-03 carry-forward** (lines 71-73):
```swift
SecondaryCTAButton(title: MomentumCopy.Sleep.headline) {
    flow.open(.sleepCheckIn)
}
```

**Movement Snapshot conditional entry, unchanged, relocate adjacent to exercise section (Pitfall 6)** (lines 102-106):
```swift
if HomeHubView.showsMovementSnapshotEntry(optIn: isMovementSnapshotEnabled) {
    SecondaryCTAButton(title: "Daily Movement Snapshot") {
        flow.open(.movementSnapshot)
    }
}
```

**Guidance/Settings overflow, unchanged logic, restyle as compact overflow per UI-SPEC section 6** (lines 87-89, 108-110, 129-140):
```swift
PrimaryCTAButton(title: "Guidance") { flow.open(.guidance) }
// ...
SecondaryCTAButton(title: "Settings") { isPresentingSettings = true }
// ...
.sheet(isPresented: $isPresentingSettings) {
    SettingsView(flow: flow, onOpenHealthProfile: { ... })
}
.sheet(isPresented: $isPresentingHealthProfile) { HealthProfileView() }
```

---

### `RithamApp/Ritham/Momentum/Components/MomentumDashboardSection.swift` (new)

**Analog:** `HomeHubView.swift`'s current `momentumSection` (lines 152-190, read in full above).

**Extraction pattern** — move the `@ViewBuilder private var momentumSection` body verbatim into a
new standalone `View` struct, parameterized instead of closing over `self`:
```swift
// NEW FILE — Ritham/Momentum/Components/MomentumDashboardSection.swift
// Placed here (not Ritham/Home/) specifically so Phase3CoverageTests's directory-walk
// no-sharing gate (which scans Ritham/Momentum/ and Ritham/MovementSnapshot/) automatically
// covers this section with zero test-file edits (04-RESEARCH.md Pitfall 2).
import SwiftUI
import RithamCore

struct MomentumDashboardSection: View {
    let summary: MomentumSummary?
    let loadFailed: Bool
    let flow: OnboardingFlow

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                MomentumProgressBlocks(filled: summary.displayedCount, target: summary.weeklyTarget)
                Text(MomentumView.streakLine(for: summary))
                    .font(RithamType.heading)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)
                ShieldRow(earned: summary.shieldCount, maximum: MomentumLedger.maxShields)
                if summary.recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                        Text(MomentumCopy.Empty.noSessionsHeadline)
                            .font(RithamType.body.weight(.semibold))
                            .foregroundStyle(RithamColor.paper)
                        Text(MomentumCopy.Empty.noSessionsBody)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                PrimaryCTAButton(title: "Momentum") { flow.open(.momentum) }
            }
        } else if loadFailed {
            Text(OnboardingCopy.Errors.savingFailed)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```
Wrap the call site in `HomeHubView` with the Dashboard Section Card modifier (see Shared Patterns).
No logic differs from today's `momentumSection` — this is a mechanical cut-and-paste, per
04-RESEARCH.md's own "Don't Hand-Roll" instruction.

---

### `RithamApp/Ritham/Recommendations/Views/RecommendationsSectionContent.swift` (new)

**Analog:** `RecommendationsView.swift`'s current `content`/`idleContent`/`planContent`/`errorContent` (lines 161-251, read in full above).

**Extraction pattern:**
```swift
// NEW FILE — Ritham/Recommendations/Views/RecommendationsSectionContent.swift
import SwiftUI
import RithamCore

struct RecommendationsSectionContent: View {
    let model: RecommendationsModel
    let flow: OnboardingFlow

    var body: some View {
        switch model.state {
        case .idle:
            idleContent
        case .loading:
            ProgressView("Building your plan...")
                .foregroundStyle(RithamColor.paper)
        case .plan(let plan):
            planContent(plan)
        case .error(let error):
            errorContent(error)
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("Get a plan built around your stored weekly frequency and starting point.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
            PrimaryCTAButton(title: "Get my plan") { request() }
        }
    }

    @ViewBuilder
    private func planContent(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            if model.adjustedPlan != nil {
                Text(MomentumCopy.Plan.banner)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryCTAButton(
                    title: model.isDisplayingAdjustedPlan ? MomentumCopy.Plan.showOriginalCTA : MomentumCopy.Plan.showLighterCTA
                ) { model.toggleDisplayedPlan() }
            }
            ForEach(plan.sessions) { session in
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text("Day \(session.dayIndex): \(session.focus)")
                        .font(RithamType.body.weight(.semibold))
                    ForEach(session.exercises, id: \.name) { exercise in
                        Text("\(exercise.name) -- \(exercise.sets) sets, \(exercise.repRange) reps")
                    }
                }
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
            }
            Text(plan.guidanceNote)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func errorContent(_ error: WorkoutPlanClientError) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("We couldn't reach the plan service. Check your connection and try again.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryCTAButton(title: "Retry") { request() }
        }
    }

    private func request() {
        Task { await model.requestPlan(flow: flow) }
    }
}
```
Note the original methods took `model` as a parameter (module-level free functions on the view);
this version closes over `let model: RecommendationsModel` as a stored property instead, since it's
now a standalone struct rather than private methods on `RecommendationsView`. Behavior is identical
— same state machine, same `requestPlan`/`toggleDisplayedPlan` calls, same copy strings verbatim.

**RecommendationsView.swift becomes a thin wrapper (Pitfall 4 — stays registered):**
```swift
struct RecommendationsView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .recommendations
    static func makeView(flow: OnboardingFlow) -> AnyView { AnyView(RecommendationsView(flow: flow)) }
    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var model: RecommendationsModel?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Recommendations") {
            if let model {
                RecommendationsSectionContent(model: model, flow: flow)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil {
                model = RecommendationsModel(store: HealthDataStore(context: modelContext))
            }
        }
    }
}
```
`RecommendationsModel` (lines 32-137 of the current file) is untouched — reused byte-for-byte by
both `RecommendationsView` and the dashboard's workout-plan section.

**HomeHubView's workout-plan section, constructing its own model per D-08's "no aggregate view
model" rule:**
```swift
@State private var recommendationsModel: RecommendationsModel?
// in onAppear, alongside the existing momentum load:
if recommendationsModel == nil {
    recommendationsModel = RecommendationsModel(store: HealthDataStore(context: modelContext))
}
// in body, inside a Dashboard Section Card:
if let recommendationsModel {
    RecommendationsSectionContent(model: recommendationsModel, flow: flow)
} else {
    ProgressView()
}
```

---

### `RithamApp/Ritham/Settings/DietPlanSectionContent.swift` (new)

**Analog:** `DietPlanView.swift`'s current diet-pattern picker and allergen-picker block (lines 62-70, 88-96, 109-113, 118-121, 158-171, read in full above). **Explicitly excludes** the food-allergy
screening checkbox/severity follow-up (lines 51-59, 72-86, 114-117, 176-188) per D-05's narrowed
scope and Pitfall 3.

**Extraction pattern:**
```swift
// NEW FILE — Ritham/Settings/DietPlanSectionContent.swift
// DIET-01-isolated subset only — never calls GateResolution.resolve or saveScreeningResult.
// No food-allergy screening checkbox, no severity follow-up, no "Done"/dismiss() (Pitfall 5):
// this is an always-visible dashboard section, not a modal.
import SwiftUI
import RithamCore

struct DietPlanSectionContent: View {
    let flow: OnboardingFlow
    let modelContext: ModelContext
    @State private var dietSelection: Set<DietaryPattern>
    @State private var allergenSelection: Set<FoodAllergen>
    @State private var showSaveError = false

    init(flow: OnboardingFlow, modelContext: ModelContext) {
        self.flow = flow
        self.modelContext = modelContext
        _dietSelection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
        _allergenSelection = State(initialValue: flow.answers.allergens)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: $dietSelection,
                optionTitle: dietOptionTitle
            )
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.allergensHeadline,
                helper: OnboardingCopy.Diet.allergensHelper,
                options: FoodAllergen.allCases,
                mode: .multiple(exclusiveOption: nil),
                selection: $allergenSelection,
                optionTitle: allergenOptionTitle
            )
            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: dietSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            flow.answers.dietaryPattern = chosen
            persistDiet(chosen)
        }
        .onChange(of: allergenSelection) { _, newValue in
            flow.answers.allergens = newValue
            persistAllergens(newValue)
        }
    }

    // dietOptionTitle / allergenOptionTitle: copy verbatim from DietPlanView.swift lines 124-130, 140-153

    private func persistDiet(_ pattern: DietaryPattern) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
    }
    private func persistAllergens(_ allergens: Set<FoodAllergen>) {
        let store = HealthDataStore(context: modelContext)
        try? store.saveFoodAllergens(allergens)
    }
}
```
`DietPlanView.swift` keeps everything else (screening checkbox, severity follow-up,
`resolveAndSaveScreening`, `dismiss()`/"Done") unchanged, and can either keep its own duplicate diet
picker code or delegate to this new content view for the diet-pattern/allergen portion — planner's
call; either satisfies D-05 as long as the screening checkbox never appears on the dashboard.

---

## Shared Patterns

### Dashboard Section Card (new composition, applies to every dashboard section)
**Source (precedent):** `RithamApp/Ritham/Settings/ReScreenBanner.swift` lines 54-55:
```swift
.background(RithamColor.paper)
.clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
```
**Dashboard variant (per 04-UI-SPEC.md "Dashboard Section Card" table) — do not reuse
`ReScreenBanner`'s solid-paper fill, use a low-opacity tint instead:**
```swift
.padding(RithamSpacing.md)
.frame(maxWidth: .infinity, alignment: .leading)
.background(RithamColor.paper.opacity(0.06))
.clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
```
Apply to: Momentum section, sleep section, exercise section, workout-plan section, diet-plan
section — every entry in `HomeHubView`'s outer `VStack(spacing: RithamSpacing.md)`.

### Test-Coupled Markers (read-only constraint on the rewrite — do not violate)
**Source:** `RithamApp/RithamTests/MovementSnapshotViewTests.swift`,
`RithamApp/RithamTests/Phase3CoverageTests.swift` (not modified by this phase; behavior only
verified against them).
- Keep `HomeHubView`'s file path exactly `RithamApp/Ritham/Home/HomeHubView.swift` and its type name
  exactly `HomeHubView` (Pitfall 1) — the rewrite is a body change, never a rename/relocation.
- Keep the exact comment string `MARK: - D-08's Momentum summary section` immediately before the
  call site that invokes `MomentumDashboardSection` inside the new body, and keep
  `extension HomeHubView { ... }` as the boundary for the `nonisolated static func` derivations at
  the bottom of the file — `MovementSnapshotViewTests` source-scans for both literal strings.
- Place the extracted Momentum rendering physically under `Ritham/Momentum/` (this file is under
  `Ritham/Momentum/Components/`) so `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`'s
  directory-walk automatically covers it with zero test-file edits (Pitfall 2).

### `nonisolated static func` testable-derivation idiom (apply to any new structural/visibility logic)
**Source:** `HomeHubView.swift` lines 198-220 (shown above) and
`RithamApp/Ritham/App/OnboardingRootView.swift`'s `resolvedRootStep` (same idiom, not re-quoted
here — same shape). Any new dashboard visibility/routing decision (e.g. whether a future section
renders) should be a `nonisolated static func` the real `body` calls directly, never duplicated
logic, so Swift Testing can assert it off the main actor without rendering.

### Content-extraction re-parenting (applies to both Recommendations and Diet)
**Source:** 04-RESEARCH.md Pattern 1 (already fully worked out with code — see excerpts above).
Never embed a `RithamScreen`-wrapped struct's `body` directly inside another screen's content
closure (nested `ScrollView`/background/header). Always extract the meaningful content into a plain
child `View` parameterized by the existing model/state, then host that same child view from both
the original full-screen wrapper and the new dashboard section.

## No Analog Found

None — every file in this phase's scope is a refactor/extraction of an existing, already-analyzed
file. No genuinely new domain logic is introduced (04-RESEARCH.md: "every domain behavior this
phase touches is already built and tested in Phase 2/3").

## Metadata

**Analog search scope:** `RithamApp/Ritham/Home/`, `RithamApp/Ritham/Recommendations/Views/`,
`RithamApp/Ritham/Settings/`, `RithamApp/Ritham/Momentum/Components/`
**Files scanned:** `HomeHubView.swift`, `RecommendationsView.swift`, `DietPlanView.swift`,
`ReScreenBanner.swift`, `ShieldRow.swift` (via 04-RESEARCH.md's own prior reads), plus
`MovementSnapshotViewTests.swift`/`Phase3CoverageTests.swift` for marker-coupling constraints
**Pattern extraction date:** 2026-09-08
