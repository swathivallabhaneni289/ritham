# Phase 2: Core Tracking & Adjusted Guidance - Context

**Gathered:** 2026-09-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can log every real training session — cardio or strength — and see safety-adjusted
guidance the moment it applies, forever for free. Covers: GPS/manual-stopwatch cardio tracking,
strength tracking with plate calculator/supersets/movement-pattern tagging and full retroactive
editing, condition-tag-adjusted workout/nutrition guidance, dietary-pattern (vegetarian/vegan)
swaps, the "always free" monetization statement, passive-first capture, and — per this
discussion — ONBOARD-01's triggered walk/lift pre-assessment and a lightweight interim navigation
hub so Phase 2's own features are reachable in the running app.

</domain>

<decisions>
## Implementation Decisions

### ONBOARD-01 trigger scope
- **D-01:** The ONBOARD-01 triggered pre-assessment (real walk/lift baseline session) is built in
  Phase 2, not deferred to a future phase. Keeps "recommendations" meaningful from the start of
  this phase rather than shipping tracking with no real recommendation entry point.
- **D-02:** Real CARDIO/STRENGTH session tracking is a **separate `WorkoutSession` domain**, not a
  reuse/extension of `CalibrationSession.swift`. It references `CalibrationThreshold`'s constants
  (10+ min walk / 3+ working sets across 2+ exercises) as the shared "qualifying session" bar, but
  calibration stays a narrow, isolated one-time baseline concept — richer tracking fields (GPS
  route, splits, sets/reps/weight per exercise, notes) live in the new domain.
- **D-03:** The trigger's entry point is a **dedicated "Recommendations" surface** (new tab/screen/
  CTA the user explicitly opens) — an explicit ask, matching ONBOARD-01's "the first time they
  request recommendations" wording, not an inferred moment folded into other guidance.
- **D-04:** Completing the triggered pre-assessment stays **baseline-only** — it never appears in
  training history or counts as a real logged session. Consistent with Phase 1's D-04 (calibration
  output never shown as a score/grade/label); it exists purely to set a safe starting point.

### Home navigation
- **D-05:** Phase 2 builds a **lightweight interim navigation hub** so its own features (tracking,
  recommendations, diet plan) are actually reachable in the running app — not CROSSGEN-01's
  polished 3-item home design (that stays Phase 4's scope), just enough real navigation to use and
  test what Phase 2 ships. Direct user request, not a Claude default: without this, Phase 2's
  features would be unreachable outside debug routing until Phase 4, the same gap that deferred
  Phase 1's compact disclaimer tag check.

### Backend architecture (Go)
- **D-06:** Starting Phase 2, new server-side logic runs behind a **Go backend API**, beginning
  with workout-plan generation. The iOS client (`RithamApp`/`RithamCore`) stays Swift — Go has no
  native iOS UI framework, so it was never a candidate for the client itself. Phase 1's existing
  Swift domain logic (screening, gate-resolution, calibration, dietary-pattern rules) is **not**
  ported and is not touched by this decision — it stays client-side, exactly as shipped and
  verified. This is a direct product decision (2026-09-04) driven by the user's job search
  (general software-engineering roles, not iOS-specific) rather than a technical or product
  requirement of Ritham itself — see `PROJECT.md` Key Decisions for the full reasoning trail.
- **D-07:** Exactly what data crosses the Go API boundary (e.g., whether raw condition tags leave
  the device for plan generation, or only a derived/minimized signal) is decided **during planning,
  per-feature** — not settled globally in this discussion. Flag for the planner: this widens the
  GDPR/CCPA privacy-review surface (LAUNCH-04) beyond what Phase 1 assumed under local-first-only
  storage, so prefer the smallest data surface that still lets the backend do its job.

### Claude's Discretion
The user asked to move quickly ("just build it, make it fast, don't want to spend too much time
on this project") rather than continue interactively through every remaining gray area. The
following were decided by Claude as fast, low-risk defaults — flag and override any of them
during planning if they're wrong:

- **Workout frequency (3/5/7 days/week):** set once as an editable Settings preference, same
  pattern as DIET-01 — user can change it anytime; a change affects future plan generation, not a
  one-time lock.
- **Experience-level classification** for plan scaling: derived from calibration/baseline output
  (`CalibrationBaseline`) when available, falling back to self-report for users who skipped
  calibration (Phase 1's D-03: skipping gives a generic/temporary starting point, never a blank
  state).
- Frequency/experience-scaling does **not** get its own new requirement ID — folds into the
  existing STRENGTH-0x/CARDIO-0x requirements already scoped to Phase 2.
- **Condition-adjusted guidance surfacing (HEALTH-03/04):** reuses Phase 1's already-built,
  verified disclaimer-tag pattern (`ConditionDisclaimerTag`, `RequiredBlockingMessageView`) rather
  than inventing a new UI pattern — appears inline wherever workout/nutrition guidance is shown
  during logging/planning.
- **Passive-first capture (CROSSGEN-02):** auto-detect surfaces a confirmation prompt only while
  the app is open ("Did you just start moving? Log this session?") — no silent background
  auto-logging in v1. Keeps sensor/permission scope lean.

### Folded Todos
- **"Workout plan frequency selection and experience scaling"** (captured 2026-09-03, during Phase
  1 closeout) — folded in full. Addressed by the frequency/experience-scaling defaults above; the
  todo's own open questions (once-vs-per-generation, classification method, requirement-ID
  question) are answered there.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Adjustment-rule content sources (HEALTH-03/04, DIET-02/03)
- `docs/health-screening.md` §2 (Workout Adjustment Rule Table), §3 (Nutrition Adjustment Rule
  Table) — the authoritative condition-tag → guidance-adjustment content this phase surfaces.
- `docs/dietary-pattern.md` §3 (Protein & Food-Source Swap Table), §4 (Nutrient-Awareness
  Education Blocks) — content source for DIET-02/DIET-03.

### Product vision (CARDIO/STRENGTH/MONETIZE-01)
- `docs/roadmap.md` §1 (Core Features: Cardio & Activity Tracking, Strength Tracking, The
  Monetization Boundary) — vision language for what "always free" covers and activity-type scope.
  §4 (Momentum mechanic) is cross-reference only — Momentum itself is Phase 3.

### Project-level requirements, roadmap, and prior-phase decisions
- `.planning/REQUIREMENTS.md` — CARDIO-01/02/03, STRENGTH-01–05, HEALTH-03/04, DIET-01/02/03,
  MONETIZE-01, CROSSGEN-02, ONBOARD-01 (provisional → now in-scope per D-01).
- `.planning/ROADMAP.md` — Phase 2 success criteria and dependency on Phase 1.
- `.planning/phases/01-onboarding-safety-intake/01-CONTEXT.md` — D-01–D-04 (calibration mechanics
  and thresholds this phase's WorkoutSession domain must not diverge from), D-14/D-15 (permanent
  13+ floor), the DIET-01 re-homing note.
- `.planning/PROJECT.md` — Key Decisions, including the new Go-backend decision (D-06/D-07 above)
  and its full rationale.

### Reused implementation reference
- `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` — `CalibrationThreshold`
  constants are the single source of truth for the "qualifying session" bar; the new
  `WorkoutSession` domain (D-02) must reference these, not restate the numbers.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RithamApp/Ritham/Settings/DietPlanView.swift` — DIET-01 (set dietary pattern + food allergens
  in Settings, isolated from any clearance gate) is **already built and working**. Phase 2's real
  new DIET work is DIET-02 (protein-swap lookup) and DIET-03 (nutrient-education blocks) only.
- `RithamCore/Sources/RithamCore/Screening/{GateResolution,ConditionTag,TagDerivation}.swift` —
  the condition-tag/clearance-gate domain HEALTH-03/04 read from; already exists and is tested.
- `RithamApp/Ritham/Disclaimers/{ConditionDisclaimerTag,RequiredBlockingMessageView,
  StandingFooterDisclaimer}.swift` — Phase 1's disclaimer UI, reused per Claude's Discretion above
  for HEALTH-03/04 surfacing rather than building new UI.
- `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` — `CalibrationThreshold`,
  `WalkProgress`, `LiftProgress` types; the new `WorkoutSession` domain references
  `CalibrationThreshold`'s constants (D-02).
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` — the single persistence facade pattern to
  extend for workout-session and frequency-preference storage, consistent with Phase 1's design.

### Established Patterns
- Settings-editable, gate-isolated user preference (DIET-01's own pattern) — reused for the
  workout-frequency preference (Claude's Discretion above).
- Persistent disclaimer-tag + required-blocking-message pair for surfacing condition-adjusted
  content — reused as-is for HEALTH-03/04 rather than inventing new UI.

### Integration Points
- `OnboardingRouter`'s `.home` step is explicitly a stub (not the real home screen). Phase 2's
  interim navigation hub (D-05) is the first real replacement for it, ahead of Phase 4's polished
  CROSSGEN-01 design.
- `SettingsView.swift` is the existing entry point `DietPlanView` already hangs off of — the new
  Recommendations surface (D-03) and interim nav hub (D-05) are new entry points alongside it.

</code_context>

<specifics>
## Specific Ideas

- The Go-backend decision (D-06) is motivated by the user's job search — they're applying to
  general software-engineering roles (not iOS-specific) and want genuine Go experience on their
  resume, not just Swift. This is documented so downstream agents don't mistake it for a technical
  or product requirement of Ritham itself; treat it as a real, standing architecture decision
  regardless of its origin.
- Explicit instruction from the user: **"just build it, make it fast, i dont want to spend too
  much time on this project."** Downstream research/planning/execution should favor lean,
  fast-to-ship scope over exhaustive design — default to reasonable choices (see Claude's
  Discretion above) rather than open-ended further discussion, and keep the Go backend's initial
  surface area small (workout-plan generation only, not a broader logic migration).

</specifics>

<deferred>
## Deferred Ideas

None new from this discussion. (The Momo mascot go/no-go decision remains open from Phase 1 — not
re-litigated here.)

</deferred>

---

*Phase: 02-core-tracking-adjusted-guidance*
*Context gathered: 2026-09-04*
