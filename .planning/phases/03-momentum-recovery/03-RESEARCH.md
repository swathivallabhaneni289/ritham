# Phase 3: Momentum & Recovery - Research

**Researched:** 2026-09-06
**Domain:** Client-side (Swift/SwiftData) weekly consistency-streak state machine, layered read-only over Phase 2's already-persisted `CardioSessionRecord`/`LiftSessionRecord`, plus a client-side post-processing wrapper over Phase 2's Go-backed workout-plan surface.
**Confidence:** MEDIUM-HIGH — the reusable qualifying-session logic, persistence facade pattern, and step-registration mechanics are all directly confirmed in the codebase (HIGH); the Monday-3am DST boundary arithmetic and the exact RECOVERY-01 plan-hook shape carry genuine open questions the planner must resolve (MEDIUM), documented below rather than silently assumed.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Architecture — client-side only**
- **D-01:** Momentum state is computed and persisted entirely client-side (RithamCore +
  `HealthDataStore`) — no Go backend involvement of any kind. Momentum only ever reads
  already-local `CardioSessionRecord`/`LiftSessionRecord` data; nothing new needs to leave the
  device. Matches PROJECT.md's local-first storage decision and leaves Phase 2's Go surface
  (workout-plan generation only) completely untouched.
- **D-02:** New `Momentum` domain in `RithamCore` (parallel to `Cardio`/`Strength`/`Screening`)
  computes weekly qualifying-session counts from existing session records against the
  already-defined qualification bar (10+ min continuous cardio, or 3+ working sets across 2+
  exercises for lift). Reference `CalibrationThreshold`'s existing constants rather than
  restating the numbers — same reuse pattern Phase 2's D-02 established for its own
  `WorkoutSession` domain. Exact new SwiftData record shapes (weekly state, shields, milestones,
  recovery-week flags, injury freezes, comeback windows, daily sleep check-ins, movement
  snapshot) are the planner's call, not decided here.

**Self-report signals are structurally independent (MOMENTUM-03/08, RECOVERY-01)**
- **D-03:** The daily sleep check-in (RECOVERY-01), the user-initiated Recovery Week flag
  (MOMENTUM-03), and the self-reported pain/injury freeze (MOMENTUM-08) are three
  structurally independent state machines with **zero automatic transitions between them**:
  the sleep check-in never auto-triggers a Recovery Week and never auto-consumes a shield
  (RECOVERY-01's own stated invariant); a Recovery Week is only ever user-initiated, never
  auto-triggered by the app (MOMENTUM-03's own stated invariant); the pain/injury freeze is its
  own distinct self-report action. Do not collapse these into one shared "recovery state" enum
  or flag — that would make the required no-auto-trigger invariants structurally unenforceable
  rather than just untested.

**Recovery-aware suggestion (RECOVERY-01) stays client-side**
- **D-04:** The sleep check-in's "shift the day's suggested session lighter" adjustment is a
  client-side post-processing step applied over whatever plan Phase 2's existing
  `WorkoutPlanClient`/`RecommendationsView` already returns. It does **not** add a new field to
  the Go `RithamService` request — Phase 2's D-07 three-field data-minimization boundary
  (`frequencyPerWeek`/`experienceLevel`/`guidancePermission`) stays exactly as-is — and requires
  no new network round-trip.
- **D-05:** RECOVERY-01's seven invariants are required unit-test assertions, not just a UI copy
  nuance: the qualification bar never changes; a lighter suggested session that meets the bar
  fully qualifies; declining the lighter suggestion and doing the original session is always
  available and fully qualifies; skipping the check-in has zero effect; the feature never
  auto-consumes a shield; it never auto-triggers a Recovery Week; no penalty/asterisk/badge/
  messaging differentiates training harder than suggested vs. accepting the lighter option. The
  planner should scope explicit test cases for each.

**Visibility & Household (MOMENTUM-06) — scoped deferral, not silent gap**
- **D-06:** Phase 3 delivers only the private-by-default half of MOMENTUM-06 — no public
  leaderboard, no sharing of any kind. The opt-in household/accountability-contact half is
  **not** built in Phase 3 (Household doesn't exist until Phase 4). This is a scoped, dated
  deferral — execution should add a dated annotation to `ROADMAP.md`'s Phase 3 criterion 5.
  The accountability-contact half specifically stays deferred even once Phase 4 ships
  HOUSEHOLD-01 — it's HOUSEHOLD-02, already out-of-scope to v2.
- **D-07:** Build the private Momentum data model with a visibility-scope property from the
  start (e.g., an enum where `.private` is the only real case in v1), so Phase 4 can add a
  `.household` case later without a data migration. No sharing UI/toggle/opt-in flow now.

**Home surface integration (forward-compat with Phase 4)**
- **D-08:** Momentum surfaces (today's progress toward the weekly target, current streak count,
  shields, milestones) are added to Phase 2's existing interim `HomeHubView`, plus a dedicated
  Momentum detail screen for shields/milestones/history and the Recovery-Week-flag/injury-flag
  actions. Structure the underlying read (e.g., a `MomentumSummary` value read from
  `HealthDataStore`) as a standalone queryable unit, not baked into a hub-specific view model —
  Phase 4's polished CROSSGEN-01 home screen will need "today's target + current streak" reading
  the same underlying data.
- **D-09:** The Daily Movement Snapshot (MOMENTUM-07) is a separate, opt-in surface (a Settings
  toggle, matching DIET-01's existing opt-in-preference pattern) with its own plain calendar-style
  view — deliberately not merged into the Momentum screen, since it must carry no
  streak/shield/target of its own.

### Claude's Discretion
- Weekly-target adjustability (2-5, default 3) is a Settings preference, following the same
  editable-preference pattern as Phase 2's workout-frequency setting.
- Comeback Session UI is a plain CTA on the Momentum screen when a week was missed and the
  3-day window is still open — no separate wizard or multi-step flow.
- Milestone badges get a simple badge case/list UI (icon + week count + one line of
  competence-framed copy) — no bespoke celebration animation.
- The Monday 3am local-time week-boundary math and full SwiftData schema design are left
  entirely to research/planning — not decided here.

### Deferred Ideas (OUT OF SCOPE)
None new from this discussion — MOMENTUM-06's household-sharing half is not a new deferred idea,
it's an existing v1 requirement whose second half structurally can't land until Phase 4
(HOUSEHOLD-01) and Household's own v2 accountability-contact tier (HOUSEHOLD-02).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MOMENTUM-01 | Cross-modality weekly streak (qualifying cardio/lift session, shared target 2-5, endowed 1/3 start, manual-vs-sensor labeling) | `CardioQualification.evaluate`/`LiftQualification.evaluate` already exist and are the exact reuse target (see Don't Hand-Roll); `CardioCaptureSource.isSensorVerified` + `CardioHistoryView`'s existing label string are the direct precedent; endowed-progress semantics flagged as Open Question 1 |
| MOMENTUM-02 | Shields (1 per 4 consecutive weeks, stack to 3, never purchasable, auto-apply on miss) | Architecture Patterns §"Reconciliation-on-read" — no background job exists (client-only, D-01), so shield accrual/consumption must be a lazy, idempotent fold over elapsed weeks computed at read time |
| MOMENTUM-03 | Monday 3am local reset boundary; user-initiated Recovery Week flag, never auto-triggered | Week-Boundary Arithmetic section; `ConditionTagValidity.expiry(from:calendar:)` is the direct in-repo precedent for injected-`Calendar`, DST-safe date math |
| MOMENTUM-04 | Comeback Session within 3 days restores streak minus one | Data Model Shape section — comeback window as a derived value (elapsed days since last-missed-week boundary), gated on ledger state |
| MOMENTUM-05 | Milestones at 4/12/26/52 weeks (badge + bonus shield) | Data Model Shape — milestone ledger as append-only, never re-derived away |
| MOMENTUM-06 | Private-by-default visibility, no public leaderboard (household half deferred to Phase 4 per D-06/D-07) | Data Model Shape — `MomentumVisibility` enum with `.private` as sole v1 case |
| MOMENTUM-07 | Daily Movement Snapshot, no streak/shield/target attached | Settings opt-in pattern (`DietPlanView`/`WorkoutFrequencyView` precedent), separate SwiftData record from weekly Momentum state |
| MOMENTUM-08 | Self-reported pain/injury flag auto-freezes streak | Reconciliation precedence order (Architecture Patterns) — guardrail must be checked before shield consumption in the weekly fold |
| RECOVERY-01 | Daily sleep check-in (Great/OK/Poor) shifts suggested session lighter, seven invariants, never touches streak mechanics | RECOVERY-01 Integration Seam section — `dayIndex` in the Go plan is a plain ordinal (not a calendar weekday), which changes what "today's suggested session" can mean; flagged as Open Question 2 |
</phase_requirements>

## Summary

This phase adds almost no new *mechanics* to invent — `docs/roadmap.md` §4 is unusually
prescriptive, and 01/02-era phases already pre-built two of the three hardest pieces without the
words "Momentum" ever appearing in scope: `CardioQualification.evaluate` and
`LiftQualification.evaluate` (both in `RithamCore`, both already unit-tested) are the *exact*
qualifying-session functions Momentum needs, reading the same `CalibrationThreshold` constants
D-02 mandates reuse of. `HealthDataStore` already exposes `loadCardioSessions(in:)` /
`loadLiftSessions(in:)` date-range queries — the precise seam a weekly rollup needs. And
`CardioCaptureSource.isSensorVerified` plus `CardioHistoryView`'s existing "Sensor-verified" /
"Manually entered" label are the direct precedent for MOMENTUM-01's labeling requirement. None of
this needs to be built from scratch; it needs to be *read* by a new, thin `Momentum` domain.

The two genuinely hard problems are (1) getting the Monday-3am-local week boundary right under
DST without hand-rolling seconds-based arithmetic (the codebase already has a working precedent
for *injected-Calendar, month-based* boundary math in `ConditionTagValidity.expiry(from:calendar:)`
— the pattern to follow, not the exact formula, since this phase's boundary is weekday+hour based,
a different Calendar API path), and (2) the fact that Momentum has no background job to run
(D-01: purely client-side, no server, no push notifications for this phase) — so "shields
auto-apply the moment a week is about to be missed" cannot literally happen at the missed moment;
it must be **reconciled lazily, idempotently, on read**, the next time the user opens the app or
the Momentum screen. This reframing — weekly counts *derived* from session records at read time,
but shield/milestone/comeback *state* persisted as an append-only ledger that reconciliation never
revokes — is the single most important architectural decision this research surfaces, because it
also solves STRENGTH-05's retroactive-edit problem for free (editing/deleting a three-week-old
lift session must never claw back an already-shown milestone badge).

RECOVERY-01's client-side wrapper has a real complication the CONTEXT.md/roadmap language doesn't
surface: the Go-generated `WorkoutPlan.sessions` are keyed by a plain ordinal `dayIndex` (1..N),
not a calendar weekday (confirmed in `RithamService/internal/plan/generate.go`). "The day's
suggested session" therefore cannot be a weekday lookup — the planner must decide what "today's
session" means client-side (see Open Question 2). The transform itself must live in `RithamApp`
(not `RithamCore`), because `WorkoutPlan`/`WorkoutPlanSession`/`WorkoutPlanExercise` are types
private to that target.

**Primary recommendation:** Build `Momentum` as a `RithamCore` domain of pure, `Calendar`/`Date`-
injected functions (mirroring `ConditionTagValidity`'s testable-before-Xcode-exists style) that
fold over `[CardioSession]`/`[LiftSession]` plus a small set of new SwiftData-persisted ledger
records (shields, milestones, comeback claims, recovery-week/injury-freeze periods, sleep
check-ins) fetched through new `HealthDataStore` facade methods following the exact
`WorkoutPreferenceRecord` single-row-upsert / range-query patterns already in that file. Do not
persist weekly qualifying counts or streak length directly — derive them every time from session
records plus the ledger, so retroactive edits (STRENGTH-05) can never desync stored state.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Weekly qualifying-session counting | RithamCore (pure domain) | — | Reads existing `CardioSession`/`LiftSession` value types via `CardioQualification`/`LiftQualification`; no UI or persistence concern |
| Week-boundary (Monday 3am local) arithmetic | RithamCore (pure domain, injected `Calendar`) | — | Must be independently unit-testable across DST fixtures without a running app; matches `ConditionTagValidity`'s precedent |
| Shield/milestone/comeback ledger persistence | RithamApp / SwiftData (`HealthDataStore`) | — | New `@Model` records, following `CardioSessionRecord`/`WorkoutPreferenceRecord` shapes |
| Streak/shield reconciliation-on-read | RithamCore (pure fold function) | RithamApp (calls it, persists resulting ledger deltas) | Core computes "what changed since last reconciliation" as a pure value; App applies the write |
| Recovery Week flag / injury freeze | RithamCore (state) + RithamApp (persistence) | — | Independent state machines per D-03; no cross-machine transitions |
| Sleep check-in (Great/OK/Poor) storage | RithamApp / SwiftData | — | Simple daily record, no domain logic beyond storage + the lighter-suggestion rule |
| "Poor sleep -> lighter suggestion" rule | RithamCore (pure function, e.g. `SleepAdjustment`) | — | A decision rule over an enum; no dependency on `WorkoutPlan` (app-target type) |
| Applying the lighter-suggestion rule to an actual `WorkoutPlan` | RithamApp (`RecommendationsModel`) | — | `WorkoutPlan`/`WorkoutPlanSession` are types private to the RithamApp target; RithamCore cannot reference them |
| Momentum summary UI (HomeHubView section, detail screen) | RithamApp / SwiftUI | — | Follows `RecommendationsView`/`HomeHubView`'s Model/View split precedent |
| Daily Movement Snapshot (calendar view + opt-in toggle) | RithamApp / SwiftUI + SwiftData | — | Separate record and screen per D-09, reads `SettingsView`'s sheet-toggle pattern |
| Go `RithamService` (workout-plan generation) | Untouched | — | D-01/D-04: zero involvement; no new field, no new endpoint |

## Standard Stack

No new third-party dependencies. This phase is pure Foundation + SwiftUI + SwiftData, matching
every prior phase's stack. `RithamCore/Package.swift` and `RithamApp/project.yml` declare no
external package dependencies today `[VERIFIED: repo inspection — grep for "dependencies" in both
manifests returns only internal target references]`, and nothing in this phase's scope (client-
side date arithmetic, SwiftData persistence, SwiftUI views) requires adding one.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation `Calendar`/`DateComponents` | iOS 17 SDK (project's existing floor) | Week-boundary arithmetic, DST-safe date math | Already the exclusive date-math approach in this codebase (`ConditionTagValidity`); Apple's own guidance is that manual `TimeInterval` addition across a DST boundary is unsafe `[CITED: developer.apple.com/documentation/foundation — Calendar reference page confirms `nextDate(after:matching:matchingPolicy:)` exists for weekday/hour matching; exact matchingPolicy semantics not independently re-verified this session, see Assumptions Log]` |
| SwiftData `@Model` | iOS 17 SDK | Persist ledger records (shields, milestones, comeback claims, recovery/injury periods, sleep check-ins, snapshot entries) | Exclusive persistence mechanism already used for every other domain (`CardioSessionRecord`, `LiftSessionRecord`, `WorkoutPreferenceRecord`) `[VERIFIED: repo inspection]` |
| Swift Testing (`@Test`/`@Suite`) | Bundled with Swift 6 toolchain | Unit tests for the new `Momentum` domain and its RithamApp integration | Exclusive test framework already used across `RithamCoreTests`/`RithamTests` `[VERIFIED: repo inspection — CardioSessionTests.swift, LiftSessionTests.swift, PhaseCoverageTests.swift all use `@Test`/`@Suite`]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None | — | — | — |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled `Calendar`-based boundary function | A dedicated date library (e.g. SwiftDate) | Rejected — matches zero-third-party-dependency precedent in this codebase; the boundary logic is a single, narrowly-testable function, not broad date-manipulation surface |
| Reconciliation-on-read (lazy) | A scheduled local notification / background task that "checks" weekly | Rejected for v1 — adds `BackgroundTasks`/notification-permission surface with no product requirement driving it (MOMENTUM-02's "auto-applies" language is satisfiable by lazy reconciliation being invisible to the user; a background job would only matter for push-notification-style "your shield saved you" alerts, out of scope here) |

**Installation:** No new packages to install.

## Package Legitimacy Audit

Not applicable — this phase introduces no new third-party package dependencies in either
`RithamCore/Package.swift` or `RithamApp/project.yml` `[VERIFIED: repo inspection]`. The Package
Legitimacy Gate is skipped; nothing to audit.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│ SwiftUI Layer (RithamApp)                                                │
│                                                                           │
│  HomeHubView ──open(.momentum)──▶ MomentumView (detail: shields,         │
│      │                             milestones, comeback CTA, flags)     │
│      │                                     │                            │
│      │                             MomentumSummary read ──┐             │
│      │                                                    │             │
│  RecommendationsView ──▶ RecommendationsModel.fetchPlan ──┼──▶ WorkoutPlanClient
│      (unchanged network path)                             │      (Go, D-01/D-04 untouched)
│      after plan returns:                                  │
│      SleepAdjustment.apply(plan, checkIn) ── RithamApp-only transform    │
│      (WorkoutPlan is an app-target type; RithamCore cannot see it)      │
│                                                            │             │
│  Settings ──▶ MomentumTargetView (2-5 picker)              │             │
│  Settings ──▶ MovementSnapshotToggle + MovementSnapshotView│             │
│  MomentumView ──▶ SleepCheckInView (Great/OK/Poor)         │             │
└────────────────────────────────────────────────┬──────────┼─────────────┘
                                                   ▼          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ HealthDataStore (persistence facade, @MainActor)                        │
│  - loadCardioSessions(in:) / loadLiftSessions(in:)  [existing, D-02 read]│
│  - saveMomentumLedger / loadMomentumLedger   [new — shields, milestones,│
│    comeback claims, recovery/injury periods, last-reconciled-week]      │
│  - saveSleepCheckIn(for: Date) / loadSleepCheckIn(for: Date)  [new]     │
│  - saveMomentumTarget / loadMomentumTarget   [new, WorkoutPreferenceRecord-style]
│  - saveSnapshotEntry / loadSnapshotEntries(in:)  [new, MOMENTUM-07]     │
└────────────────────────────────────────────────┬─────────────────────────┘
                                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ RithamCore (pure domain logic, no SwiftData/UIKit/network imports)      │
│                                                                           │
│  MomentumWeek.boundary(for: Date, calendar: Calendar) -> DateInterval   │
│      (Monday 3am local; injected Calendar, no Date() inside)            │
│                                                                           │
│  CardioQualification.evaluate(_:) / LiftQualification.evaluate(_:)      │
│      [ALREADY EXIST — Phase 1/2 built these; Momentum reads, not builds]│
│                                                                           │
│  MomentumReconciliation.reconcile(                                      │
│      sessions: [CardioSession]/[LiftSession],                          │
│      ledger: MomentumLedger,                                           │
│      guardrails: [RecoveryWeekPeriod]/[InjuryFreezePeriod],             │
│      now: Date, calendar: Calendar                                     │
│  ) -> MomentumLedger   (pure fold, idempotent, never revokes past grants)│
│                                                                           │
│  SleepAdjustment.suggestedIntensity(for: SleepCheckIn) -> IntensityShift│
│      (no dependency on WorkoutPlan — app layer applies the shift)       │
└───────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
RithamCore/Sources/RithamCore/Momentum/
├── MomentumWeek.swift            # week-boundary arithmetic (injected Calendar)
├── MomentumLedger.swift          # shields/milestones/comeback state as pure value types
├── MomentumReconciliation.swift  # the lazy, idempotent fold — the core mechanic
├── MomentumTarget.swift          # weekly target (2-5) validation
└── SleepAdjustment.swift         # Great/OK/Poor -> intensity-shift decision rule

RithamApp/Ritham/Persistence/
├── MomentumLedgerRecord.swift    # new @Model, single-row-per-week or append-only ledger rows
├── SleepCheckInRecord.swift      # new @Model, one row per day
├── MovementSnapshotRecord.swift  # new @Model, MOMENTUM-07's separate opt-in record
└── HealthDataStore.swift         # extended with Momentum/Sleep/Snapshot facade methods

RithamApp/Ritham/Momentum/
├── Views/MomentumView.swift          # detail screen (shields, milestones, comeback CTA, flags)
├── Views/SleepCheckInView.swift      # daily Great/OK/Poor prompt
├── Views/MomentumTargetView.swift    # Settings 2-5 picker (WorkoutFrequencyView precedent)
├── MomentumRegistration.swift        # StepRegistry registrar (RecommendationsRegistration precedent)
└── MomentumSummary.swift             # the standalone queryable read D-08 requires

RithamApp/Ritham/Settings/
└── MovementSnapshotView.swift    # MOMENTUM-07's plain calendar view (opt-in toggle in SettingsView)

RithamApp/Ritham/Recommendations/
└── (RecommendationsModel.swift modified, not created — see RECOVERY-01 Integration Seam below)
```

### Pattern 1: Injected-Calendar pure date arithmetic (the DST-safety pattern)
**What:** Every function that reasons about "what week is `now` in" or "when does this week
reset" takes `Calendar` (and `Date`, where relevant) as an explicit parameter — never reads
`Calendar.current` or calls `Date()` internally.
**When to use:** Every function in the new `Momentum` domain that touches week boundaries,
comeback windows, or milestone-eligibility dates.
**Example:**
```swift
// Source: RithamCore/Sources/RithamCore/Screening/ConditionTagValidity.swift (existing precedent)
public static func expiry(from recordedAt: Date, calendar: Calendar) -> Date {
    calendar.date(byAdding: .month, value: validityWindowMonths, to: recordedAt) ?? recordedAt
}
```
This is the *pattern* to follow (inject `Calendar`, fail safe rather than force-unwrap, test with
explicit fixtures) — not the exact API, since `ConditionTagValidity` uses month-based
`date(byAdding:)` and Momentum's weekday+hour boundary needs a different Calendar API path (see
Week-Boundary Arithmetic below).

### Pattern 2: Reconciliation-on-read (lazy, idempotent fold)
**What:** Because D-01 rules out any server/background-job component, "shields auto-apply the
moment a week is about to be missed" cannot fire at that literal moment. Instead, every read of
Momentum state (opening the Momentum screen, opening HomeHubView) triggers a pure reconciliation
pass: given the ledger's `lastReconciledWeekStart` and `now`, fold over every fully-elapsed week
since then, in order, applying — in this precedence, per week —
1. Recovery Week flag active for that week → target paused, streak unaffected, no shield touched.
2. Injury freeze active for that week → streak frozen, no shield touched.
3. Otherwise: qualifying-session count (derived from `CardioQualification`/`LiftQualification`
   over that week's sessions) ≥ target → streak continues; accrue toward the next shield.
4. Otherwise (a genuine miss, no guardrail): if a shield is available, auto-consume one shield,
   streak continues. If no shield, open a 3-day Comeback window; streak is "at risk" until either
   a Comeback Session lands within the window (streak restored minus one) or the window closes
   (streak resets, framed as "Week 1 of your rebuilt streak" per D-05/roadmap framing).

**Guardrail-before-shield ordering is load-bearing**: checking the Recovery Week/injury flag
*before* shield consumption is what prevents a user who explicitly flagged a Recovery Week from
also silently losing a shield that week — a real correctness bug if the order is reversed.
**Idempotence requirement:** reconciling twice against the same `now` (e.g., app relaunch same
day) must produce the identical ledger — no double shield consumption, no double milestone award.
**Append-only requirement:** reconciliation may only ever *add* to the ledger (grant a shield,
award a milestone, open/close a comeback window) — it must never retract an already-granted
shield or already-shown milestone badge, even if a retroactive session edit (STRENGTH-05's
`applyRevision`) changes a past week's derived qualifying count after the fact. This is what
keeps Momentum consistent with STRENGTH-05's full retroactive-editing feature without needing to
"undo" a badge the user has already been shown.
**When to use:** Every app-foreground / Momentum-screen-appear event; also directly after saving
a new session (so the current week's live progress reflects the just-logged session immediately).

### Pattern 3: Single-row / range-query facade extension (existing `HealthDataStore` shape)
**What:** New persistence follows two already-proven shapes in `HealthDataStore.swift`: (a) a
single upserted row for scalar preference-like state (`WorkoutPreferenceRecord`'s
`upsertWorkoutPreference` pattern) for the weekly target and the ledger's scalar fields
(current streak, shield count, `lastReconciledWeekStart`); (b) an independently-addressable,
date-range-queryable `@Model` for append-only per-instance records (`CardioSessionRecord`'s
`loadCardioSessions(in:)` pattern) for sleep check-ins, milestone-award events, comeback claims,
and Daily Movement Snapshot entries.
**Example:**
```swift
// Source: RithamApp/Ritham/Persistence/HealthDataStore.swift (existing, lines 509-578)
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
Momentum's `saveMomentumTarget(_:)`/`loadMomentumTarget()` should mirror this exactly, with
`supportedMomentumTargets: Set<Int> = [2, 3, 4, 5]` replacing `supportedWeeklyFrequencies`.

### Pattern 4: New `OnboardingStep` cases + dedicated registrar file
**What:** Every new full-screen surface (Momentum detail screen, sleep check-in, Movement
Snapshot view) is added as a new case to the single shared `OnboardingStep` enum
(`RithamCore/Sources/RithamCore/Onboarding/OnboardingStep.swift`), implements
`OnboardingStepPresenting`, and is registered from one new owner file
(`MomentumRegistration.swift`, mirroring `RecommendationsRegistration.swift`), whose
`registerAll()` call is added to `StepBootstrap.registerAllSteps()`.
**Why this matters:** `PhaseCoverageTests.unregisteredStepsIsEmpty` is an existing acceptance
gate (`RithamApp/RithamTests/PhaseCoverageTests.swift`) that fails the whole suite if any
`OnboardingStep` case has no registered presenter — adding a case without registering it is a
guaranteed, already-instrumented test failure, not a silent gap.
**Example:**
```swift
// Source: RithamApp/Ritham/Recommendations/RecommendationsRegistration.swift (existing)
@MainActor
enum RecommendationsRegistration {
    static func registerAll() {
        StepRegistry.register(RecommendationsView.self)
        StepRegistry.register(PreAssessmentView.self)
    }
}
```

### Anti-Patterns to Avoid
- **Reimplementing the qualifying-session bar:** `CardioQualification.evaluate(_:CardioProgress)`
  and `LiftQualification.evaluate(_:LiftSession)` already exist in `RithamCore` and are already
  unit-tested against `CalibrationThreshold`. Momentum must call these, never re-derive
  `continuousDuration >= 600` or `workingSetCount >= 3 && distinctWorkingExercises >= 2` a third
  time anywhere.
- **Using `Calendar.dateInterval(of: .weekOfYear, for:)` for the Momentum week boundary:** this
  API honors the calendar's locale-dependent `firstWeekday` (Sunday in `en_US`), which will
  silently produce a Sunday-anchored week instead of the required Monday-3am boundary for any
  device whose locale/calendar doesn't default to Monday. Do not use it for this feature.
- **Reading `calendar.firstWeekday` at all for this feature:** the correct anchor is a hardcoded
  Gregorian `weekday: 2` (Monday), which is fixed regardless of locale — not a value derived from
  the user's regional settings. Momentum's week starts on Monday for every user, unconditionally.
- **Persisting the current streak length or a week's qualifying count as the source of truth:**
  both must be derivable from session records + the ledger at any time; persisting them directly
  creates a second copy that can drift after a retroactive session edit/delete (STRENGTH-05).
  Persist only what genuinely cannot be derived (see Data Model Shape below).
- **Placing `RingAndDot` near any Momentum progress display:** `RithamApp/Ritham/DesignSystem/
  RingAndDot.swift`'s own header comment states this ornament "must never sit adjacent to
  Momentum data" and is deliberately non-data-bearing (01-UI-SPEC.md's binding decision) — build
  a distinct progress component for the weekly-target ring, never repurpose or place this one
  beside it.
- **Collapsing sleep check-in / Recovery Week / injury freeze into one enum:** D-03 explicitly
  forbids this; each needs its own independent record/flag so "never auto-triggers" is
  structurally true, not just untested.
- **Calling `Date()` or `Calendar.current` inside `RithamCore`:** every other domain in this
  codebase (calibration, screening) injects both; Momentum's boundary/reconciliation functions
  must too, both for testability and because `MomentumReconciliation` needs the *same* `now`/
  `calendar` values a test fixture supplies across a DST transition.

## Week-Boundary Arithmetic (MOMENTUM-03)

**The requirement:** the tracked week resets Monday at 3am local time, not midnight Sunday
(`docs/roadmap.md` §4: "to absorb travel, time-zone shifts, and late/irregular schedules without
a false break").

**Recommended approach — total function, explicit edge-case handling, no force-unwraps:**

```swift
/// Returns the start instant of the Momentum week containing `now`: the most recent
/// Monday at 03:00 local time at or before `now`. Injected `calendar`/`now` — no `Date()`
/// or `Calendar.current` inside this function, matching `ConditionTagValidity`'s precedent.
public static func weekStart(containing now: Date, calendar: Calendar) -> Date {
    // Gregorian weekday is fixed 1=Sunday...7=Saturday regardless of locale/firstWeekday —
    // Monday is always weekday 2. Do not derive this from calendar.firstWeekday.
    let weekday = calendar.component(.weekday, from: now)
    let daysSinceMonday = (weekday - 2 + 7) % 7
    guard let candidateDay = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now),
          let candidateBoundary = calendar.date(
              bySettingHour: 3, minute: 0, second: 0, of: candidateDay
          )
    else {
        return now // fail-safe: never crash; an unreachable-in-practice overflow falls back
                   // to treating `now` itself as the boundary, same fail-safe direction as
                   // ConditionTagValidity.expiry's `?? recordedAt` fallback
    }

    if candidateBoundary > now {
        // `now` is Monday but before 3am local -- still inside the *previous* Momentum week.
        return calendar.date(byAdding: .day, value: -7, to: candidateBoundary) ?? candidateBoundary
    }
    return candidateBoundary
}
```

**Why `bySettingHour(_:minute:second:of:)` rather than `nextDate(after:matching:matchingPolicy:)`:**
`bySettingHour` operates on a day you've already identified (the candidate Monday), so it avoids
the ambiguity of `nextDate`'s exact-match-at-the-search-instant behavior at a week's exact
boundary second — an edge case this session could not independently verify against Apple's
documentation (see Assumptions Log, A1). `bySettingHour` still requires DST-aware unit tests: on
a DST transition day where local 03:00 does not exist (a "spring forward" that skips a hipper
hour range covering 3am in some non-US regions) or occurs twice (a "fall back" doubling an hour
range covering 3am in some non-US regions), `bySettingHour` returns `nil` for the non-existent
case, which this implementation must handle explicitly (falls through to `now` here — flag this
specific behavior for the planner to confirm against product intent, since "week never resets on
this one date" is a real, if rare, observable consequence of the fallback above).

**Week-assignment rule (which timestamp counts):** a session is assigned to the week containing
its `startedAt` timestamp, matching both existing `HealthDataStore.loadCardioSessions(in:)` and
`loadLiftSessions(in:)` predicates, which already filter on `startedAt` — using `startedAt`
requires no new store method. A session started at 02:50 Monday and ending 03:30 Monday is
assigned to the *previous* week (its `startedAt` precedes that Monday's 3am boundary). Document
this as a locked decision in planning, not an implicit side effect.

**Required test fixtures:** unit tests must use explicit `TimeZone(identifier:)` values (e.g.
`America/New_York` for a US spring-forward/fall-back pair, and at least one Southern Hemisphere
or non-US-DST-date zone) constructed into a dedicated `Calendar` per test — never
`Calendar.current`/`TimeZone.current`, which vary by CI/simulator configuration and would make a
DST-boundary test non-reproducible.

## Data Model Shape

**Design principle (see Pattern 2 above): derive what can be derived; persist only what cannot.**

**Derived at read time (never persisted directly):**
- This week's qualifying-session count (fold `CardioQualification.evaluate`/
  `LiftQualification.evaluate` over `loadCardioSessions(in:)`/`loadLiftSessions(in:)` for the
  current `weekStart(containing:)...weekStart+7days` range).
- Current streak length (derived from the ledger's `currentStreak` scalar *plus* re-running
  reconciliation for any weeks elapsed since `lastReconciledWeekStart` — see below; the scalar
  itself is a cached derivation, refreshed on every reconciliation pass, not independently
  editable).

**Persisted (SwiftData, new records):**

| Record | Shape | Pattern |
|--------|-------|---------|
| `MomentumStateRecord` (single row) | `currentStreak: Int`, `shieldCount: Int` (0-3), `lastReconciledWeekStart: Date`, `weeklyTarget: Int` (2-5), `visibilityScopeRaw: String` (D-07's `.private`-only-in-v1 enum) | `WorkoutPreferenceRecord` single-row-upsert pattern |
| `MilestoneAwardRecord` (append-only, one row per award) | `id: UUID`, `weekCount: Int` (4/12/26/52), `awardedAt: Date` | `CardioSessionRecord`-style independently addressable rows; never deleted by reconciliation |
| `ComebackWindowRecord` (append-only, one row per missed-week event) | `id: UUID`, `missedWeekStart: Date`, `windowClosesAt: Date` (missedWeekStart + 3 days), `claimedAt: Date?`, `claimingSessionID: UUID?` | Same shape; `claimedAt == nil && windowClosesAt > now` is the "comeback CTA visible" condition |
| `RecoveryWeekPeriodRecord` (append-only) | `id: UUID`, `weekStart: Date`, `flaggedAt: Date` | D-03: independent of injury/sleep; user-initiated only |
| `InjuryFreezePeriodRecord` (append-only) | `id: UUID`, `startedAt: Date`, `endedAt: Date?` (open-ended until user clears it) | D-03: independent state machine; freeze is open-ended, not scoped to one week like Recovery Week |
| `SleepCheckInRecord` (one row per calendar day) | `id: UUID`, `date: Date` (day-granularity), `qualityRaw: String` (great/ok/poor), `note: String?` | Simple daily record; D-04 — never read by reconciliation, never touches the ledger |
| `MovementSnapshotEntryRecord` (append-only, MOMENTUM-07) | `id: UUID`, `date: Date`, freeform fields per whatever the plain-calendar view needs (e.g. `note: String?`, `activityRaw: String?`) | D-09: entirely separate from `MomentumStateRecord` — carries no streak/shield/target reference of any kind, structurally enforced by having no foreign key to it |

**Why append-only for milestones/comeback/recovery/injury records rather than mutable fields on
the single state row:** reconciliation must never *retract* history (Pattern 2's requirement).
An append-only table of "this happened at this time" events is trivially safe against a later
retroactive session edit changing a past week's derived count — the awarded badge/claimed
comeback stays claimed regardless of what a later fold recomputes, because reconciliation only
ever asks "has this milestone already been awarded?" (a lookup) before deciding whether to award
it again (never), rather than asking "should this milestone currently be true?" (which could flip
to false after an edit).

**Reuse, not duplication, of existing session data:** Momentum's SwiftData layer adds zero new
fields to `CardioSessionRecord`/`LiftSessionRecord` and zero new columns representing
"qualifies for Momentum" — that boolean is always computed on read via
`CardioQualification.evaluate`/`LiftQualification.evaluate`, never cached, per D-02 and the
retroactive-edit consistency argument above.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Is this cardio session long enough to count?" | A new `continuousDuration >= 600` check | `CardioQualification.evaluate(_ progress: CardioProgress) -> CardioQualification` (`RithamCore/Sources/RithamCore/Cardio/CardioSession.swift`, already exists, already tested in `CardioSessionTests.swift`) | Already reads `CalibrationThreshold.qualifyingWalkDuration`; a second implementation risks drifting from calibration's own bar exactly the way D-02 warns against |
| "Is this lift session enough sets/exercises to count?" | A new `workingSetCount >= 3 && distinctWorkingExercises >= 2` check | `LiftQualification.evaluate(_ session: LiftSession) -> LiftQualification` (`RithamCore/Sources/RithamCore/Strength/LiftSession.swift`, already exists, already tested in `LiftSessionTests.swift`) | Same reuse argument; `LiftSession.workingSetCount`/`distinctWorkingExercises` are already computed properties this reads |
| "Is this session manually entered or sensor-verified?" | A new labeling enum/lookup | `CardioCaptureSource.isSensorVerified` (already exists) + `CardioHistoryView.swift` line 165's existing `"Sensor-verified"` / `"Manually entered"` label strings | Direct, already-shipped precedent for exactly this UI copy; reuse the string, don't reinvent the label logic. Note the asymmetry: `LiftSessionRecord` has no capture-source field at all (all lift sessions are manually logged) — Momentum's combined history view must handle lift entries showing no verification badge, not a default "manually entered" label invented for a field that doesn't exist |
| "Which condition tags must never trigger streak-loss messaging?" | A new hardcoded list of 5 condition tags | `WorkoutGuidanceCatalog.neverTriggersStreakLoss(_ tag: ConditionTag) -> Bool` (`RithamCore/Sources/RithamCore/Guidance/WorkoutGuidanceCatalog.swift`, already exists, header comment explicitly says "Phase 3's Momentum reads this rather than re-deriving the list") | Already-shipped, already-tested (`GuidanceCatalogTests.exactlyFiveTagsNeverTriggerStreakLoss`); the phase's own predecessor left this as a deliberate forward-reference for Momentum to consume |
| Date/week arithmetic across DST | Manual `TimeInterval`-based day/week addition (e.g. `now.addingTimeInterval(7*86400)`) | `Calendar` API (`date(byAdding:)`, `bySettingHour(_:minute:second:of:)`, `component(.weekday, from:)`) with an injected `Calendar` | `ConditionTagValidity`'s own header comment states this exact rationale for its month-based case: "a twelve-month window cannot be represented as a fixed `TimeInterval`... without reintroducing the leap-year/DST drift this rule exists to avoid" — the same argument applies to a weekly boundary |
| Weekly-frequency-style Settings preference validation | A new bespoke validation/storage path | `WorkoutPreferenceRecord`'s `upsertWorkoutPreference` single-row pattern, generalized with a new `supportedMomentumTargets: Set<Int> = [2,3,4,5]` constant | Identical shape to `supportedWeeklyFrequencies`/`saveWeeklyFrequency`; no reason to diverge |

**Key insight:** this phase's domain logic is unusually pre-built. The real net-new surface area
is (a) the week-boundary function, (b) the reconciliation fold that turns qualifying-session
counts into streak/shield/milestone state over time, and (c) the SwiftData ledger + UI wrapping
it — not a second copy of "what counts as a workout."

## Common Pitfalls

### Pitfall 1: Treating "shields auto-apply the moment a week is about to be missed" as requiring a live trigger
**What goes wrong:** A planner reads MOMENTUM-02's wording literally and tries to design a
background task, local notification, or app-launch-time-only check that fires "at the moment" a
week would be missed.
**Why it happens:** D-01 (client-side only, no server) rules out a scheduled server-side job, but
the requirement's language still sounds event-driven.
**How to avoid:** Reconciliation-on-read (Pattern 2) satisfies the requirement's observable
behavior — by the time the user next opens the app or the Momentum screen, the shield has already
been applied (or the comeback window already opened) as of the correct historical week boundary,
even though the *computation* happened later. The user never sees an un-reconciled state.
**Warning signs:** Any design doc mentioning `BackgroundTasks`, `UNUserNotificationCenter`, or a
"the app must be running at 3am Monday" assumption for this phase.

### Pitfall 2: Reconciliation double-counting or double-awarding on repeated calls
**What goes wrong:** Calling reconciliation on every app-foreground event (as recommended)
without idempotence causes the same missed week to consume a shield twice, or the same milestone
to be awarded twice, if reconciliation runs more than once against an unchanged `lastReconciledWeekStart`.
**Why it happens:** A naive "walk forward from the ledger's last state" implementation that
doesn't first check "has this specific week already been processed?"
**How to avoid:** Reconciliation must be provably idempotent: running it twice with the same
`now` and unchanged session data must produce byte-identical ledger output. Test this explicitly
(call reconcile twice in a row in a unit test, assert equal results) — this is exactly the kind
of "easy to leave unverified" negative assertion D-05 calls out for RECOVERY-01, and the same
discipline applies here.
**Warning signs:** `shieldCount` or a milestone list growing on a second identical reconciliation
call in a test.

### Pitfall 3: `Calendar.current`/`Date()` leaking into `RithamCore`'s Momentum domain
**What goes wrong:** A convenience default parameter (`calendar: Calendar = .current`) or an
internal `Date()` call makes week-boundary tests non-reproducible across CI machines in different
timezones, and makes DST-transition fixtures impossible to construct reliably.
**Why it happens:** `.current` defaults are the path of least resistance in Swift, and other
non-Core code in this app (`CardioHistoryView.swift`'s `Calendar.current.date(byAdding:...)`) does
use `.current` — but that's UI-layer convenience code, not the domain-logic layer this pattern
governs.
**How to avoid:** Every `RithamCore` Momentum function takes `calendar: Calendar` and, where
relevant, `now: Date` as required (non-defaulted) parameters, exactly as `ConditionTagValidity`
does. Only call sites in `RithamApp` (e.g., `HealthDataStore`) may supply `Calendar.current`/
`Date()` as the concrete arguments at the actual call site.
**Warning signs:** Any `RithamCore/Sources/RithamCore/Momentum/*.swift` file containing the
literal token `Calendar.current` or a bare `Date()` call.

### Pitfall 4: `PhaseCoverageTests.unregisteredStepsIsEmpty` failing after adding new screens
**What goes wrong:** Adding new `OnboardingStep` cases (Momentum detail, sleep check-in, Movement
Snapshot) without registering each with `StepRegistry` fails an existing, already-instrumented
test gate for the whole target, not just a Momentum-specific test.
**Why it happens:** `OnboardingStep` is a single shared enum (CROSSGEN-05's structural
enforcement) and every case must resolve to a presenter by the time `StepBootstrap.registerAllSteps()`
returns.
**How to avoid:** Follow Pattern 4 exactly — new registrar file, call added to
`StepBootstrap.registerAllSteps()`'s list, in the same wave/commit that adds the new
`OnboardingStep` cases.
**Warning signs:** `xcodebuild test -only-testing:RithamTests/PhaseCoverageTests` failing after
adding a Momentum screen.

### Pitfall 5: `StepRegistry`'s shared static state racing across parallel test suites
**What goes wrong:** New Momentum-related test suites that touch `StepRegistry` (any suite
calling `StepBootstrap.registerAllSteps()` in `init()`) can intermittently report registered
steps as unregistered when run in a full-target `xcodebuild test` pass, due to concurrent Swift
Testing suite execution racing on `StepRegistry`'s shared static state.
**Why it happens:** Already documented in `STATE.md` Blockers/Concerns and fixed once already in
plan 02-16 (`Phase2CoverageTests`) via `.serialized` on the affected `@Suite`.
**How to avoid:** Add `.serialized` to any new `@Suite` that calls `StepBootstrap.registerAllSteps()`
or otherwise touches `StepRegistry`'s shared state, matching the existing precedent, or run new
Momentum registration tests via their own `-only-testing:` target during development.
**Warning signs:** A new test passing in isolation (`-only-testing:RithamTests/MomentumTests`) but
failing intermittently in a full-target run.

### Pitfall 6: Assuming `dayIndex` in the Go-generated plan maps to a calendar weekday
**What goes wrong:** Building RECOVERY-01's "shift the day's suggested session lighter" as a
lookup of `plan.sessions.first { $0.dayIndex == todaysWeekday }` — this will silently either
crash-adjacent (no match for most `dayIndex` values) or match the wrong session.
**Why it happens:** `dayIndex` reads like it should mean "day of week," but
`RithamService/internal/plan/generate.go`'s `Generate` function assigns it as a plain ordinal
(`for i := 0; i < frequencyPerWeek; i++ { DayIndex: i + 1 }`) — 1..N for an N-times-per-week
plan, with zero calendar semantics.
**How to avoid:** See Open Question 2 below — this must be resolved as a planning decision, not
silently coded around.
**Warning signs:** Any code comparing `dayIndex` to `Calendar.component(.weekday, from:)`.

## Code Examples

### Reusing the existing qualifying-session evaluators (RithamCore)
```swift
// Source: RithamCore/Sources/RithamCore/Cardio/CardioSession.swift (existing)
public enum CardioQualification: Sendable, Equatable {
    case incomplete
    case complete
    public static func evaluate(_ progress: CardioProgress) -> CardioQualification {
        progress.continuousDuration >= CalibrationThreshold.qualifyingWalkDuration ? .complete : .incomplete
    }
}

// Source: RithamCore/Sources/RithamCore/Strength/LiftSession.swift (existing)
public enum LiftQualification: Sendable, Equatable {
    case incomplete
    case complete
    public static func evaluate(_ session: LiftSession) -> LiftQualification {
        let hasEnoughSets = session.workingSetCount >= CalibrationThreshold.qualifyingWorkingSets
        let hasEnoughExercises = session.distinctWorkingExercises >= CalibrationThreshold.qualifyingExercises
        return (hasEnoughSets && hasEnoughExercises) ? .complete : .incomplete
    }
}

// Momentum's weekly count (new, RithamCore) — a thin fold over the above, nothing more:
public static func qualifyingSessionCount(
    cardio: [CardioSession], lift: [LiftSession]
) -> Int {
    let qualifyingCardio = cardio.filter { CardioQualification.evaluate($0.progress) == .complete }
    let qualifyingLift = lift.filter { LiftQualification.evaluate($0) == .complete }
    return qualifyingCardio.count + qualifyingLift.count
}
```

### Range-query seam already available on `HealthDataStore`
```swift
// Source: RithamApp/Ritham/Persistence/HealthDataStore.swift (existing, lines 354-365, 417-428)
public func loadCardioSessions(in range: ClosedRange<Date>) throws -> [CardioSession] { /* ... */ }
public func loadLiftSessions(in range: ClosedRange<Date>) throws -> [LiftSession] { /* ... */ }
// A Momentum weekly-count read is simply:
// let week = MomentumWeek.weekStart(containing: now, calendar: calendar)
// let range = week...week.addingTimeInterval(7*86400 - 1)  // or a Calendar-derived end bound
// let count = qualifyingSessionCount(
//     cardio: try store.loadCardioSessions(in: range),
//     lift: try store.loadLiftSessions(in: range)
// )
```

### Existing sensor-verified labeling to reuse verbatim (UI copy)
```swift
// Source: RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift line 165 (existing)
Text(session.source.isSensorVerified ? "Sensor-verified" : "Manually entered")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| N/A | N/A | N/A | This is a greenfield feature domain; there is no prior Momentum implementation in this codebase to supersede. The only "old approach" risk is a planner re-deriving qualifying-session logic that already shipped in Phases 1-2 (see Don't Hand-Roll). |

**Deprecated/outdated:** None applicable.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Calendar.nextDate(after:matching:matchingPolicy:)`'s exact-match-at-boundary-instant behavior (whether the start instant itself is included/excluded from the search) and the precise semantics of `.nextTime` vs `.nextTimePreservingSmallerComponents` vs `.strict` `matchingPolicy` cases | Week-Boundary Arithmetic | If the planner chooses `nextDate` instead of the `bySettingHour` approach recommended here without independently confirming this behavior via Apple's official docs or a spike, the week boundary could be off by exactly one week at the precise Monday-3am-and-0-seconds instant — a rare but real edge case. Recommendation: pin behavior with unit tests, not documentation reading, regardless of which API is chosen. |
| A2 | `bySettingHour(_:minute:second:of:)` returns `nil` (rather than an adjusted valid time) when the requested hour does not exist on a given day due to a DST transition | Week-Boundary Arithmetic | If it instead silently returns an adjusted time, the `nil`-handling fallback code path in the recommended implementation is unreachable dead code rather than a real fallback — low risk (the function still returns *a* reasonable answer either way) but the documented behavior should be pinned by a DST-transition-day unit test, not left as an assumption. |
| A3 | The Foundation `Calendar` API version behavior described above applies unchanged as of the current iOS 17+ SDK this project targets | Standard Stack, Week-Boundary Arithmetic | Low risk — these are long-stable Foundation APIs; no version-specific deprecation is expected, but this session could not independently re-fetch Apple's current documentation body (WebFetch returned no page content; no Context7 MCP tool was available in this environment) to re-confirm wording. |
| A4 | Endowed-progress "first week starts pre-filled at 1/3" (MOMENTUM-01) means a *genuine head-start toward the target* (2 more qualifying sessions complete a 3-target week), not merely "the display correctly shows 1/3 after one session, which would happen anyway" | Open Question 1 | If the planner picks the no-op reading when the roadmap's own Nunes & Dreze citation clearly intends a genuine head start (or vice versa), the resulting acceptance test asserts the wrong observable behavior — this is a binary, testable difference that must be locked before implementation, not left ambiguous. |
| A5 | "The day's suggested session" (RECOVERY-01) should be interpreted client-side as the next not-yet-completed session in the current week's `WorkoutPlan.sessions` ordinal sequence, since the Go plan's `dayIndex` carries no calendar-weekday meaning | RECOVERY-01 Integration Seam, Open Question 2 | This is this session's best inference from the confirmed Go-side ordinal semantics, but it is a design choice, not a confirmed product decision — an equally plausible alternative is that RECOVERY-01 only ever adjusts a session the user is *actively about to start* (session-start-time UI, no plan-wide relabeling at all), sidestepping the `dayIndex` question entirely. Flagged for explicit planner/CONTEXT-level resolution. |

**If this table is empty:** N/A — see rows above.

## Open Questions

1. **What does "first Momentum week starts pre-filled at 1/3" concretely mean for the target
   count itself, not just the display?**
   - What we know: `docs/roadmap.md` §4 cites the Nunes & Dreze (2006) car-wash field experiment
     (a card seeded with a head start produced higher completion despite identical remaining
     effort) as the deliberate rationale — this strongly implies a genuine head start (a
     default-3 target effectively needs only 2 more qualifying sessions in week one), not merely
     a display quirk.
   - What's unclear: REQUIREMENTS.md's MOMENTUM-01 wording ("starts pre-filled at 1/3 after the
     user's first logged session") is also literally true of the no-op reading (one qualifying
     session naturally shows "1 of 3" on any week). The distinction only becomes observable if
     the user's *adjustable target* is, say, 5 — does week one become "1 of 5" (no-op) or
     genuinely require only 4 more (head start, target effectively becomes 4 for that week only)?
   - Recommendation: treat this as a locked decision the planner must state explicitly and test
     for (e.g., an acceptance test: "a user with a 5-session target who logs zero further sessions
     after their first one does/does not complete week one"), rather than letting it fall out
     implicitly from whichever counting implementation gets written first. Per RECOVERY-01's
     first invariant analog, this must not be confused with or allowed to alter the per-session
     qualification bar itself — it is a one-time week-one target adjustment, not a change to what
     counts as a qualifying session.

2. **What does "today's suggested session" mean when the Go-generated plan's `dayIndex` is a
   plain ordinal with no calendar mapping?**
   - What we know: `RithamService/internal/plan/generate.go`'s `Generate` function assigns
     `DayIndex: i + 1` for `i` in `0..<frequencyPerWeek` — a pure sequence number, confirmed by
     reading the source. `WorkoutPlan.sessions[].dayIndex` therefore cannot be compared against
     `Calendar.component(.weekday, from: Date())`.
   - What's unclear: RECOVERY-01's product language ("the day's suggested session") implies a
     calendar-day-granularity concept the current plan generation simply does not carry. Options:
     (a) treat "today's session" as the next `dayIndex` not yet marked complete this week
     (requires the client to track per-plan-session completion, which does not currently exist
     anywhere — `WorkoutPlan` is a fetched-fresh value with no persisted completion state); (b)
     apply the lighter-suggestion adjustment to every session in the currently-displayed plan
     uniformly whenever today's sleep check-in is Poor, sidestepping "which specific day" entirely;
     (c) scope RECOVERY-01 narrower — adjust only the next session the user is actively about to
     start (session-launch time UI), never the static plan list view at all.
   - Recommendation: (b) is the lowest-implementation-risk option that satisfies all seven D-05
     invariants without inventing new per-plan-session completion tracking this phase doesn't
     otherwise need — but this is a product-shape decision, not a pure implementation detail, and
     should be confirmed (or `/gsd-discuss-phase`'d) explicitly before planning locks a specific
     `RecommendationsModel`/`SleepAdjustment` interface around it.

3. **Does the Recovery Week flag apply prospectively (starting now, running for one Momentum
   week) or does the user select a specific past/current week to flag?**
   - What we know: MOMENTUM-03 says "a user-initiated Recovery Week flag pauses the target
     without breaking the streak count" with no wording about selecting a specific week.
   - What's unclear: whether flagging mid-week (e.g., Wednesday) pauses only the remainder of the
     current week, or requires the flag to be set before the week begins to count.
   - Recommendation: default to "flagging at any point during a week fully pauses that entire
     week's target retroactively for reconciliation purposes" (simplest rule, matches the
     forgiveness-first product philosophy) — but confirm this doesn't conflict with any
     UI-copy expectation the planner's `MomentumView` design sets.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond what Phase 1/2
already require (Xcode/xcodebuild toolchain, Swift 6, iOS 17+ SDK, SwiftData, Swift Testing —
all already verified present and in use by the existing codebase). No new CLI, database, or
network service dependency is introduced.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`/`@Suite`), bundled with the Swift 6 toolchain — no separate install `[VERIFIED: repo inspection, e.g. RithamCore/Tests/RithamCoreTests/CardioSessionTests.swift, RithamApp/RithamTests/PhaseCoverageTests.swift]` |
| Config file | None — `RithamCore/Package.swift`'s `.testTarget` and `RithamApp/project.yml`'s `RithamTests` target are the only configuration; no separate test-runner config |
| Quick run command | `cd RithamCore && swift test --filter MomentumTests` (pure-domain tests, fast, no simulator) |
| Full suite command | `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MOMENTUM-01 | Qualifying cardio/lift session counted equally toward shared target; manual-vs-sensor labeled distinctly; endowed 1/3 start | unit (RithamCore) | `cd RithamCore && swift test --filter MomentumTests` | ❌ Wave 0 |
| MOMENTUM-02 | Shield accrual (1/4 weeks, stacks to 3), never purchasable, auto-applies on miss | unit (RithamCore, reconciliation fold) | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ Wave 0 |
| MOMENTUM-03 | Monday 3am local reset boundary (incl. DST fixtures); Recovery Week user-initiated only | unit (RithamCore, injected `Calendar`/`TimeZone` fixtures) | `cd RithamCore && swift test --filter MomentumWeekTests` | ❌ Wave 0 |
| MOMENTUM-04 | Comeback Session within 3 days restores streak minus one, never to zero | unit (RithamCore) | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ Wave 0 |
| MOMENTUM-05 | Milestones at 4/12/26/52 weeks (badge + bonus shield), never re-derived away after retroactive edit | unit (RithamCore) | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ Wave 0 |
| MOMENTUM-06 | Private-by-default visibility; no leaderboard surface exists | unit (RithamApp, `HealthDataStore`) + source-grep (no leaderboard/network call in Momentum UI files) | `xcodebuild test -only-testing:RithamTests/MomentumStoreTests` | ❌ Wave 0 |
| MOMENTUM-07 | Daily Movement Snapshot carries no streak/shield/target reference | unit (RithamApp) — assert `MovementSnapshotEntryRecord` has no foreign key/field referencing `MomentumStateRecord` | `xcodebuild test -only-testing:RithamTests/MovementSnapshotTests` | ❌ Wave 0 |
| MOMENTUM-08 | Self-reported injury flag auto-freezes streak; independent of sleep/Recovery Week (D-03) | unit (RithamCore) — assert injury-freeze state changes never mutate `SleepCheckInRecord`/Recovery-Week state and vice versa | `cd RithamCore && swift test --filter MomentumReconciliationTests` | ❌ Wave 0 |
| RECOVERY-01 | Seven D-05 invariants: bar unchanged, lighter session fully qualifies, declining fully qualifies, skip has zero effect, never auto-consumes shield, never auto-triggers Recovery Week, no differentiating messaging | unit (RithamCore `SleepAdjustment` + RithamApp `RecommendationsModel`) — one test per invariant, plus a source-grep test for "no differentiating messaging" mirroring 02-13's "zero occurrences of X in the source file" pattern | `xcodebuild test -only-testing:RithamTests/RecoveryAdjustmentTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd RithamCore && swift test` (pure-domain suite; fast, no simulator boot required for most of this phase's logic)
- **Per wave merge:** `xcodebuild test -project RithamApp/Ritham.xcodeproj -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RithamTests/<NewSuite>` for each new suite individually, per the existing `StepRegistry` race workaround (Pitfall 5) — avoid a full-target run mid-phase
- **Phase gate:** full-target `xcodebuild test` (all suites, no `-only-testing:` filter) green before `/gsd-verify-work`, matching 02-16's precedent for closing out cross-suite races before declaring a phase done

### Wave 0 Gaps
- [ ] `RithamCore/Tests/RithamCoreTests/MomentumWeekTests.swift` — covers MOMENTUM-03 boundary arithmetic, DST fixtures
- [ ] `RithamCore/Tests/RithamCoreTests/MomentumReconciliationTests.swift` — covers MOMENTUM-01/02/04/05/08
- [ ] `RithamApp/RithamTests/MomentumStoreTests.swift` — covers `HealthDataStore` Momentum facade methods, MOMENTUM-06
- [ ] `RithamApp/RithamTests/MovementSnapshotTests.swift` — covers MOMENTUM-07
- [ ] `RithamApp/RithamTests/RecoveryAdjustmentTests.swift` — covers RECOVERY-01's seven invariants
- [ ] No new test framework install needed — Swift Testing is already the project standard

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (treated as enabled per the
project's own convention — see `.planning/config.json`'s current contents, which contain only an
unrelated `workflow._auto_chain_active` key).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No new auth surface — Momentum is entirely local-device state, no login/session concept added |
| V3 Session Management | No | Not applicable — no server session involved (D-01) |
| V4 Access Control | No | Single-user local device; no multi-tenant/role concept exists yet (household sharing is explicitly deferred to Phase 4, D-06) |
| V5 Input Validation | Yes | Weekly-target picker constrained to `{2,3,4,5}` exactly, mirroring `saveWeeklyFrequency`'s `supportedWeeklyFrequencies` guard-and-throw pattern (`HealthDataStoreError.unsupportedWeeklyFrequency` precedent) — never silently clamp an out-of-range value |
| V6 Cryptography | No | No new sensitive-data-at-rest concern beyond what SwiftData's existing on-device storage already covers; no new encryption/hashing logic needed for this phase's data shapes |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Weekly-target/Settings input tampering (out-of-range value written directly, bypassing UI) | Tampering | `HealthDataStore.saveMomentumTarget` validates against a fixed `Set<Int>` and throws rather than persisting an invalid value, exactly like the existing `saveWeeklyFrequency` |
| New sensitive self-report health data (injury flag, sleep quality) expanding the pre-launch privacy-review surface | Information Disclosure (scope, not a code vulnerability) | Per D-01/D-04, this data never leaves the device — it stays inside LAUNCH-04's existing GDPR/CCPA review surface rather than widening it (no new network transmission of health-adjacent data is introduced by this phase, unlike Phase 2's Go-backend decision which did widen that surface for `experienceLevel`/`guidancePermission`) |
| Reconciliation logic silently mis-crediting a shield/milestone due to a boundary bug | Tampering (of derived state, not attacker-controlled, but a correctness/trust concern) | Idempotence + append-only-ledger unit tests (Pitfall 2) are the mitigation — there is no external attacker model here, but an incorrect reconciliation function is functionally equivalent to a trust-boundary bug in a gamified system users rely on for motivation |

## Sources

### Primary (HIGH confidence)
- Direct repository inspection (`grep`/`Read` of `RithamCore/Sources/RithamCore/Cardio/CardioSession.swift`, `Strength/LiftSession.swift`, `Calibration/CalibrationSession.swift`, `Screening/ConditionTagValidity.swift`, `Onboarding/OnboardingStep.swift`, `Guidance/WorkoutGuidanceCatalog.swift`; `RithamApp/Ritham/Persistence/HealthDataStore.swift`, `CardioSessionRecord.swift`, `LiftSessionRecord.swift`, `LiftSetRecord.swift`; `RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift`, `Views/RecommendationsView.swift`, `RecommendationsRegistration.swift`; `RithamApp/Ritham/App/StepRegistry.swift`, `StepBootstrap.swift`, `OnboardingStepPresenting.swift`; `RithamApp/Ritham/Settings/SettingsView.swift`, `DietPlanView.swift`; `RithamApp/Ritham/Home/HomeHubView.swift`; `RithamApp/Ritham/DesignSystem/RingAndDot.swift`; `RithamService/internal/plan/generate.go`) — every "Don't Hand-Roll" and Architecture Pattern claim is grounded here.
- `.planning/phases/03-momentum-recovery/03-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `docs/roadmap.md` §4 — the authoritative mechanic spec and locked decisions.
- `.planning/phases/02-core-tracking-adjusted-guidance/02-CONTEXT.md`, `02-13-SUMMARY.md` — Phase 2's precedent this phase must not diverge from.

### Secondary (MEDIUM confidence)
- Apple Developer Documentation, `Calendar` reference (`developer.apple.com/documentation/foundation`) — confirmed the existence and general shape of `nextDate(after:matching:matchingPolicy:)` and `dateInterval(of:for:)` via a WebSearch summary; the fetched page body did not return full parameter-level text this session, so exact `matchingPolicy` semantics are `[ASSUMED]`, not `[VERIFIED]` (see Assumptions Log A1-A3).

### Tertiary (LOW confidence)
- `swiftbysundell.com/articles/computing-dates-in-swift` — general community confirmation of the "use Calendar, not raw TimeInterval, across DST" principle; consistent with but not independently authoritative beyond the in-repo `ConditionTagValidity` precedent, which is the stronger source for this claim.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, entirely existing project conventions
- Architecture: HIGH for the reuse/derivation strategy (directly grounded in confirmed existing code); MEDIUM for the exact week-boundary API choice and the RECOVERY-01 "today's session" interpretation (both flagged as open questions/assumptions requiring a planning-level decision, not a research gap)
- Pitfalls: HIGH — five of six pitfalls are drawn from this exact codebase's own documented history (STATE.md Blockers/Concerns, PhaseCoverageTests, RingAndDot's binding UI-SPEC constraint); one (Pitfall 6) is newly discovered this session by reading the Go source directly

**Research date:** 2026-09-06
**Valid until:** 30 days (stable, no external API surface at risk of change; the only volatility risk is if Phase 2's `WorkoutPlan`/`WorkoutPlanClient` shape changes before Phase 3 planning starts)
