# Phase 1: Onboarding & Safety Intake - Context

**Gathered:** 2026-08-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Every new user, regardless of age or health background, completes a real calibration session and
a fixed-choice safety screening that safely gates personalized guidance later — without ever being
funneled into a separate "senior" or "kid" experience. Covers: the calibration walk/light-lift,
explanation-register choice, age/dietary-pattern intake, parental consent for minors, the
PAR-Q-style gate section, condition checklist, SCOFF eating-disorder follow-up, and the privacy
explainer. Visual/copy contract is locked separately in `01-UI-SPEC.md`.

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

### Parental consent verification (MINOR-01/02)
- **D-05 (corrected post-research 2026-08-23):** A single email-link click does not meet the FTC
  COPPA "email plus" bar for verifiable parental consent (01-RESEARCH.md Conflict 2 — confirmed
  MEDIUM confidence, cross-referenced legal-industry sourcing; amended COPPA Rule, in force as of
  April 22, 2026, retains this requirement). Building the full compliant flow now, not a
  placeholder: consent is modeled as a **state machine**, not a boolean —
  `pending → email_sent → link_clicked → confirmed`. Email 1 contains the confirmation link; on
  click, after a short delay (a few hours), a second confirmation email is sent asking the parent
  to confirm again — that delayed second email is the "plus" factor, chosen because it requires no
  additional parent-identifying data beyond the email address already collected (satisfies
  MINOR-02). No SMS/phone/account-linking mechanism in Phase 1. Backend: a minimal server
  (send/verify the email tokens) plus a Universal Link back into the app — this is the one
  capability in this phase that cannot be client-only, since the parent's email client isn't
  running the iOS app. Open legal question not resolved here (flag for LAUNCH-05 review, does not
  block Phase 1 build): whether using a third-party email vendor under a data-processing agreement
  counts as third-party disclosure under email-plus's internal-use-only limitation.
- **D-13:** The backend service is written in **Go**, per direct user instruction — this overrides
  01-RESEARCH.md's TypeScript/Supabase-Edge-Functions suggestion (that was Claude's recommendation,
  not a locked decision, and the research's `resend`/`@supabase/supabase-js` package references
  were npm examples for that now-superseded suggestion). The service still does the same job:
  generate a single-use expiring consent token, send the initial and delayed second confirmation
  emails, verify the click, hand off to the app via Universal Link. Hosting/framework choice
  (Vapor-adjacent Go equivalent, e.g. a plain `net/http` service or a minimal router like `chi`) is
  Claude's Discretion during planning — not discussed in depth with the user.
- **D-06:** While awaiting parent confirmation (any state before `confirmed`), the under-13 account
  is fully locked — no preview access, no partial functionality. This differs from the 13–17 flow,
  which already allows calibration/tracking/Momentum before parental approval per
  `docs/health-screening.md` §1.1 — that distinction is preserved, not changed by this decision.

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
- Exact resend/edit-email UX for the parental-consent flow (if the parent's email was mistyped or
  the link expires) — standard pattern, not discussed in depth; planner/executor should implement
  a reasonable resend/edit affordance without a fixed-height layout constraint.
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
- `.planning/REQUIREMENTS.md` — MINOR-01/02 (parental consent), HEALTH-01/02/05/06 (screening
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
