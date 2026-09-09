# Phase 4: Household & Home - Context

**Gathered:** 2026-09-08
**Status:** Ready for planning

<domain>
## Phase Boundary

This round of Phase 4 delivers CROSSGEN-01 only: replacing `HomeHubView` (Phase 2's deliberately
"interim hub" — a vertical list of navigation buttons) with a real dashboard home screen. The
user tested the interim hub directly during Phase 3 sign-off and rejected its layout explicitly
("it should open a desktop... it should have all these many features"), which is what triggered
this phase starting now rather than after Phase 3's formal close-out.

HOUSEHOLD-01 (household grouping, cross-member cheers) and CROSSGEN-04 (visibility spectrum
controls) are both nominally "Phase 4" per ROADMAP.md but are **explicitly deferred to a later
Phase 4 round** — see Deferred Ideas below. This mirrors Phase 3's own MOMENTUM-06 scoped-deferral
precedent (03-CONTEXT.md D-06/D-07): ship the part that's ready and asked-for now, defer the rest
with a dated record rather than silently expanding this round's scope.

</domain>

<decisions>
## Implementation Decisions

### Layout — supersedes the original CROSSGEN-01 rule
- **D-01:** The original "exactly 3 things by default, everything else one tap deeper" rule is
  dropped (REQUIREMENTS.md CROSSGEN-01, revised 2026-09-08). The home screen is a real dashboard:
  multiple sections are visible on the screen itself, not behind a tap. Never a vertical list of
  `PrimaryCTAButton`/`SecondaryCTAButton` rows — `HomeHubView`'s current layout is exactly what
  was rejected and must not survive into the replacement, in shape or in spirit.

### Dashboard sections — what ships this round
- **D-02:** A logged-exercise section: a summary of recent cardio/strength activity, using
  `MomentumSummary.recentSessions` (already computed by `MomentumSummaryReader`, already
  distinguishes manual vs. sensor-verified per Phase 3's `MomentumCopy.Verification` labels — do
  not re-derive this list a second way).
- **D-03:** A sleep section: today's sleep check-in entry point, carried over unchanged from
  `HomeHubView`'s existing `SecondaryCTAButton(title: MomentumCopy.Sleep.headline) { flow.open(.sleepCheckIn) }`
  call. RECOVERY-01 invariant 3 (a skipped check-in must be indistinguishable, app-wide, from a
  day the prompt was never shown) still applies — no badge, dot, or "you haven't logged sleep"
  nudge on this section.
- **D-04 (revised 2026-09-08, Task 3 human-checkpoint feedback):** A workout-plan section on the
  dashboard, but as a compact, tap-to-open summary card (heading + a one-line status derived from
  `RecommendationsModel.state` — "Tap to get your plan" / "Building your plan…" / "N sessions
  ready" / "Couldn't load — tap to retry"), not the original always-inline embed of
  `RecommendationsSectionContent`. Tapping opens `RecommendationsQuickView`, a sheet hosting the
  same content over the same shared `RecommendationsModel` instance the summary card observes, so
  neither the sheet nor the card can go stale relative to the other. Direct product feedback: "the
  details of the diet plan should only open when I click the diet plan option. The same goes for
  the workout plan also." Supersedes the original D-04 (inline embed); `RecommendationsView`
  itself and its `.recommendations` registration are unaffected (still registered per Pitfall 4,
  still unreached by the dashboard either way).
- **D-05 (narrowed 2026-09-08 per 04-RESEARCH.md Pitfall 3/Assumption A1):** A diet-plan section
  on the dashboard, but scoped to `DietPlanView`'s DIET-01-isolated controls only — the dietary-
  pattern picker and allergen multi-select (`persistDiet`/`persistAllergens`, which never touch
  `GateResolution`). The food-allergy screening checkbox and its severity follow-up
  (`checklistBinding`/`severitySelection`) stay in the Settings-presented `DietPlanView` only, and
  are NOT duplicated onto the dashboard. Reason: that checkbox re-resolves and re-saves the full
  screening result through `flow.answers.screening`, which is empty on every fresh app launch now
  that `OnboardingRootView` roots straight at `.home` for a returning user (D-09) — embedding it on
  a screen reached fresh on every relaunch would silently wipe real condition-tag data the first
  time a returning user touched it. The user asked to see their diet plan on the dashboard, not
  specifically for the screening checkbox to move there; this narrowing preserves the former
  without introducing the latter's data-loss risk.

  **Further revised 2026-09-08 (Task 3 human-checkpoint feedback):** the diet-plan section itself
  moved from an always-inline embed of `DietPlanSectionContent` to a compact, tap-to-open summary
  card (heading + the currently saved dietary pattern, e.g. "Vegan" / "Not set"). Tapping opens
  `DietPlanQuickEditView`, a new sheet hosting only `DietPlanSectionContent` — the food-allergy
  screening checkbox stays exclusively in the Settings-presented `DietPlanView`, so this revision
  does not reopen Pitfall 3's risk; it only changes how the DIET-01-isolated pickers are reached,
  not what reaches the screening checkbox. Direct product feedback, same quote as D-04's revision
  above (diet and workout plan named together).
- **D-06:** The Momentum summary section Phase 3 already built (D-08 in 03-CONTEXT.md — progress
  blocks, streak line, shield row) carries forward into the new dashboard essentially as-is. It
  is proven, tested, reconciliation-on-read code; this phase re-parents it into the new layout,
  it does not rebuild it. MOMENTUM-06's structural no-sharing gate
  (`Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`) must keep passing against
  wherever this section ends up living.
- **D-07:** Cardio/strength logging entry points (`Track cardio`, `Log strength`) and their
  history screens, plus Guidance, remain reachable from the dashboard — as direct actions on the
  relevant section (e.g. a "Log" affordance on the exercise section), not as a separate leftover
  vertical button list bolted below the new sections. Settings remains reachable (existing gear/
  overflow pattern, not a full-width button).

### Steps and calories — explicitly NOT this round
- **D-08:** Step count and calories-burned were requested ("just like how Apple Health app
  works") but have **no data source anywhere in the codebase today** — no HealthKit integration,
  no pedometer/motion-sensor step counting, no calorie computation of any kind exists (confirmed
  by search before this decision was recorded). Adding either is new data-ingestion scope, not a
  layout change, and needs its own decision (HealthKit entitlement/permissions UX, on-device vs.
  no computation, what "calories burned" would even mean for a manually-logged strength session)
  before it is built. This phase's dashboard layout should leave room for these as a future
  section (do not architect them out), but does not implement them.

### Onboarding-restart bug — already fixed, not this phase's scope
- **D-09 [informational]:** The user also reported onboarding re-asking every relaunch even after completion.
  This was a pre-existing defect unrelated to Phase 4's scope (Phase 1/2 code,
  `OnboardingRootView`/`WorkoutPreferenceRecord`) and was fixed directly, ahead of this phase,
  once confirmed as a genuine bug rather than a design question — see commit `744784d`. Not a
  Phase 4 task; noted here only so the researcher/planner don't rediscover and re-scope it.

### Claude's Discretion
- Exact visual arrangement of sections (order, card vs. list-row styling, scroll vs. fixed
  regions) — no specific mockup or reference screenshot was given beyond "like Apple Health" and
  "a desktop" (the user's own words for "dashboard," not a literal macOS-style desktop). UI-spec
  should interpret this as: multiple always-visible, scannable sections on one scrollable screen,
  consistent with Ritham's existing dark/high-contrast visual language — not a literal skeuomorphic
  desktop metaphor.
- Whether cardio/strength history screens get their own dashboard entry point or are reached via
  the exercise section's own "see all" affordance.

</decisions>

<specifics>
## Specific Ideas

User's own words (this session, verbatim from voice-dictated messages):
- "once setup is done, whenever I try to reopen, it should not ask me the same question" — the
  onboarding-restart bug (D-09, already fixed).
- "I wanted a home page, like a dashboard with all these features... it should have a section for
  the steps... a section for the calories burned... just like how an Apple Health app works."
- "it should have a separate section for the plans that I suggested earlier — that is diet plan
  and the workout plans."
- "I don't want to see anything vertical after the questionnaire... it should open a desktop...
  many features which would say what exercise they did. They could log in sleep. They could log
  in the exercises in the dashboard."

The repeated framing is "sections, all visible at once" (Apple Health's tab/card-summary style),
explicitly contrasted against the current vertical button list — the contrast itself is the
requirement, not just the Apple Health reference.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked decision history this phase supersedes
- `.planning/ROADMAP.md` Phase 4 criterion 1 — revised 2026-09-08 with the dated annotation
  explaining the supersession; read the annotation, not just the criterion text.
- `.planning/REQUIREMENTS.md` CROSSGEN-01 — same revision, same date.
- `.planning/phases/03-momentum-recovery/03-CONTEXT.md` D-06/D-07 — the MOMENTUM-06 scoped-
  deferral precedent this phase's own deferral (Deferred Ideas below) mirrors.

### Existing screens this phase re-parents rather than rebuilds
- `RithamApp/Ritham/Home/HomeHubView.swift` — the screen this phase replaces. Its `momentumSection`
  (D-06 above) and its Movement Snapshot opt-in-gated entry (`showsMovementSnapshotEntry`) are
  reusable logic, not throwaway.
- `RithamApp/Ritham/Momentum/MomentumSummary.swift` / `MomentumSummaryReader` — the read path D-02
  and D-06 both depend on.
- `RithamApp/Ritham/Settings/DietPlanView.swift` — DIET-01, to be surfaced per D-05.
- `RithamApp/Ritham/Recommendations/Views/RecommendationsView.swift` — to be surfaced per D-04.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MomentumSummaryReader.summary(now:)` — already the single source of truth for streak/shield/
  recent-session data; the new dashboard's exercise and momentum sections should read through
  this, not duplicate `HealthDataStore` calls directly.
- `DietPlanView`, `RecommendationsView` — both fully built screens; this phase's job for D-04/D-05
  is presentation (embed as a section) not construction.

### Established Patterns
- `HomeHubView`'s own `nonisolated static func` extraction pattern
  (`showsMovementSnapshotEntry(optIn:)`, `routingSteps(movementSnapshotOptIn:)`) for making a
  view's structural/routing decisions unit-testable without rendering — the new dashboard should
  follow the same pattern for whatever section-visibility logic it needs (e.g., movement snapshot
  opt-in gating carries forward unchanged).
- CROSSGEN-05: exactly one navigation container for the whole app
  (`RithamApp/Ritham/App/OnboardingRootView.swift`) — the new dashboard is still reached via
  `.home` in that same container; it must not introduce a second `NavigationStack` or its own
  destination resolver.

### Integration Points
- `OnboardingStep.home` remains the step identifier; `StepBootstrap`/`OnboardingCompletionRegistration`
  still register `.home` to whatever view replaces `HomeHubView`, not a new step case.

### No data source exists for
- Step counts, calorie computation, HealthKit/CoreMotion of any kind (confirmed by search — zero
  references anywhere in `RithamApp`/`RithamCore`). See D-08.

</code_context>

<deferred>
## Deferred Ideas

- **HOUSEHOLD-01** (household grouping — grandparent/parent/teen under one plan, fixed non-ranked
  cheers, no leaderboard/comparison) — deferred to a later Phase 4 round. Genuinely new social/
  multi-user scope, unrelated to the dashboard layout itself.
- **CROSSGEN-04** (visibility spectrum — private solo vs. opt-in household sharing) — deferred
  alongside HOUSEHOLD-01, since it only has meaning once a household/sharing concept exists to
  have a visibility spectrum over.
- **Steps and calories tracking** (D-08) — needs its own scoping decision (HealthKit integration,
  permissions UX, what "calories burned" means for manually-logged sessions) before it can be
  planned. Not silently dropped — flagged here and in D-08 so a future session picks it up
  deliberately rather than rediscovering the gap.
- **Automatic/device-based workout detection** (raised 2026-09-09, Task 3 checkpoint, sixth round
  of dashboard feedback) — direct concern that manual cardio/strength logging requires the user to
  "practically go and stop it" themselves, versus other apps/devices that "can actually calculate
  the act... be more accurate about the details." Same class of new data-ingestion scope as D-08's
  steps/calories deferral (HealthKit/CoreMotion integration, permissions UX, what device-detected
  "automatic" logging even means alongside the existing manual `CardioSession`/`LiftSession` flows)
  — not a layout change, and not folded into this round's visual pass. Flagged here so a future
  session scopes it deliberately rather than rediscovering it.

</deferred>

---

*Phase: 04-household-home*
