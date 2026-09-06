# Phase 3: Momentum & Recovery - Context

**Gathered:** 2026-09-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Users build one fair, cross-modality weekly consistency habit ("Momentum") on top of Phase 2's
already-shipped cardio/lift tracking — a qualifying session in either modality counts equally
toward one shared weekly target, with automatic shields, a single comeback repair after a missed
week, milestone badges, non-threat-framed copy, and private-by-default visibility. Layered on top:
a daily sleep self-report (Great/OK/Poor) that shifts the day's suggested session lighter without
ever affecting streak mechanics, plus a separate optional Daily Movement Snapshot with no
streak/shield/target attached. Covers MOMENTUM-01 through MOMENTUM-08 and RECOVERY-01.

</domain>

<decisions>
## Implementation Decisions

### Architecture — client-side only
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

### Self-report signals are structurally independent (MOMENTUM-03/08, RECOVERY-01)
- **D-03:** The daily sleep check-in (RECOVERY-01), the user-initiated Recovery Week flag
  (MOMENTUM-03), and the self-reported pain/injury freeze (MOMENTUM-08) are three
  structurally independent state machines with **zero automatic transitions between them**:
  the sleep check-in never auto-triggers a Recovery Week and never auto-consumes a shield
  (RECOVERY-01's own stated invariant); a Recovery Week is only ever user-initiated, never
  auto-triggered by the app (MOMENTUM-03's own stated invariant); the pain/injury freeze is its
  own distinct self-report action. Do not collapse these into one shared "recovery state" enum
  or flag — that would make the required no-auto-trigger invariants structurally unenforceable
  rather than just untested.

### Recovery-aware suggestion (RECOVERY-01) stays client-side
- **D-04:** The sleep check-in's "shift the day's suggested session lighter" adjustment is a
  client-side post-processing step applied over whatever plan Phase 2's existing
  `WorkoutPlanClient`/`RecommendationsView` already returns. It does **not** add a new field to
  the Go `RithamService` request — Phase 2's D-07 three-field data-minimization boundary
  (`frequencyPerWeek`/`experienceLevel`/`guidancePermission`) stays exactly as-is — and requires
  no new network round-trip. Two reasons: (1) sleep-quality data never needs to leave the
  device, consistent with local-first storage; (2) this keeps RECOVERY-01 a pure
  unit-testable client concern instead of pushing its verification into the
  physical-device/cross-process bucket already deferred to the end-of-project batch pass (see
  PROJECT.md Key Decisions, 2026-09-06).
- **D-05:** RECOVERY-01's seven invariants are required unit-test assertions, not just a UI copy
  nuance, since they're all negative assertions that are easy to leave unverified: the
  qualification bar never changes; a lighter suggested session that meets the bar fully
  qualifies for Momentum; declining the lighter suggestion and doing the original session is
  always available and fully qualifies; skipping the check-in has zero effect (never a penalty,
  never an assumed "bad" state); the feature never auto-consumes a shield; it never
  auto-triggers a Recovery Week; no penalty/asterisk/badge/messaging differentiates training
  harder than suggested vs. accepting the lighter option. The planner should scope explicit test
  cases for each.

### Visibility & Household (MOMENTUM-06) — scoped deferral, not silent gap
- **D-06:** Phase 3 delivers only the private-by-default half of MOMENTUM-06: streak/shield
  state has zero visibility surface beyond the user's own device in this phase — no public
  leaderboard, no sharing of any kind. The "opt-in household/accountability-contact sharing"
  half is **not** built in Phase 3, because Household (HOUSEHOLD-01) doesn't exist until Phase
  4 — there is nothing to opt into yet. This is a scoped, dated deferral, not a silent gap:
  execution should add a dated annotation to `ROADMAP.md`'s Phase 3 criterion 5 explaining the
  split, mirroring Phase 2's own precedent (criterion 6's 2026-09-04 heart-rate correction).
  Note for whoever later closes this out: even once Phase 4 ships HOUSEHOLD-01, the
  accountability-contact half specifically stays deferred — it's HOUSEHOLD-02, already
  out-of-scope to v2 per PROJECT.md.
- **D-07:** Build the private Momentum data model with a visibility-scope property from the
  start (e.g., an enum where `.private` is the only real case in v1), so Phase 4 can add a
  `.household` case later without a data migration. Do not build any sharing UI, toggle, or
  opt-in flow now — that's Phase 4's job once a household actually exists.

### Home surface integration (forward-compat with Phase 4)
- **D-08:** Momentum surfaces (today's progress toward the weekly target, current streak count,
  shields, milestones) are added to Phase 2's existing interim `HomeHubView` — continuing the
  interim-hub pattern Phase 2's D-05 established — plus a dedicated Momentum detail screen for
  shields/milestones/history and the Recovery-Week-flag/injury-flag actions. Structure the
  underlying read (e.g., a `MomentumSummary` value read from `HealthDataStore`) as a standalone
  queryable unit, not baked into a hub-specific view model — Phase 4's polished CROSSGEN-01 home
  screen will need "today's target + current streak" as 2 of its exactly-3 default items,
  reading the same underlying data.
- **D-09:** The Daily Movement Snapshot (MOMENTUM-07) is a separate, opt-in surface (a Settings
  toggle, matching DIET-01's existing opt-in-preference pattern) with its own plain calendar-style
  view — deliberately not merged into the Momentum screen, since it must carry no
  streak/shield/target of its own.

### Claude's Discretion
The user asked to move fast with minimal back-and-forth this session, matching Phase 2's "just
build it, make it fast" instruction. The following are fast, low-risk defaults — flag and
override during planning if wrong:

- Weekly-target adjustability (2-5, default 3) is a Settings preference, following the same
  editable-preference pattern as Phase 2's workout-frequency setting.
- Comeback Session UI is a plain CTA on the Momentum screen when a week was missed and the
  3-day window is still open — no separate wizard or multi-step flow.
- Milestone badges get a simple badge case/list UI (icon + week count + one line of
  competence-framed copy) — no bespoke celebration animation. The framing constraint (never
  threat-framed; "Week 1 of your rebuilt streak," never a reset-to-zero animation) governs
  copy, not visual complexity.
- The Monday 3am local-time week-boundary math and full SwiftData schema design are left
  entirely to research/planning — not decided here.

### Folded Todos
None — no pending todo matched Phase 3's domain (the three open todos in
`.planning/todos/pending/` are all Phase 2 engineering gaps: workout-plan frequency selection
already folded into Phase 2, unpersisted GPS coordinate trail, and `SessionEditView` not wired
into history).

### Post-research resolutions (03-RESEARCH.md Open Questions 1-3)
`03-RESEARCH.md` surfaced three product-shape questions that couldn't be resolved as pure
implementation detail. Resolved here, fast, rather than looping back through discuss-phase:

- **D-10 (Open Question 1 — endowed 1/3 start is a genuine head start, not a display no-op):**
  A brand-new user's first Momentum week's effective target is the normal target minus one
  (floor of 1) after their first logged session — e.g., a default target of 3 needs only 2 more
  qualifying sessions that week; an adjusted target of 5 needs only 4. This matches
  `docs/roadmap.md` §4's explicit Nunes & Dreze (2006) citation, which only makes sense as a real
  head start, not a display artifact every reading would already show. This is a one-time,
  week-one-only target adjustment — it must never be confused with or alter the per-session
  qualification bar itself (RECOVERY-01's own "bar never changes" invariant applies by the same
  logic).
- **D-11 (Open Question 2 — RECOVERY-01 applies uniformly to the whole displayed plan, not a
  specific day):** Since the Go-generated `WorkoutPlan.sessions[].dayIndex` is a plain ordinal
  with no calendar-weekday meaning (confirmed by reading `RithamService/internal/plan/generate.go`),
  and no per-plan-session completion state exists or is needed elsewhere in this phase, RECOVERY-01's
  lighter-suggestion adjustment applies uniformly across every session in the currently-displayed
  plan whenever the day's sleep check-in is Poor — not a single "today's" session picked out by
  day-matching. This satisfies all seven D-05 invariants without inventing new per-session
  completion tracking. Lowest-implementation-risk option per research's own recommendation.
- **D-12 (Open Question 3 — Recovery Week flag pauses the whole week retroactively):**
  Flagging a Recovery Week at any point during a week fully pauses that entire week's target for
  reconciliation purposes, regardless of what day of the week the flag was set — not just the
  remainder of the week from the flag point forward. Simplest rule, matches the
  forgiveness-first product philosophy already established for shields/comeback repair.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Momentum/Recovery mechanic spec (authoritative)
- `docs/roadmap.md` §4 ("Streak System Design" / "Momentum — the mechanic") — the full mechanic
  this phase implements near-verbatim: cadence, qualifying session, shields, grace boundary,
  injury/recovery guardrail, comeback repair, milestone rewards, endowed-progress onboarding,
  informational (never threat-framed) copy, private-by-default visibility, Daily Movement
  Snapshot.
- `docs/roadmap.md` §1 ("Streak/Consistency System", "The Monetization Boundary") — forgiveness
  mechanics (shields, comeback repair, injury guardrail) are permanently free, never monetized.

### Requirements and roadmap
- `.planning/REQUIREMENTS.md` — MOMENTUM-01 through MOMENTUM-08, RECOVERY-01 (full acceptance
  detail). Also read the v2 section's `WEAR-02`/`SCHED-01`/`TIMETABLE-01` and the cycle-tracking
  deferral for what NOT to build now.
- `.planning/ROADMAP.md` — Phase 3 success criteria (1-5) and its dependency on Phase 2.
- `.planning/PROJECT.md` — Key Decisions (local-first storage; forgiveness mechanics never
  monetized, permanently; permanent 13+ floor; physical-device/AX3-AX5 verification batched to
  end of project) and Out of Scope (weekly timetable, wearable fusion, public leaderboards —
  permanent product-category exclusion).

### Prior-phase precedent this phase must not diverge from
- `.planning/phases/02-core-tracking-adjusted-guidance/02-CONTEXT.md` — D-02 (qualifying-session
  bar reuse pattern), D-05 (interim nav hub precedent this phase continues), D-06/D-07 (Go
  backend data-minimization boundary this phase must not widen per D-04 above).
- `.planning/phases/02-core-tracking-adjusted-guidance/02-13-SUMMARY.md` — `WorkoutPlanClient`/
  `RecommendationsView`'s exact shape; the surface RECOVERY-01's lighter-suggestion adjustment
  wraps.
- `.planning/ROADMAP.md` Phase 2 criterion 6's 2026-09-04 dated correction — the precedent for
  how to record a criterion that can only be partially met in this phase (see D-06 above).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RithamApp/Ritham/Persistence/{CardioSessionRecord,LiftSessionRecord}.swift` — the qualifying
  session source data Momentum reads; no changes expected, only new read-side logic.
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` — the single persistence facade pattern to
  extend for every new Momentum/Recovery record type.
- `RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift` — `CalibrationThreshold`
  constants, the qualifying-session bar's single source of truth (D-02).
- `RithamApp/Ritham/Recommendations/{WorkoutPlanClient.swift,Views/RecommendationsView.swift}` —
  the surface RECOVERY-01's lighter-suggestion adjustment wraps client-side (D-04).
- `RithamApp/Ritham/Home/HomeHubView.swift` — Phase 2's interim nav hub; Momentum summary surfaces
  here per D-08.
- `RithamApp/Ritham/Settings/DietPlanView.swift` — the opt-in-preference-in-Settings pattern
  reused for the Daily Movement Snapshot's opt-in (D-09) and weekly-target adjustability.
- `RithamApp/Ritham/Disclaimers/*.swift` — Phase 1/2's disclaimer-tag UI pattern; reuse if any
  Momentum/Recovery framing needs a standing footer note (unlikely, since this phase carries no
  new condition-tag-gated content).

### Established Patterns
- Settings-editable, gate-isolated user preference (DIET-01's pattern, reused for Phase 2's
  workout-frequency setting) — reused again for the weekly-target and Daily Movement Snapshot
  opt-ins.
- Single persistence facade (`HealthDataStore`) extended per-phase rather than new stores per
  feature.
- Interim navigation hub (Phase 2's D-05) as the landing surface for each phase's new features
  until Phase 4's polished home ships.

### Integration Points
- `HomeHubView` gains a Momentum summary section (D-08); the underlying accessor must be
  structured so Phase 4's CROSSGEN-01 home screen (exactly 3 default items: today's target,
  current streak, last session summary) can read the same data later without rework.
- `RecommendationsView`/`WorkoutPlanClient` gain a client-side wrapping layer for RECOVERY-01
  (D-04) — no changes to the Go `RithamService` contract.
- `SettingsView.swift` gains the Daily Movement Snapshot opt-in and weekly-target preference,
  alongside Phase 2's existing `DietPlanView`/frequency entries.

</code_context>

<specifics>
## Specific Ideas

- Explicit instruction this session: move fast, minimal back-and-forth, make reasonable calls —
  same posture as Phase 2's "just build it, make it fast, i dont want to spend too much time on
  this project." Discuss-phase ran in `--auto` mode as a result: no interactive questions: gray
  areas were resolved directly using Phase 2's precedent and the mechanic spec's own
  specificity (`docs/roadmap.md` §4 leaves very little genuinely open).
- Physical-device and AX3/AX5 verification for this phase's own UI is deferred to the
  single end-of-project batched pass, per PROJECT.md's 2026-09-06 decision — Phase 3 stays
  code-complete-and-unit-verified at close, not blocked on manual verification, same as Phase 2.

</specifics>

<deferred>
## Deferred Ideas

None new from this discussion — MOMENTUM-06's household-sharing half is not a new deferred idea,
it's an existing v1 requirement whose second half structurally can't land until Phase 4
(HOUSEHOLD-01) and Household's own v2 accountability-contact tier (HOUSEHOLD-02); see D-06.

</deferred>

---

*Phase: 03-momentum-recovery*
*Context gathered: 2026-09-06*
