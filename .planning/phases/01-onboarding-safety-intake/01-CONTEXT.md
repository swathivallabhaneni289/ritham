# Phase 1: Onboarding & Safety Intake - Context

**Gathered:** 2026-08-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Every new user 13 or older, regardless of health background, completes a real calibration session
and a fixed-choice safety screening that safely gates personalized guidance later — without ever
being funneled into a separate "senior" or "kid" experience. Covers: the calibration walk/
light-lift, explanation-register choice, age/dietary-pattern intake, the 13+ age floor, the
PAR-Q-style gate section, condition checklist, SCOFF eating-disorder follow-up, and the privacy
explainer. Ritham has no under-13 tier of any kind (see D-14) — there is no parental-consent flow
anywhere in this phase. Visual/copy contract is locked separately in `01-UI-SPEC.md`.

</domain>

<decisions>
## Implementation Decisions

### Calibration session mechanics
- **D-01 (corrected post-research 2026-08-23):** The walk counts as complete at 10+ continuous
  minutes. The light-lift equivalent is **3+ working sets across 2+ exercises** — this now matches
  MOMENTUM-01's actual wording verbatim (`.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`),
  correcting an earlier inference of "2+ sets across 1+ exercise" that 01-RESEARCH.md's Conflict 1
  found didn't match. One consistent "real session" bar across calibration and Momentum, confirmed
  by the user.
- **D-02:** Measured via GPS/motion sensors when the user grants location access; falls back to a
  manual stopwatch when they don't. No blocking GPS permission prompt required to proceed — the
  fallback must work standalone.
- **D-03:** Calibration is skippable via a "Skip for now" action. While skipped, the app gives the
  user a generic/temporary starting point (not a blank state) so cardio/strength suggestions still
  work — never blocks core app use pending calibration.
- **D-04:** On completion, the session sets a comfortable pace-zone range (cardio) and a safe
  starting weight (strength) — used only to set safe initial targets. Never displayed to the user
  as a score, grade, or fitness-level label.

### Age floor (supersedes the 2026-08-22/23 parental-consent design)
- **D-14 (2026-08-23, supersedes D-05/D-06/D-13):** Ritham has a permanent 13+ age floor instead
  of tiered parental consent. There is no under-13 tier of any kind — not a reduced-functionality
  one, not a gated one. Age under 13 shows a plain blocking message ("Ritham is for ages 13+") and
  lets the user back out and re-enter a different age; nothing is saved for the rejected attempt,
  matching Strava/MyFitnessPal's own age-floor pattern. A confirmed user who later edits their age
  down below 13 (e.g. in Settings) has that edit rejected, keeping the previous age. Age is
  self-attested with no verification beyond entry — matching every researched competitor (Strava,
  Nike, Peloton, MyFitnessPal); no age-verification service, ID check, or OS-level parental-control
  signal is required for Phase 1. A 13–17-year-old gets full, identical access to an 18+ user from
  the moment they enter their age — the full screening (gate section, condition checklist, SCOFF)
  included, with zero parental involvement at any point (see D-15 for why SCOFF stays included).
  Reason for the reversal: GitHub issue #1 asked for real accounts so parental-consent state could
  survive a device change; tracing that request back showed the tiered-consent design it depended
  on cost far more (a full Go backend, COPPA "email plus" compliance, Universal Links, LAUNCH-05
  legal review) than the problem it solved was worth, and no researched competitor fitness app
  builds real under-13 support at all — they all set a hard floor instead. Dropping the tier
  removes the problem GitHub issue #1 was trying to solve, not just the sign-up mechanism.
- **D-15 (2026-08-23):** SCOFF and the rest of the sensitive screening (gate section, condition
  checklist) are NOT restricted to 18+ — they run for every 13+ user identically. The screening
  exists to make guidance safer (a positive SCOFF screen pauses weight-loss/calorie features and
  shows a supportive referral, never a diagnosis or label), so excluding teens from it would leave
  them with less-adjusted, not safer, guidance — and MyFitnessPal's own 18+ floor is specifically
  because calorie-focused apps carry elevated eating-disorder risk for teens, which is exactly the
  population this screening's protective behavior is aimed at.
- **D-05, D-06, D-13 (2026-08-22/23, SUPERSEDED by D-14):** The original tiered-consent design —
  a state-machine-modeled COPPA "email plus" parental-consent flow for under-13, a Go backend
  service to run it, and a full lock on under-13 accounts pending parent confirmation. Kept here
  for history; no longer authoritative. See D-14.

### Condition-tag re-screen experience
- **D-07:** At 12-month tag expiry, the app shows a non-blocking reminder/banner — never blocks
  core app use pending re-screen.
- **D-08:** While overdue but not yet re-screened, the app keeps applying the user's existing
  (expired) condition-based restrictions rather than reverting to generic guidance — the safer
  default (over-restrict briefly, never silently under-restrict).
- **D-09:** Editing a single answer later (e.g., in Settings) re-checks only that specific
  question/section, not the entire questionnaire.

### SCOFF trigger & restriction transparency
- **D-10:** SCOFF's trigger condition was already fully specified in `docs/health-screening.md`
  §1.3/§1.4, not an open decision — it fires only when the user checks "Current or past eating
  disorder, disordered eating, or a difficult relationship with food or exercise" in the condition
  checklist. Not shown to every user.
- **D-11:** Restriction transparency (showing which condition caused an adjustment) was already
  locked by `01-UI-SPEC.md`'s persistent disclaimer tag ("Adjusted for **[Condition]** · General
  guidance, not medical advice · Edit in Settings").
- **D-12:** When 2+ condition tags apply simultaneously but only the single most restrictive gate
  is binding (per HEALTH-06's red-flag escalation logic), the disclaimer tag lists **all** matched
  conditions, not just the one currently governing the restriction.

### Claude's Discretion
- Precise light-lift qualifying threshold (D-01's "2+ sets across 1+ exercise" is inferred from
  Momentum's bar, not independently re-confirmed with the user) — verify against MOMENTUM-01
  wording during planning; flag if it diverges.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Health screening — content, flow, and legal-review status
- `docs/health-screening.md` — full intake question flow (§1), workout/nutrition adjustment rule
  tables (§2–3), disclaimer/legal framing copy (§4), and the single authoritative red-flag
  escalation logic (§5) including "Not sure → more cautious branch" and "2+ tags → single most
  restrictive gate wins." §1.3 defines the SCOFF trigger condition (D-10). §1.6 covers expiry/
  re-screening flow mechanics, which this discussion's D-07–D-09 build directly on top of.
  Portions sourced from this doc are pending LAUNCH-01 (counsel)/LAUNCH-02 (clinician) review —
  see `01-UI-SPEC.md` Copywriting Contract for the exact pending-review rows.

### Visual/copy design contract
- `01-UI-SPEC.md` — locked spacing/typography/color/copywriting contract for this phase, including
  the persistent disclaimer-tag pattern this discussion's D-11/D-12 extend, the Decorative Surface
  Inventory (which screens stay flat/no-motif), and the SwiftUI re-expression requirements for the
  sketch-003 background asset.

### Project-level requirements and roadmap
- `.planning/REQUIREMENTS.md` — MINOR-01 (13+ age floor), HEALTH-01/02/05/06 (screening
  discipline, red-flag escalation), DIET-01, EXPLAIN-01, CROSSGEN-03/05, ONBOARD-01.
- `.planning/ROADMAP.md` — Phase 1 success criteria and dependency on nothing (first phase);
  Phase 3's MOMENTUM-01 qualifying-session definition, referenced by D-01's inference.

### Mascot / brand asset
- `docs/mascot.md` — Momo two-tier asset system referenced by `01-UI-SPEC.md`'s Momo Placement
  section; note the correction flagged there (§1a's amber-accent rationale is superseded).

</canonical_refs>

<code_context>
## Existing Code Insights

No existing Swift/iOS codebase — this is the first phase of a greenfield native SwiftUI project.
No `.planning/codebase/*.md` maps exist yet. Nothing to reuse; the researcher/planner should not
expect any established patterns beyond what `01-UI-SPEC.md` locks.

</code_context>

<specifics>
## Specific Ideas

- App-wide visual identity (charcoal/coral/lime/off-white diagonal-band motif) is locked via
  `.planning/sketches/003-band-motif-asset/` and `01-UI-SPEC.md` — not re-litigated here.
- Whether Momo (the mascot) ships at all is an explicitly **open, deferred decision** — not part of
  this phase's scope to resolve. `01-UI-SPEC.md` includes provisional Momo placement guidance per
  the user's own choice to leave that content as-is rather than strip it, but implementation should
  not treat Momo's inclusion as final until that decision is made separately.
- **DIET-01 no longer has an onboarding step.** Flagged during a live design review of the
  running app (2026-08-25) as feeling "random" this early in onboarding, and resolved
  (2026-08-29) as a firm decision, not a placement tweak: the dietary-pattern question is fully
  optional and moved out of onboarding entirely into `SettingsView` (`DietaryPatternStepView`
  removed; `OnboardingRouter` routes `.age`/`.ageIneligible` straight to `.privacyExplainer`).
  Users who never open Settings simply never set a dietary pattern — `dietaryPattern` was
  already `nil`-defaulted at the persistence layer, so this required no schema change. The
  question's copy and its "never affects a clearance gate" isolation rule (DIET-01) are
  unaffected; only its mandatory-onboarding placement is gone. `DIET-01` itself is re-homed to
  Phase 2 in `ROADMAP.md`/`REQUIREMENTS.md`, alongside `DIET-02`/`DIET-03`, since that's where a
  real "diet plan" destination for it is expected to eventually live (Phase 2's tracking/guidance
  surface, though the specific screen isn't scoped yet).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The Momo go/no-go decision is not a scope-creep
deferral — it's an existing phase element whose final form is pending, tracked in `<specifics>`
above, not a new capability for a future phase.)

</deferred>

---

*Phase: 01-onboarding-safety-intake*
*Context gathered: 2026-08-23*
