# Phase 4: Household & Home - Research

**Researched:** 2026-09-08
**Domain:** SwiftUI dashboard composition, re-parenting existing screens into a sectioned home screen, single-navigation-container constraint (CROSSGEN-05)
**Confidence:** HIGH

## Summary

This round of Phase 4 is a pure SwiftUI composition/refactor problem, not a new-feature build. `HomeHubView` (the interim vertical-button hub) must become a real scrollable dashboard with visible sections, while `RecommendationsView` and `DietPlanView` — both fully built, working screens — get their real content embedded inline as dashboard sections rather than reached by navigating away. No new libraries, no new data models, and no new persistence are required: `MomentumSummaryReader`, `HealthDataStore`, `RecommendationsModel`, and `DietPlanView`'s existing `@State`/persistence functions are all reused unchanged.

The one genuine technical risk is structural, not visual: `RecommendationsView` and `DietPlanView` are each built as a *complete, self-contained screen* — each wraps itself in `RithamScreen`, which renders its own `ZStack{ RithamColor.ink; ScrollView{...} }` and its own `ScreenHeader`. Naively embedding either struct's `body` inside the new dashboard's own `RithamScreen`/`ScrollView` content would nest a second full-screen background, header, and scroll region inside the first — a broken, not-merely-ugly result (nested same-axis `ScrollView`s fight for height and gesture ownership). The correct pattern, confirmed by reading both files, is to extract each screen's *content* (the `@ViewBuilder` switch/body that renders the actual plan/diet UI) into a child view that takes the existing model/bindings as parameters, and have both the dashboard section and (if kept) the full-screen presenter host that same child view. This reuses `RecommendationsModel` and `DietPlanView`'s persistence logic byte-for-byte; only the container changes.

CROSSGEN-05 is not actually at risk here and the doc should say so plainly: `RithamScreen` already supplies the one `ScrollView` this screen needs, `OnboardingRootView` supplies the single app-wide `NavigationStack`, and neither `RecommendationsView` nor `DietPlanView` declares a `NavigationStack`/`NavigationView` of its own. The real constraint to protect is narrower and code-verified: two hardcoded-path test files (`HomeHubTests.swift`, `MovementSnapshotViewTests.swift`) and one directory-walk test (`Phase3CoverageTests.swift`) assert structural facts about `RithamApp/Ritham/Home/HomeHubView.swift`'s literal file path, its `HomeHubView` type name, an exact MARK-comment string, and which directories contain Momentum-related source. **Primary recommendation:** keep the dashboard as a rewrite of `HomeHubView`'s *body*, in the same file, under the same type name, at the same path — do not rename or relocate the type — and extract the Momentum summary rendering into a new file under `Ritham/Momentum/` (not `Ritham/Home/`) so it falls under the MOMENTUM-06 no-sharing gate's existing directory walk, which today does *not* cover `Ritham/Home/` at all.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dashboard layout/section composition | SwiftUI View (client, iOS app) | — | Pure on-device rendering; `RithamScreen` already the client-side scroll/header scaffold |
| Exercise-log summary section | SwiftUI View, reading `HealthDataStore` via `MomentumSummaryReader` | Local SwiftData store | Read-only reconciliation-on-read presentation; no new data flow |
| Sleep check-in entry point | SwiftUI View → `flow.open(.sleepCheckIn)` | Local SwiftData store (via `SleepCheckInView`, unchanged) | Unmodified carry-forward per D-03 |
| Workout-plan section (embedded `RecommendationsView` content) | SwiftUI View + `RecommendationsModel` (client) | Go workout-plan service (`WorkoutPlanClient`, unchanged) | Model/network layer untouched; only its host container changes |
| Diet-plan section (embedded `DietPlanView` content) | SwiftUI View (client) | Local SwiftData store (`HealthDataStore`) | Diet-pattern/allergen writes are local-only, DIET-01-isolated |
| Navigation container | `OnboardingRootView` (app root, single `NavigationStack`) | — | CROSSGEN-05: exactly one container for the whole app; dashboard is a leaf reached via `.home`, never a second container |
| Cardio/strength/guidance entry points | SwiftUI View → `flow.open(_:)` push | — | Unchanged Phase 2 destinations, reached from dashboard per D-07 |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** The original "exactly 3 things by default, everything else one tap deeper" rule is dropped. The home screen is a real dashboard: multiple sections visible on the screen itself, never a vertical list of `PrimaryCTAButton`/`SecondaryCTAButton` rows.
- **D-02:** A logged-exercise section using `MomentumSummary.recentSessions` (already computed by `MomentumSummaryReader`, already distinguishes manual vs. sensor-verified) — do not re-derive this list a second way.
- **D-03:** A sleep section: today's sleep check-in entry point, carried over unchanged from `HomeHubView`'s existing `SecondaryCTAButton(title: MomentumCopy.Sleep.headline) { flow.open(.sleepCheckIn) }`. RECOVERY-01 invariant 3 still applies — no badge/dot/nudge.
- **D-04:** A workout-plan section, surfacing `RecommendationsView` directly as a dashboard section rather than a button that navigates away.
- **D-05:** A diet-plan section, surfacing `DietPlanView` directly as a dashboard section — same re-parenting treatment as D-04, not a rebuild.
- **D-06:** The Momentum summary section (progress blocks, streak line, shield row) carries forward essentially as-is — re-parented, not rebuilt. `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance` must keep passing against wherever this section ends up living.
- **D-07:** Cardio/strength logging entry points and history screens, plus Guidance, remain reachable from the dashboard as direct actions on the relevant section, not a leftover vertical button list. Settings remains reachable via gear/overflow, not a full-width button.
- **D-08:** Steps and calories-burned are NOT this round (no data source exists anywhere in the codebase). Leave room for a future section; do not implement.
- **D-09:** The onboarding-restart bug is already fixed (commit `744784d`), not this phase's scope.

### Claude's Discretion
- Exact visual arrangement of sections (order, card vs. list-row styling, scroll vs. fixed regions) — interpret "like Apple Health"/"a desktop" as multiple always-visible, scannable sections on one scrollable screen, consistent with Ritham's dark/high-contrast visual language, not a literal skeuomorphic desktop.
- Whether cardio/strength history screens get their own dashboard entry point or are reached via the exercise section's own "see all" affordance.

### Deferred Ideas (OUT OF SCOPE)
- **HOUSEHOLD-01** (household grouping, fixed non-ranked cheers) — later Phase 4 round.
- **CROSSGEN-04** (visibility spectrum) — later Phase 4 round, alongside HOUSEHOLD-01.
- **Steps and calories tracking** (D-08) — needs its own HealthKit/permissions/computation scoping decision before it can be planned.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CROSSGEN-01 | Home screen is a real dashboard, not a vertical button list — sections for logged exercise, sleep, workout-plan, and diet-plan all visible on the home screen itself | Architecture Patterns section below documents the exact re-parenting technique (content-extraction) for `RecommendationsView`/`DietPlanView`, the file/type-identity constraints from existing tests, and the section layout pattern (`RithamScreen` content closure + section cards) |

## Standard Stack

No new libraries. This phase is a SwiftUI composition/refactor exercise entirely within the existing stack (SwiftUI, SwiftData, Swift Testing, RithamCore).

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17.0 SDK (project.yml deployment target) | Dashboard layout, sections | Already the app's only UI framework |
| SwiftData | iOS 17.0 SDK | `HealthDataStore` persistence (unchanged) | Already the app's only persistence layer |
| Swift Testing | Bundled with Swift 6.3.3 / Xcode 26.6 | New/updated test suites | Already the app's only test framework (`RithamTests` target) |

### Supporting
_None new._ `MomentumSummaryReader`, `RecommendationsModel`, `WorkoutPlanClient`, `HealthDataStore` are all reused as-is.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual VStack sections in `RithamScreen`'s content closure | A `List`/`Form`-based dashboard | `List` imposes its own row chrome/dividers that conflict with Ritham's existing card-free, flat-charcoal `RithamScreen` design language used everywhere else in the app; the codebase has zero `List`/`Form` usage in any existing screen — introducing one here would be the first, inconsistent with every other screen |
| Extracting screen content into child views | Presenting `RecommendationsView`/`DietPlanView` as `.sheet`s launched from dashboard buttons | Explicitly forbidden by D-04/D-05 ("directly as a dashboard section rather than a button that navigates away") |

**Installation:** None — no new packages.

**Version verification:** N/A — no external packages introduced this phase.

## Package Legitimacy Audit

**Not applicable.** This phase introduces no external packages (npm/PyPI/CocoaPods/SPM). All reused types (`RecommendationsModel`, `HealthDataStore`, `MomentumSummaryReader`, `WorkoutPlanClient`) are first-party code already in the repository. `Package.swift`/`project.yml` need no dependency changes for this phase's scope.

## Architecture Patterns

### System Architecture Diagram

```
OnboardingRootView (single NavigationStack, app-wide)
        │
        ▼  StepRegistry.view(for: .home, flow:)
   HomeStepView.makeView  ──────────────►  HomeHubView (rewritten body, same type/file)
                                                  │
                                    RithamScreen(surface: .boundedHeaderOnly) { … }
                                                  │
                        ┌─────────────────────────┼───────────────────────────┐
                        ▼                          ▼                           ▼
              MomentumDashboardSection   RecommendationsSectionContent   DietPlanSectionContent
              (new file, Ritham/Momentum/)   (extracted from             (extracted from
                        │                     RecommendationsView)        DietPlanView)
                        ▼                          │                           │
             MomentumSummaryReader.summary()       ▼                           ▼
                        │                  RecommendationsModel          HealthDataStore
                        ▼                  (unchanged) ─► WorkoutPlanClient   .updateProfile /
                 HealthDataStore                 (Go service, network)       .saveFoodAllergens
                        │
                        ▼
                 SwiftData store (on-device)

Sleep section: SecondaryCTAButton → flow.open(.sleepCheckIn) → StepRegistry → SleepCheckInView
                                                                  (unchanged, no dashboard embedding)

Direct actions (D-07): PrimaryCTAButton/section affordance → flow.open(.cardioActivityPicker /
                        .cardioHistory / .strengthSession / .strengthHistory / .guidance)
                        → StepRegistry → existing Phase 2 screens (unchanged, pushed on the
                        single NavigationStack)
```

A reader can trace the primary use case (open app → see dashboard → see today's plan/diet/exercise/sleep at a glance → tap into a specific tracking flow) entirely by following the arrows above: everything left of the dashed line renders inline on one screen; everything reached via `flow.open(_:)` is a push onto the app's one `NavigationStack`.

### Recommended Project Structure
```
RithamApp/Ritham/
├── Home/
│   └── HomeHubView.swift          # REWRITTEN body (same file/type — see Pitfall 1). Composes
│                                   # the sections below inside one RithamScreen. Keeps its
│                                   # existing `nonisolated static func` derivations
│                                   # (showsMovementSnapshotEntry, routingSteps — updated).
├── Momentum/
│   └── Components/
│       └── MomentumDashboardSection.swift   # NEW — extracted from HomeHubView's old
│                                             # `momentumSection` computed var, verbatim logic,
│                                             # relocated so it's automatically covered by
│                                             # Phase3CoverageTests's directory-walk gate.
├── Recommendations/
│   └── Views/
│       ├── RecommendationsView.swift         # MODIFIED — body delegates to the extracted
│       │                                     # content view below; RecommendationsModel
│       │                                     # untouched; stays registered at `.recommendations`.
│       └── RecommendationsSectionContent.swift  # NEW — the `idle/loading/plan/error` content
│                                                 # switch, extracted verbatim, parameterized by
│                                                 # `RecommendationsModel`. Used by both
│                                                 # RecommendationsView (full-screen, if kept
│                                                 # reachable) and the dashboard section.
├── Settings/
│   ├── DietPlanView.swift                    # MODIFIED — Settings-presented sheet keeps the
│   │                                         # food-allergy screening question (see Pitfall 3);
│   │                                         # delegates its diet-pattern picker UI to the
│   │                                         # extracted content view below.
│   └── DietPlanSectionContent.swift          # NEW — dashboard-embeddable subset: dietary
│                                              # pattern picker only (DIET-01-isolated writes),
│                                              # no food-allergy screening question (see Pitfall
│                                              # 3), no `dismiss()` call.
└── App/
    └── StepRegistry.swift                     # UNCHANGED — HomeStepView.makeView still returns
                                                 # AnyView(HomeHubView(flow: flow))
```

### Pattern 1: Content-extraction re-parenting (the core technique for D-04/D-05)

**What:** Pull the meaningful, non-chrome body of an existing `RithamScreen`-wrapped view into a plain child view parameterized by the existing model/state, so it can be hosted either standalone (wrapped in its own `RithamScreen`) or embedded inline inside another screen's content closure.

**When to use:** Any time an existing fully-built screen needs to appear inline on another screen without its own header/scroll/background — exactly D-04 and D-05's requirement.

**Example (Recommendations, following the existing file's own structure):**
```swift
// RecommendationsSectionContent.swift — NEW, extracted verbatim from RecommendationsView's
// existing `content`/`idleContent`/`planContent`/`errorContent` @ViewBuilder methods.
// Takes the same RecommendationsModel already constructed by whichever parent hosts it.
struct RecommendationsSectionContent: View {
    let model: RecommendationsModel
    let flow: OnboardingFlow

    var body: some View {
        switch model.state {
        case .idle: idleContent
        case .loading: ProgressView("Building your plan...").foregroundStyle(RithamColor.paper)
        case .plan(let plan): planContent(plan)
        case .error(let error): errorContent(error)
        }
    }
    // ...idleContent/planContent/errorContent bodies moved here unchanged...
}

// RecommendationsView.swift — kept, registered at `.recommendations` (see Pitfall 4), now a
// thin RithamScreen wrapper around the same content:
struct RecommendationsView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .recommendations
    static func makeView(flow: OnboardingFlow) -> AnyView { AnyView(RecommendationsView(flow: flow)) }
    let flow: OnboardingFlow
    @State private var model: RecommendationsModel?
    var body: some View {
        RithamScreen(surface: .flat, headline: "Recommendations") {
            if let model { RecommendationsSectionContent(model: model, flow: flow) }
            else { ProgressView() }
        }
        .onAppear { /* unchanged model construction */ }
    }
}

// HomeHubView.swift — the new dashboard section, no second RithamScreen/ScrollView/header:
private var workoutPlanSection: some View {
    VStack(alignment: .leading, spacing: RithamSpacing.sm) {
        Text("Your workout plan").font(RithamType.heading).foregroundStyle(RithamColor.paper)
        if let model = recommendationsModel {
            RecommendationsSectionContent(model: model, flow: flow)
        } else {
            ProgressView()
        }
    }
    .padding(RithamSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RithamColor.paper.opacity(0.05))   // section-card treatment, see Pattern 2
    .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
}
```

### Pattern 2: Section-card wrapper (visual grouping, Claude's Discretion)

**What:** A small, local convention — `VStack` + padding + `background` + `clipShape(RoundedRectangle(...))` — matching `ReScreenBanner.swift`'s existing precedent (the only banner-with-background component in the codebase today). No dedicated reusable `Card` component exists yet; one is cheap to introduce as a private helper in the dashboard file, or as a tiny shared `DashboardSectionCard` view if the planner wants it reused across the 4+ sections.

**When to use:** Every dashboard section, for consistent visual grouping without introducing `List`/`Form`.

### Pattern 3: `nonisolated static func` for testable routing/visibility decisions

**What:** `HomeHubView.showsMovementSnapshotEntry(optIn:)` and `HomeHubView.routingSteps(movementSnapshotOptIn:)` are `nonisolated static func`s the real `body` calls directly, so Swift Testing (which runs off the main actor) can assert routing/visibility logic without rendering the view. SwiftUI's `View` protocol is itself `@MainActor`-isolated, which infers `@MainActor` onto every member of a conforming type by default — `nonisolated` on these pure derivations is what makes them callable from test functions at all.

**When to use:** Any new structural/visibility decision the dashboard needs (e.g., whether a section renders given some state) should follow this exact pattern, not a fresh one — it is the codebase's established idiom for this problem, used identically in `OnboardingRootView.resolvedRootStep`.

**Required update:** `routingSteps(movementSnapshotOptIn:)` currently hardcodes `.recommendations` in its returned array (reflecting the *old* `PrimaryCTAButton("Recommendations") { flow.open(.recommendations) }`). Once D-04 embeds the plan inline, the dashboard no longer calls `flow.open(.recommendations)` from a button, so this list must be updated to remove `.recommendations` (and add nothing for diet, which also stops being a `flow.open` destination from the dashboard) — otherwise this function actively lies about what the dashboard's `body` does. `MovementSnapshotViewTests`'s two callers of this function only assert `.movementSnapshot` presence/absence and are unaffected by removing `.recommendations` from the list.

### Anti-Patterns to Avoid
- **Embedding a full `RithamScreen`-wrapped struct inside another `RithamScreen`'s content:** produces a `ScrollView` inside a `ScrollView` along the same axis, plus a duplicated `RithamColor.ink` background and a second `ScreenHeader` — visually broken and not what "a section" means. Always extract content, never nest the wrapper.
- **Re-deriving `MomentumSummary` a second time for the dashboard:** D-02 explicitly forbids this — read through `MomentumSummaryReader` exactly as `HomeHubView`/`MomentumView` already do.
- **A dashboard-specific view model that owns Momentum/Recommendations/Diet state as one aggregate:** D-08 (03-CONTEXT.md precedent, restated in this phase's canonical refs) requires the Momentum summary to stay a plain `MomentumSummary?` loaded via its own reader call, not baked into a hub-specific view model. Keep each section's state independently loaded, matching the existing `onAppear` pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Workout plan fetch/adjustment/sleep-shift logic | A new dashboard-specific plan-fetching path | `RecommendationsModel` (unchanged) | Already handles pre-assessment gating, RECOVERY-01 sleep adjustment, and error states — re-deriving any of it risks silently diverging from `RecommendationsScreenTests`' already-verified behavior |
| Diet-pattern/allergen persistence | New dashboard-specific save calls | `HealthDataStore.updateProfile`/`.saveFoodAllergens` via the same `persistDiet`/`persistAllergens` functions `DietPlanView` already has | DIET-01's isolation guarantee (never touches gate resolution) is already correctly implemented; a second write path risks accidentally coupling diet changes to `GateResolution` |
| Momentum progress/streak/shield rendering | A new dashboard-specific summary view | `MomentumProgressBlocks`, `MomentumView.streakLine(for:)`, `ShieldRow` (all unchanged) | D-06 requires "essentially as-is" reuse; these are already accessibility- and copy-verified components |

**Key insight:** every domain behavior this phase touches (plan fetching, sleep adjustment, diet persistence, Momentum reads) is already built and tested in Phase 2/3. The only genuinely new code is presentation-layer composition — section containers and the content-extraction refactor. Resist the temptation to "clean up" or restate any of the reused logic while moving it; the extraction should be a mechanical cut-and-paste-into-a-new-view, not a rewrite.

## Runtime State Inventory

> This phase renames/relocates `HomeHubView`'s internal structure (a refactor of an existing screen), so this section applies, scoped to what actually changes.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `HomeHubView`'s rewrite touches no SwiftData model, no stored key, no persisted identifier. `OnboardingStep.home`'s raw value (`"home"`) is unchanged; `OnboardingStep` is `Codable` and persisted as part of in-progress `path` state, but `.home` itself is not renamed. | None |
| Live service config | None — no external service (the Go `WorkoutPlanClient` backend) has any config keyed on `HomeHubView`'s existence or shape. | None |
| OS-registered state | None — no Task Scheduler/launchd/pm2-equivalent registration exists for an iOS app screen. | None |
| Secrets/env vars | None. | None |
| Build artifacts | **xcodegen source-list regeneration required.** Per STATE.md's 02-06 precedent, xcodegen's directory-scan source list (`project.yml`) requires `xcodegen generate` (regenerating `Ritham.xcodeproj/project.pbxproj`) any time a task adds a new file or directory — this phase adds at least `MomentumDashboardSection.swift`, `RecommendationsSectionContent.swift`, and `DietPlanSectionContent.swift`. Each task that adds a file must run `xcodegen generate` and commit the regenerated `project.pbxproj`, or `xcodebuild` will not see the new file. |
| Test-file coupling (not a standard inventory category, but load-bearing here — see Pitfall 1) | `HomeHubTests.swift` and `MovementSnapshotViewTests.swift` reference `HomeHubView` by exact type name and, in one case, by exact file path (`Ritham/Home/HomeHubView.swift`) and exact MARK-comment string. | Keep type name `HomeHubView` and file path `Ritham/Home/HomeHubView.swift` unchanged (rewrite the body in place) to avoid touching these test files' file-path/marker-string assumptions. See Pitfall 1. |

**Nothing found in the first four categories** — verified by search (no HealthKit/pedometer/step/calorie references exist anywhere in the codebase per D-08's own confirmation, and no other runtime system stores anything keyed to `HomeHubView`'s shape).

## Common Pitfalls

### Pitfall 1: Two tests hardcode `HomeHubView`'s file path and an exact MARK-comment string
**What goes wrong:** `MovementSnapshotViewTests.swift`'s `theSnapshotEntryIsNotAdjacentToTheMomentumSummary` test reads `RithamApp/Ritham/Home/HomeHubView.swift` directly off disk (via `#filePath`-relative path construction), searches for the literal string `"MARK: - D-08's Momentum summary section"`, then searches forward for `"\nextension HomeHubView"` to bound the section, and asserts the text between the two never mentions `"movementSnapshot"`. If the dashboard's replacement view lives in a different file, or is a differently-named type, or the MARK comment/extension declaration text changes, this test fails with `Issue.record` (file/marker not found) rather than a normal assertion failure.
**Why it happens:** No ViewInspector-style rendering/section-tree introspection tool exists in this codebase (the test file's own comment says so), so Phase 3 verified structural adjacency via raw source-text scanning — a brittle but deliberate technique.
**How to avoid:** Keep the dashboard as a rewrite of `HomeHubView`'s `body`, in the same file (`RithamApp/Ritham/Home/HomeHubView.swift`), under the same type name (`HomeHubView`). Preserve the exact comment `MARK: - D-08's Momentum summary section` immediately before wherever the extracted Momentum section is invoked, and keep `extension HomeHubView { ... }` as the boundary for the pure-derivation static funcs at the bottom of the file (as it is today). This makes the rewrite a body-only change from this test's point of view, requiring zero edits to `MovementSnapshotViewTests.swift`.
**Warning signs:** `xcodebuild test` failing with "could not locate the Momentum summary section marker in HomeHubView.swift" or "could not locate the end of HomeHubView's struct body" — both are `Issue.record` calls in this exact test, not compiler errors, so they will not show up until the test suite runs.

### Pitfall 2: MOMENTUM-06's no-sharing gate does not scan `Ritham/Home/` today — this is a pre-existing gap, not a regression risk
**What goes wrong:** `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance` walks only `Ritham/Momentum/` and `Ritham/MovementSnapshot/` for banned tokens (`ShareLink`, `UIActivityViewController`, `UIPasteboard`). `HomeHubView.swift` (in `Ritham/Home/`) has never been covered by this gate, even though it has rendered the Momentum summary section since Phase 3. D-06 requires this gate to "keep passing against wherever this section ends up living" — read literally, this asks the planner to *close* a gap, not merely preserve current coverage.
**Why it happens:** The gate's `featureDirectories` array was written in Phase 3, before the Momentum section was known to live partly outside `Ritham/Momentum/`.
**How to avoid:** Extract the Momentum summary rendering (`MomentumProgressBlocks`, `MomentumView.streakLine(for:)`, `ShieldRow`, the empty-state text, the "Momentum" CTA) into a new file physically located under `Ritham/Momentum/Components/` (e.g. `MomentumDashboardSection.swift`), and have `HomeHubView` call it as a one-line component reference. This makes the extracted logic automatically covered by the existing directory walk with zero edits to `Phase3CoverageTests.swift`. (Alternative: add `Ritham/Home` to `featureDirectories` directly — also valid, but touches a Phase-3-owned test file for a Phase-4 concern; the extraction approach is cleaner and matches "re-parent, don't rebuild.")
**Warning signs:** If neither fix is applied, the gate keeps silently passing (green) while providing zero actual coverage of the dashboard's Momentum section — a false sense of safety, not a test failure. Verify manually by temporarily adding a `ShareLink` to the dashboard's Momentum section and confirming the gate actually fails before removing it.

### Pitfall 3 (HIGH severity): `DietPlanView`'s food-allergy checkbox writes through live screening state that is empty on every fresh app launch
**What goes wrong:** `DietPlanView`'s own header comment states plainly: its food-allergy checkbox (`checklistBinding`) and severity follow-up call `GateResolution.resolve(answers: flow.answers.screening, ...)` and `HealthDataStore.saveScreeningResult(...)` — a full screening re-resolve, not a DIET-01-isolated write — and this "requires the same `OnboardingFlow` instance whose `answers.screening` already holds the user's other screening answers in memory, or the re-resolve silently wipes them." Today this is reachable only via Settings → sheet, during the same app session where `flow.answers.screening` may or may not be populated (this is already a documented "KNOWN LIMITATION" per the file's own comment, shared with `EditAnswerFlow`). Critically: `OnboardingRootView` constructs a **brand-new `OnboardingFlow()`** (with empty `answers.screening`) on every app launch once `hasCompletedOnboarding` is true, rooting straight at `.home`. If D-05's "directly as a dashboard section" is implemented literally — the food-allergy checkbox rendered permanently on the first screen the user sees after every relaunch — any interaction with it re-resolves and re-saves the screening result against an **empty** `ScreeningAnswers()`, silently corrupting real condition-tag data (this is a safety-relevant regression: `GateResolution.resolve` feeds `WorkoutGuidanceCatalog`/`NutritionGuidanceCatalog` gating).
**Why it happens:** The existing screening re-resolve design assumes `DietPlanView` is only ever reached mid-session, after the user has just walked through (or is still holding in memory) the full onboarding screening flow — an assumption that was already fragile behind Settings, and becomes actively dangerous once the same control sits on the always-visible home screen reached fresh on every launch.
**How to avoid:** Narrow D-05's scope for the *dashboard section* specifically: embed only the DIET-01-isolated controls — the dietary-pattern picker (`dietSelection` → `persistDiet` → `HealthDataStore.updateProfile`, which never touches `GateResolution`) and, if desired, the allergen multi-select (`allergenSelection` → `persistAllergens` → `HealthDataStore.saveFoodAllergens`, same isolation). Leave the food-allergy screening checkbox and its severity follow-up (`checklistBinding`/`severitySelection`, the ones that call `GateResolution.resolve`) in the Settings-presented `DietPlanView` only, where the existing (already-fragile, already-documented) assumption about a live mid-session `OnboardingFlow` at least has a chance of holding, rather than being guaranteed false on every dashboard view after a cold launch.
**Warning signs:** A "before/after" manual check: relaunch the app fresh, check the food-allergy box on the dashboard, then open `HealthProfileView` (Settings) and confirm every other previously-set condition tag is still present. If any tag silently disappeared, this pitfall has been triggered.
**This is flagged in the Assumptions Log below** since it narrows a locked decision (D-05) rather than simply implementing it, and should be confirmed with the user before the plan locks it in.

### Pitfall 4: Should `.recommendations` (and any diet full-screen equivalent) stay registered once nothing pushes to it?
**What goes wrong:** `StepRegistry`'s `unregisteredSteps` (asserted empty by `PhaseCoverageTests`) filters `OnboardingStep.allCases` — every case must have a registered presenter, whether or not anything in the running app currently pushes to it. If the dashboard stops calling `flow.open(.recommendations)` (because the plan is now embedded inline per D-04), `.recommendations` becomes unreachable via user action but must remain registered, or the coverage gate fails at compile-adjacent test time.
**Why it happens:** The registry's completeness gate is per-case, not per-reachability.
**How to avoid:** Keep `RecommendationsView` registered exactly as it is today (`StepRegistry.register(RecommendationsView.self)` inside whatever registrar already does this — likely `Phase2StepRegistration`). Its `body` becomes a thin wrapper around the extracted `RecommendationsSectionContent` (Pattern 1 above) so no logic is duplicated, but the type and its registration stay untouched. This resolves the "is `.recommendations` still needed?" question raised by the re-parenting requirement: yes, keep it, just repoint what calls it (nothing does anymore from the dashboard, and that's fine — the gate only requires registration, not reachability).
**Warning signs:** `PhaseCoverageTests.unregisteredSteps`-is-empty failing if `.recommendations`'s registration is ever removed as "dead code" during cleanup.

### Pitfall 5: `DietPlanView`'s "Done" button calls `@Environment(\.dismiss)`, which is a no-op once embedded inline
**What goes wrong:** `DietPlanView`'s current `PrimaryCTAButton(title: "Done") { dismiss() }` assumes modal/pushed presentation. Once its content is embedded directly on the always-visible dashboard (not presented as a sheet), there is nothing to dismiss — the button either does nothing (confusing dead control) or, if `dismiss()`'s no-op behavior isn't understood, a task might try to "fix" it by wiring up navigation that doesn't belong on a dashboard section.
**Why it happens:** `dismiss()` is a `DismissAction` from `@Environment(\.dismiss)`, valid only inside a presentation context (sheet/pushed view); it silently no-ops outside one rather than crashing, which can mask the issue during manual testing if the extraction is done carelessly.
**How to avoid:** The extracted `DietPlanSectionContent` (Pattern 1) should not include a "Done" button at all — an always-visible dashboard section has no modal to close. Keep "Done" only on `DietPlanView`'s Settings-presented full-screen path.
**Warning signs:** Tapping "Done" on the dashboard's diet section does nothing (dead tap target) if this extraction is skipped and the raw view is embedded unmodified.

### Pitfall 6: Movement Snapshot / Momentum adjacency rule extends to the whole new dashboard, not just the old hub's layout
**What goes wrong:** `HomeHubView`'s existing comments establish that the Daily Movement Snapshot entry must never render "inside or adjacent to" the Momentum summary section — not just visually, but structurally (verified by Pitfall 1's source-scan test). A dashboard redesign that groups "everything activity-related" into one visual cluster risks placing the Movement Snapshot CTA next to (or worse, inside) the new Momentum section card without realizing this is a locked structural rule carried forward from Phase 3, not a fresh layout decision open to "Claude's Discretion."
**Why it happens:** D-06/D-07 read as being about *content* reuse; the adjacency rule is easy to miss since it is documented only in `HomeHubView`'s own header comments and MOMENTUM-07's requirement text, not restated in 04-CONTEXT.md.
**How to avoid:** Treat "section order/arrangement" (explicitly Claude's Discretion) as bounded by this pre-existing constraint: the Movement Snapshot entry point must not be the Momentum section's visual neighbor. Placing it near the exercise-logging section (D-02) instead is consistent with both this rule and MOMENTUM-07's "no streak/shield/target attached" framing.
**Warning signs:** `theSnapshotEntryIsNotAdjacentToTheMomentumSummary` failing once the Movement Snapshot line is moved into (or immediately after) the new Momentum section's own source block.

## Code Examples

### Existing Momentum summary rendering (to extract verbatim into `Ritham/Momentum/Components/MomentumDashboardSection.swift`)
```swift
// Source: RithamApp/Ritham/Home/HomeHubView.swift (current momentumSection, lines 152-190) —
// move this @ViewBuilder body into a new standalone View taking `summary`/`momentumLoadFailed`/
// `flow` as parameters. No logic change; only the hosting file/type changes.
@ViewBuilder
private var momentumSection: some View {
    if let summary = momentumSummary {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            MomentumProgressBlocks(filled: summary.displayedCount, target: summary.weeklyTarget)
            Text(MomentumView.streakLine(for: summary))
                .font(RithamType.heading)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)
            ShieldRow(earned: summary.shieldCount, maximum: MomentumLedger.maxShields)
            // ...empty-state / "Momentum" CTA unchanged...
        }
    } else if momentumLoadFailed {
        Text(OnboardingCopy.Errors.savingFailed)
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
    }
}
```

### Existing `RecommendationsModel` state machine (reused unchanged by the extracted section content)
```swift
// Source: RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift
enum RecommendationsState: Equatable {
    case idle
    case loading
    case plan(WorkoutPlan)
    case error(WorkoutPlanClientError)
}
// RecommendationsModel.requestPlan(flow:now:) already gates on pre-assessment completion and
// applies RECOVERY-01's sleep-based adjustment — the dashboard section calls this exact function,
// unchanged, from whatever "Get my plan"/"Retry" control the extracted content view renders.
```

### DIET-01-isolated persistence (safe to embed on the dashboard per Pitfall 3's narrowed scope)
```swift
// Source: RithamApp/Ritham/Settings/DietPlanView.swift — these two functions never touch
// GateResolution and are safe to call from a dashboard section reached fresh on every launch.
private func persistDiet(_ pattern: DietaryPattern) {
    let store = HealthDataStore(context: modelContext)
    guard let existingAge = try? store.loadProfile().age else { return }
    try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
}
private func persistAllergens(_ allergens: Set<FoodAllergen>) {
    let store = HealthDataStore(context: modelContext)
    try? store.saveFoodAllergens(allergens)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `HomeHubView` as a vertical list of `PrimaryCTAButton`/`SecondaryCTAButton` rows, each pushing a full-screen destination | Sectioned dashboard with 2-3 screens' content embedded inline, only tracking-entry-point actions (D-07) still pushing | This phase (2026-09-08), per direct user rejection of the interim hub | Establishes the pattern future sections (e.g. a future steps/calories section, D-08) should follow: embed a summary/content view, not a nav button |

**Deprecated/outdated:**
- `HomeHubView`'s "This is a temporary hub..." framing copy and its full vertical CTA list — explicitly what D-01 requires removed "in shape or in spirit."

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | D-05's "directly as a dashboard section, not a rebuild" should be narrowed to exclude the food-allergy screening checkbox (kept in the Settings-presented `DietPlanView` only), because embedding it on the always-fresh dashboard risks silently wiping condition tags via an empty `OnboardingFlow.answers.screening` on every cold launch (Pitfall 3). | Common Pitfalls, Pitfall 3 | If the user actually wants full parity (including the allergy checkbox) on the dashboard, the plan must first fix `DietPlanView`'s screening re-resolve to not depend on in-memory `OnboardingFlow` state (e.g., persist/reload `ScreeningAnswers` from the store instead of relying on the flow instance) — a materially larger task than a pure re-parenting refactor. Confirm with the user via discuss-phase or an explicit planner checkpoint before locking the section scope. |
| A2 | Extracting the Momentum section into `Ritham/Momentum/Components/` (rather than editing `Phase3CoverageTests.featureDirectories`) is the preferred fix for Pitfall 2's coverage gap. | Common Pitfalls, Pitfall 2 | Low risk either way — both are valid, mechanical fixes; if the planner prefers editing the test's directory list instead, that is an equally correct alternative, just touches a different file. |
| A3 | The dashboard should be built as `HomeHubView`'s body rewritten in place (same file/type), not a newly named `DashboardView`, based on minimizing test churn (Pitfall 1). | Architecture Patterns, Common Pitfalls Pitfall 1 | If the planner instead creates a genuinely new type/file, the two tests identified in Pitfall 1 must be updated in the same plan wave — not left for a later cleanup — or they will fail on missing markers/paths. |

## Open Questions

1. **Should `RecommendationsView` (and an equivalent full-screen `DietPlanView` variant) remain reachable as a standalone full screen at all, once their content is embedded on the dashboard?**
   - What we know: `.recommendations` must stay *registered* regardless (Pitfall 4), and `DietPlanView` stays reachable from Settings regardless (Pitfall 3's narrowed scope keeps the screening checkbox there).
   - What's unclear: whether a "See full plan" / "see all sessions" affordance from the dashboard section should still push to the full `RecommendationsView` screen, or whether the embedded section is the only way to see it going forward.
   - Recommendation: Claude's Discretion per 04-CONTEXT.md ("whether cardio/strength history screens get their own dashboard entry point..." implies the same open-ended treatment applies to workout-plan detail). Default to no separate full-screen entry point for Recommendations specifically (the embedded section already shows the complete plan), keeping `RecommendationsView` registered purely to satisfy `unregisteredSteps`.

## Environment Availability

Skipped — this phase has no new external dependencies (no HealthKit, no new package, no new service). The existing Go `WorkoutPlanClient` backend dependency is unchanged from Phase 2 and already covered by that phase's own research/verification.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (bundled with Swift 6.3.3 / Xcode 26.6) |
| Config file | `RithamApp/Ritham.xcodeproj` (via `project.yml`, xcodegen-managed) — no separate test-plan file |
| Quick run command | `cd RithamApp && xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RithamTests/HomeHubTests` (swap the `-only-testing` target per suite under active work) |
| Full suite command | `cd RithamApp && xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CROSSGEN-01 | Dashboard renders logged-exercise, sleep, workout-plan, and diet-plan sections all visible without navigation | unit (model/data-level, matching `HomeHubTests`'s existing discipline of testing `OnboardingFlow`/static derivations rather than rendering) | `xcodebuild test -scheme Ritham -only-testing:RithamTests/HomeHubTests` | ✅ existing file, needs new tests added |
| CROSSGEN-01 | Momentum section's no-sharing structural gate still passes after relocation (Pitfall 2) | structural/directory-walk | `xcodebuild test -scheme Ritham -only-testing:RithamTests/Phase3CoverageTests` | ✅ existing, no new file needed if extraction lands under `Ritham/Momentum/` |
| CROSSGEN-01 | Movement Snapshot entry stays non-adjacent to Momentum section post-refactor (Pitfall 1/6) | structural/source-scan | `xcodebuild test -scheme Ritham -only-testing:RithamTests/MovementSnapshotViewTests` | ✅ existing, requires file path/marker preserved (Pitfall 1) — else ❌ Wave 0 update needed |
| CROSSGEN-01 | `.recommendations`/`.home` (and every `OnboardingStep`) stays registered after the dashboard rewrite | structural/registry | `xcodebuild test -scheme Ritham -only-testing:RithamTests/PhaseCoverageTests` | ✅ existing |
| CROSSGEN-01 | DIET-01 isolation preserved: dashboard diet-pattern writes never touch `GateResolution`/condition tags (Pitfall 3) | unit, new | new test in a `DashboardDietSectionTests.swift` or added to `RecommendationsTests.swift`-equivalent for diet | ❌ Wave 0 — no `DietPlanView`/diet dashboard test file exists today (STATE.md confirms DIET-01 has never had a dedicated automated test suite) |

### Sampling Rate
- **Per task commit:** quick run scoped to the suite touched (`HomeHubTests`, `Phase3CoverageTests`, `MovementSnapshotViewTests`, or the new diet-section suite)
- **Per wave merge:** full suite (`xcodebuild test -scheme Ritham` with no `-only-testing` filter)
- **Phase gate:** full suite green before `/gsd-verify-work`, plus a manual click-through pass (STATE.md notes no touch-injection tool is available in this environment beyond `simctl`, so the interactive UAT pass that DIET-01 already deferred should be repeated/extended to the new dashboard sections at that time)

### Wave 0 Gaps
- [ ] New test file for the diet-plan dashboard section's DIET-01 isolation (no dedicated `DietPlanView`/diet test suite exists in the repo today — confirm this gap directly: `find RithamApp/RithamTests -iname "*Diet*"` returns nothing)
- [ ] `MovementSnapshotViewTests.swift`'s `theSnapshotEntryIsNotAdjacentToTheMomentumSummary` must be re-verified (not necessarily rewritten, if Pitfall 1's file-path/marker preservation approach is followed) against the rewritten `HomeHubView.swift`
- [ ] `Phase3CoverageTests.swift`'s `noMomentumSurfaceOffersASharingAffordance` must be re-verified against the relocated Momentum section file (Pitfall 2) — passing here with the extraction approach requires no test edits, only correct file placement

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface touched this phase |
| V3 Session Management | No | No session/token handling touched this phase |
| V4 Access Control | Marginal — see Pitfall 3 | The dashboard's diet section must not silently escalate/de-escalate a condition-tag-derived permission gate through an unintended re-resolve path; mitigation is Pitfall 3's scope narrowing, not a new access-control library |
| V5 Input Validation | No new input surfaces | Existing `ChoiceQuestionView`/enum-backed selections reused unchanged |
| V6 Cryptography | No | Not touched |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Silent data corruption via a stale/empty in-memory state object driving a persistence write (Pitfall 3: `OnboardingFlow.answers.screening` empty on relaunch, feeding `GateResolution.resolve`/`saveScreeningResult`) | Tampering (unintentional, self-inflicted) | Scope the dashboard's diet section to DIET-01-isolated writes only (`updateProfile`/`saveFoodAllergens`), which read/write only their own field and never re-derive/re-save the full screening result |

## Sources

### Primary (HIGH confidence)
- Direct codebase reads: `RithamApp/Ritham/Home/HomeHubView.swift`, `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift`, `RithamApp/Ritham/Settings/DietPlanView.swift`, `RithamApp/Ritham/App/OnboardingRootView.swift`, `RithamApp/Ritham/App/StepRegistry.swift`, `RithamApp/Ritham/App/StepBootstrap.swift`, `RithamApp/Ritham/App/OnboardingStepPresenting.swift`, `RithamApp/Ritham/Components/RithamScreen.swift`, `RithamApp/Ritham/DesignSystem/ScreenHeader.swift`, `RithamApp/Ritham/Momentum/Components/ShieldRow.swift`, `RithamApp/Ritham/Settings/ReScreenBanner.swift`, `RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift`
- Direct test-codebase reads: `RithamApp/RithamTests/HomeHubTests.swift`, `RithamApp/RithamTests/MovementSnapshotViewTests.swift`, `RithamApp/RithamTests/Phase3CoverageTests.swift`, `RithamApp/RithamTests/RecommendationsTests.swift`
- `.planning/phases/04-household-home/04-CONTEXT.md` (locked decisions, verbatim user quotes)
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` (Phase 4 criteria, CROSSGEN-01 revision annotation)
- `.planning/STATE.md` (xcodegen regeneration precedent, `StepRegistry` cross-suite race fix, DIET-01's never-tested status)
- `xcodebuild -list -project Ritham.xcodeproj` (confirmed scheme name `Ritham`, targets `Ritham`/`RithamTests`)
- `swift --version` / `xcodebuild -version` (Swift 6.3.3, Xcode 26.6, confirming `nonisolated static func` / Swift 6 strict concurrency context already established in this codebase)

### Secondary (MEDIUM confidence)
_None used — every claim in this document is either a direct code/doc read or explicitly marked `[ASSUMED]` in the Assumptions Log above._

### Tertiary (LOW confidence)
_None._

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new stack decisions; every reused component read directly from source
- Architecture: HIGH — the content-extraction pattern and file/type-identity constraints are derived from reading the actual `RithamScreen`, `RecommendationsView`, `DietPlanView`, and test files, not inferred
- Pitfalls: HIGH for Pitfalls 1/2/4/5/6 (each verified by reading the exact test/source code that would break); MEDIUM for Pitfall 3's exact remediation shape (the underlying screening-re-resolve fragility is HIGH-confidence/code-verified via `DietPlanView`'s own header comment, but the recommended scope-narrowing is this researcher's judgment call, logged in the Assumptions table for confirmation)

**Research date:** 2026-09-08
**Valid until:** 30 days (stable, no fast-moving external dependency in this phase's scope)
