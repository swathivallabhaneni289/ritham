# Phase 1: Onboarding & Safety Intake - Research

**Researched:** 2026-08-23
**Domain:** Native iOS (SwiftUI/SwiftData) onboarding wizard + fixed-choice health screening + COPPA-gated parental consent + custom decorative Shape geometry
**Confidence:** MEDIUM — core SwiftUI/SwiftData patterns are well-established (MEDIUM, WebSearch cross-referenced against Apple docs); the parental-consent legal mechanism has a confirmed conflict with the locked CONTEXT.md decision (see Conflicts block below); calibration-session sensor mechanics (CMPedometer) are newly researched this session and unverified on real hardware.

> **⚠️ SUPERSEDED, 2026-08-23 — read before using this document.** Everything below concerning
> parental consent, COPPA "email plus," the under-13/13-17/18+ tiered-access model, consent tokens,
> Universal Links, and the parent-consent backend service (Conflict 2, the MINOR-01/02 rows, the
> consent architecture/data-flow sections, the Don't Hand-Roll and threat-model entries about
> consent tokens, and every other consent-related passage) describes a design that has since been
> **reversed and is no longer authoritative**. Ritham now has a permanent 13+ age floor with no
> under-13 tier of any kind and no parental-consent flow at any age — see `01-CONTEXT.md` D-14/D-15
> for the reversal and its reasoning. This research is kept in place as historical record of why the
> original tiered-consent design looked the way it did; it is not deleted, but it must not be used
> as input to planning or implementation. The remaining content of this document — calibration
> mechanics, gate-resolution/SCOFF/condition-tag architecture, the wizard-flow and custom-`Shape`
> patterns, testing/security guidance unrelated to consent — is unaffected and still current.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Calibration session mechanics**
- **D-01:** The walk counts as complete at 10+ continuous minutes. The light-lift equivalent is
  inferred as 2+ sets across 1+ exercise, mirroring the Momentum qualifying-session bar
  (MOMENTUM-01) so the app has one consistent definition of "a real session" from day one — not
  separately re-confirmed with the user, flag for planner/researcher to verify against
  MOMENTUM-01's exact wording.
- **D-02:** Measured via GPS/motion sensors when the user grants location access; falls back to a
  manual stopwatch when they don't. No blocking GPS permission prompt required to proceed — the
  fallback must work standalone.
- **D-03:** Calibration is skippable via a "Skip for now" action. While skipped, the app gives the
  user a generic/temporary starting point (not a blank state) so cardio/strength suggestions still
  work — never blocks core app use pending calibration.
- **D-04:** On completion, the session sets a comfortable pace-zone range (cardio) and a safe
  starting weight (strength) — used only to set safe initial targets. Never displayed to the user
  as a score, grade, or fitness-level label.

**Parental consent verification (MINOR-01/02)**
- **D-05:** Verification mechanism is an email link: the under-13 user enters a parent/guardian
  email address, the parent receives an email containing a confirmation link, clicking it is the
  approval. No SMS/phone, no account-linking mechanism in Phase 1.
- **D-06:** While awaiting parent confirmation, the under-13 account is fully locked — no preview
  access, no partial functionality. This differs from the 13–17 flow, which already allows
  calibration/tracking/Momentum before parental approval per `docs/health-screening.md` §1.1 — that
  distinction is preserved, not changed by this decision.

> **Superseded 2026-08-23:** D-05/D-06 (and the MINOR-01/02 tiered-consent reading they research)
> are replaced by `01-CONTEXT.md` D-14 — a permanent 13+ age floor, no under-13 tier, no parental
> consent at any age. Kept here for historical record only.

**Condition-tag re-screen experience**
- **D-07:** At 12-month tag expiry, the app shows a non-blocking reminder/banner — never blocks
  core app use pending re-screen.
- **D-08:** While overdue but not yet re-screened, the app keeps applying the user's existing
  (expired) condition-based restrictions rather than reverting to generic guidance — the safer
  default (over-restrict briefly, never silently under-restrict).
- **D-09:** Editing a single answer later (e.g., in Settings) re-checks only that specific
  question/section, not the entire questionnaire.

**SCOFF trigger & restriction transparency**
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
  wording during planning; flag if it diverges. **See Conflicts block below — this has diverged.**

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (The Momo go/no-go decision is not a scope-creep
deferral — it's an existing phase element whose final form is pending, tracked separately, not a
new capability for a future phase.)
</user_constraints>

---

### ⚠️ Conflicts With Locked Decisions — Require User Confirmation Before Planning

Two locked decisions in CONTEXT.md were explicitly flagged by the discuss-phase for researcher
verification. Both have now surfaced real conflicts against verified facts. **The planner must not
silently implement D-01 or D-05 as literally written — route these back through
`/gsd-discuss-phase` or get explicit user sign-off before planning locks them in.**

#### Conflict 1 — D-01's light-lift threshold does not match MOMENTUM-01

- **D-01 says:** "The light-lift equivalent is inferred as 2+ sets across 1+ exercise."
- **MOMENTUM-01 (REQUIREMENTS.md line 134-135) actually says:** "a qualifying lift session (at
  least 3 working sets across 2+ exercises)." `.planning/ROADMAP.md` line 96-98 restates the same
  number: "3+ working sets across 2+ exercises."
- **Verdict:** `[VERIFIED: .planning/REQUIREMENTS.md, .planning/ROADMAP.md]` — this is a direct
  textual mismatch on both numbers (sets: 2 vs 3; exercises: 1 vs 2), not a rounding difference.
- **Why it matters:** CONTEXT.md's own stated intent for D-01 is "one consistent definition of 'a
  real session' from day one." As currently worded, the calibration bar and the Momentum
  qualifying-session bar are two different definitions — a user could complete calibration under
  D-01's lighter threshold, then not have that same session count toward their first Momentum week
  under MOMENTUM-01's stricter threshold, or vice versa on the first `1/3` pre-fill described in
  MOMENTUM-01's success criteria.
- **Recommendation:** Use MOMENTUM-01's actual wording — "3+ working sets across 2+ exercises" —
  as the light-lift calibration bar, not D-01's inferred "2+ sets across 1+ exercise." This is the
  one-line fix that restores the "one consistent definition" intent D-01 itself states. Flag for
  explicit user confirmation since it changes a locked decision's literal numbers.

#### Conflict 2 — D-05's single-click email link does not meet the FTC's own "email plus" bar

- **D-05 says:** "the under-13 user enters a parent/guardian email address, the parent receives an
  email containing a confirmation link, clicking it is the approval" — i.e., one email, one link,
  one click, done.
- **What FTC COPPA guidance actually requires for "email plus"** `[CITED: FTC COPPA guidance,
  cross-referenced across multiple 2025-2026 legal-industry summaries — see Sources; direct fetch
  of ftc.gov and eCFR was blocked (HTTP 403) this session, so this is not a primary-source
  confirmation]`, confidence per the `classify-confidence` seam = MEDIUM (verified/cross-checked
  websearch, not a raw single search):
  - "Email plus" is not a single click. It requires an initial email **plus a distinct confirming
    step**: either (a) a second confirmation message sent to the parent after a time delay, or
    (b) collecting a phone/fax/mailing address in the reply so the operator can follow up with a
    confirming call, fax, or letter.
  - Email-plus is only a valid method when the child's personal information is **not disclosed to
    third parties** (internal-use-only data collection). It is explicitly *not* adequate for
    consenting to third-party disclosure or advertising use.
  - The amended COPPA Rule (published April 22, 2025; compliance required by April 22, 2026 — now
    in force as of this research date) **retains** the email-plus method essentially unchanged,
    alongside a new sibling "text plus" method and several higher-assurance methods (KBA, facial
    recognition + government ID, etc.). This is not a stale, pre-amendment finding.
- **Why it matters:** MINOR-01/02 and LAUNCH-05 (COPPA compliance review, gating public App Store
  submission) both depend on the consent mechanism actually satisfying FTC's own definition of the
  method it claims to use. A single-click link with no second confirming step is not "email plus"
  by the FTC's own description of the method — it's closer to no-verification-at-all with an email
  step bolted on. Building it exactly as D-05 describes creates real risk of failing LAUNCH-05.
- **Recommendation — architectural, not just "add a step":** Don't hard-code "link click ==
  consent" into the data model. Model parental consent as a **state machine with a pluggable
  verification step** (`pending → email_sent → link_clicked → confirmed` rather than
  `pending → confirmed` in one hop), so Phase 5's clinician/counsel review (LAUNCH-05) can require
  a stronger method later without a schema rewrite. The **lowest-friction compliant "plus" factor**
  for MVP is a **delayed second confirmation email** (send email 1 with the link; on click, wait a
  short delay — e.g., a few hours — then send email 2 asking the parent to confirm again) — this
  requires zero additional parent-identifying data, directly matching MINOR-02's "collects no more
  parent-identifying information than the consent method strictly requires."
- **Open sub-question, not resolved here:** whether using Supabase/a third-party email-sending
  vendor (Resend, etc.) under a data-processing agreement counts as "disclosure to a third party"
  for email-plus's internal-use-only limitation is a legal determination, not a technical one — see
  Open Questions below. Flag for LAUNCH-05 counsel review, don't assume a service-provider
  relationship is automatically exempt.

> **Superseded 2026-08-23:** This entire conflict is moot — `01-CONTEXT.md` D-14 replaces the
> tiered-consent design with a permanent 13+ age floor, so there is no parental-consent mechanism
> left to satisfy FTC's "email plus" bar, no consent state machine to build, and LAUNCH-05 (the
> COPPA compliance review this conflict was blocking) no longer exists as a requirement. This
> analysis remains valuable as the record of *why* the original design changed — the cost/rigor
> this conflict surfaced (a real backend, a multi-step verification flow, an ongoing legal-review
> dependency) is a direct input to D-14's cost/benefit reversal — but it is not an open item to
> resolve going forward.

---

## Summary

Phase 1 is the first code in a greenfield native iOS app: there is no existing Xcode project,
Package.swift, or established pattern to reuse. This phase must simultaneously (1) stand up the
project's foundational technical choices — persistence, navigation/state management for a
multi-step wizard, and a custom decorative `Shape` — and (2) implement a genuinely
compliance-sensitive flow (COPPA-gated consent, fixed-choice health screening with SCOFF and
red-flag escalation logic) where getting the architecture wrong now creates real rework risk later
(Phase 5's LAUNCH-01/02/05 legal/clinical review gates public shipping, not code correctness).

**Primary recommendation:** Use SwiftData (not Core Data) for all Phase 1 persistence, a single
`NavigationStack` driven by a shared `@Observable` flow-state model for the onboarding wizard, a
custom `Shape` (not `GeometryReader`-wrapped image) for the band-motif header keyed off
`dynamicTypeSize.isAccessibilitySize`, `CMPedometer`/`CMPedestrianActivity` (not raw
`CoreLocation`) as the no-permission-prompt-required path for the walk calibration, and a
consent-state-machine data model (not a boolean) for parental consent so Phase 5's compliance
review doesn't force a rewrite. **The two locked decisions flagged above (D-01, D-05) need explicit
user confirmation before the planner treats them as final** — everything else in this document can
proceed straight to planning.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ONBOARD-01 | Guided walk-or-light-lift calibration sets real starting baseline, never a dropdown | CMPedometer research (calibration mechanics); SwiftData model for storing baseline; Conflict 1 above must be resolved before the light-lift bar is implemented |
| EXPLAIN-01 | User-chosen explanation register (plain/technical), changeable anytime, tap-to-expand everywhere | SwiftUI wizard-state pattern (register stored in flow-state model, persisted to SwiftData, read via `@Environment` app-wide) |
| HEALTH-01 | Fixed-choice screening questionnaire, full branching logic per docs/health-screening.md | Wizard navigation pattern (conditional `navigationDestination` push based on prior answers); pure-Swift gate-resolution module recommended in Validation Architecture below |
| HEALTH-02 | Condition tags + clearance toggle valid 12mo, re-screen prompted at expiry | SwiftData model with an `expiresAt` field; D-07/D-08's "keep applying expired restrictions" behavior is a query-time check, not a data-deletion event |
| HEALTH-05 | Standard disclaimer/legal copy blocks at defined touchpoints | Already fully drafted verbatim in 01-UI-SPEC.md Copywriting Contract — no additional research needed, straight implementation |
| HEALTH-06 | Red-flag escalation logic: "Not sure" → cautious; 2+ tags → most restrictive; block domain only | Recommend implementing as a pure Swift module, unit-testable in isolation — see Validation Architecture |
| MINOR-01 | Age resolves tiered parental-consent gate (under-13 halts; 13-17 partial gate; 18+ no gate) | Consent state-machine model (Conflict 2 above); Universal Links research for the confirm-in-app step |
| MINOR-02 | Consent step never requires minor to hold parent credentials; minimal parent-identifying info | Delayed-second-email "plus" factor requires zero additional parent PII beyond the email address already being collected — see Conflict 2 |
| DIET-01 | dietary_pattern set right after age, editable in Settings, never touches gate logic | SwiftData model field, no gate coupling — already locked as a project-wide Key Decision in PROJECT.md |
| CROSSGEN-03 | Privacy explained on one screen before any opt-in; nothing shared by default | Copy already drafted in 01-UI-SPEC.md; no technical research needed beyond standard SwiftUI screen |
| CROSSGEN-05 | No age-gated fork anywhere — age only adjusts content within shared screens | Directly informs the wizard pattern: age/consent state must gate *which step is next* in one shared `NavigationStack`, never route to a structurally different view hierarchy |
</phase_requirements>

> **Superseded 2026-08-23:** The MINOR-01 and MINOR-02 rows above describe the old tiered-consent
> reading of those requirement IDs. MINOR-01 has since been rewritten (see `.planning/REQUIREMENTS.md`)
> to a permanent 13+ age floor with self-attested age and no consent step; MINOR-02 no longer exists
> as a requirement — there is no consent step left to require anything of. See `01-CONTEXT.md`
> D-14/D-15. The CROSSGEN-05 row's "age/consent state must gate which step is next" phrasing should
> now be read as "age" only — CROSSGEN-05 itself is unaffected and, per D-14, is now easier to
> satisfy since there is no consent-driven branch to avoid creating.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Onboarding wizard flow/state | Client (SwiftUI app) | — | Entirely on-device; no server round-trip needed to progress through steps |
| Screening answers, condition tags, calibration baseline | Client (SwiftData, local-first) | Cloud sync (backup only, per PROJECT.md Key Decision) | Local-first is a project-wide locked decision; server is never source of truth |
| Gate-resolution / red-flag escalation logic (HEALTH-06) | Client (pure Swift module) | — | Must run entirely on-device since the app must function offline immediately after screening; no live AI/server call permitted per HEALTH-01's fixed-choice constraint |
| Calibration session measurement (GPS/motion) | Client (CoreMotion / CoreLocation frameworks) | — | Native OS sensor frameworks, no third-party dependency |
| Band-motif header rendering | Client (SwiftUI custom `Shape`) | — | Pure rendering concern, no data dependency |
| Parental consent email send + link verification | Server (minimal backend) | Client (Universal Link receiver) | The parent's browser/email client is not running the iOS app — a server must generate the token, send the email, and validate the click *before* handing control back to the app via Universal Link. This is the one capability in this phase that cannot be client-only. |
| Consent state persistence (pending/confirmed) | Server (source of truth during the wait) + Client (SwiftData mirror) | — | The server is authoritative for "has the parent clicked yet" since the click happens outside the app; the client polls/receives the confirmation and mirrors it locally once known |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | Ships with iOS 17+ SDK (part of Xcode 16+/current) | Local-first persistence: screening answers, condition tags, calibration baseline, dietary pattern | `[CITED: WebSearch cross-referenced against Apple's SwiftData framework positioning]` Apple's own recommended default for new SwiftUI apps targeting iOS 17+ — type-safe `@Model` macros, native `@Query` integration with SwiftUI, no `.xcdatamodeld`/`NSManagedObject` boilerplate. Built on Core Data internally so has comparable base performance; Core Data itself is not recommended here since it exists only to support pre-iOS-17 targets or advanced migration control this project doesn't need. |
| SwiftUI `NavigationStack` | Ships with iOS 16+ SDK | Multi-step onboarding wizard navigation | `[CITED]` The current (post-`NavigationView`) idiomatic SwiftUI navigation container; supports the conditional/branching step sequence HEALTH-01 requires via `navigationDestination(for:)`. |
| CoreMotion (`CMPedometer`) | Ships with iOS SDK | Walk calibration: step count, distance, pace — without requiring location permission | `[CITED: developer.apple.com/documentation/coremotion/cmpedometer, fetched this session]` Requires only `NSMotionUsageDescription`, not `NSLocationWhenInUseUsageDescription`/CoreLocation authorization. This directly satisfies D-02's "no blocking GPS permission prompt required to proceed" — CMPedometer *is* the no-prompt-required path, not a location fallback bolted on separately. |
| CoreLocation | Ships with iOS SDK | Optional GPS enrichment (pace/distance precision) when the user does grant location access, per D-02 | `[ASSUMED]` Standard framework for GPS tracking; exact integration with CMPedometer's motion-only baseline is an implementation detail for planning, not fully specified here — flag as an area the plan should make an explicit call on (does GPS *replace* or *supplement* CMPedometer's reading when granted?). |
| Swift Testing | Ships with Xcode 16+ | Unit tests for gate-resolution logic (HEALTH-06), consent-tier routing (MINOR-01), calibration threshold logic | `[CITED: WebSearch, Apple WWDC 2024 framework]` Apple's current recommendation for all new unit/business-logic tests as of 2026; XCTest remains only for `XCUITest` UI automation and `XCTMetric` performance tests, neither of which this phase's safety-critical logic needs. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Universal Links (`apple-app-site-association`) | N/A — platform capability, not a package | Confirming the parent's email-link click routes back into the app | Required for MINOR-01's consent flow; a custom URL scheme is the fallback only if Universal Link domain verification proves infeasible pre-launch (see Common Pitfalls) |
| `.activityBackgroundTint` / Dynamic Type environment APIs | Ships with SDK | Reading `dynamicTypeSize` to drop the band-motif header at AX1-AX5 | Used directly by the custom `Shape` host view, per UI-SPEC's reflow rule |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | Core Data | Only justified if iOS 15/16 support or 10K+-record batch operations were needed — neither applies; iPhone-only v1 targeting current iOS floors makes SwiftData strictly less code for equivalent capability |
| SwiftData | Realm / GRDB.swift (third-party) | UI-SPEC already locks "no third-party Swift package targeted for Phase 1" for the iOS target — out of scope regardless of technical merit |
| `CMPedometer` for walk detection | `CoreLocation` GPS-only distance/duration | GPS-only would force the location permission prompt into the critical path, directly violating D-02's "no blocking GPS permission prompt required to proceed" |
| Custom email-verification backend | Firebase Auth / Supabase Auth email-link sign-in, repurposed | Auth systems are built for creating an authenticated *user* session, not verifying a third party (the parent) who never becomes an app user themselves; repurposing risks modeling the parent as an "account" that then needs its own privacy/data handling — cleaner to model consent as its own record, not an auth identity. Supabase's underlying *infrastructure* (Postgres + Edge Functions + Resend integration) is still a reasonable backend choice — just not its Auth product specifically. |

**Installation:**
No package manager installation is required for the iOS app target in Phase 1 — every iOS-side
dependency listed above ships with the Apple SDK. A separate, small backend service (for the
parental-consent email flow) will need its own dependency install; see Package Legitimacy Audit
below for the two candidate packages evaluated for that service.

**Version verification:** SwiftData, `NavigationStack`, CoreMotion, and Swift Testing are all
Apple first-party frameworks tied to the OS/Xcode SDK version rather than an independently
versioned package — there is no `npm view`/`pip index versions`-equivalent registry check
applicable. Confirm the actual Xcode/iOS SDK version being targeted during Wave 0 project setup
(recommend targeting the current Xcode 16+/iOS 17+ toolchain, consistent with SwiftData's minimum
deployment target).

## Package Legitimacy Audit

Only the separate parental-consent backend service (not the iOS app target) has candidate external
packages in Phase 1's scope — per `01-UI-SPEC.md`, the iOS target itself uses "SwiftUI native
controls only... no third-party Swift UI package targeted for Phase 1." The table below covers the
backend-service candidates surfaced by research; both packages carry an automated `SUS` verdict
from the legitimacy-check seam, but the underlying signal in both cases is a **false-positive
pattern worth recording** so a human verifier doesn't waste time re-deriving it: the seam's
`publishedAt` field reflects the *most recent version's* release date, not the package's creation
date, and both packages show extremely high weekly download counts against a GitHub org matching
the vendor's own official name.

| Package | Registry | Age (per npm, `publishedAt` = latest version, not creation) | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `resend` | npm | Latest version published 2026-08-21 (package itself is long-established; this is a routine version bump, not a new package) | ~9.96M/week | `github.com/resend/resend-node` (matches official Resend vendor) | `[SUS]` — "too-new" signal, false positive per above | Flagged per protocol — planner must add `checkpoint:human-verify` before this is installed in the backend service, but note the recorded reasoning above so verification is fast, not a blind re-check |
| `@supabase/supabase-js` | npm | Latest version published 2026-08-11 (same false-positive pattern) | ~24.7M/week | `github.com/supabase/supabase-js` (matches official Supabase org) | `[SUS]` — "too-new" signal, false positive per above | Flagged per protocol — planner must add `checkpoint:human-verify` before this is installed in the backend service |

**Packages removed due to `[SLOP]` verdict:** none.
**Packages flagged as suspicious `[SUS]`:** `resend`, `@supabase/supabase-js` — both false positives per the recorded reasoning above (recent version publish mistaken for package age); planner still gates each behind `checkpoint:human-verify` per protocol, since the audit gate does not permit self-override of a `SUS` verdict during research.

*Both packages were discovered via WebSearch, not an authoritative source (official docs/Context7),
so per the Package Name Provenance Rule they remain `[ASSUMED]` regardless of the registry check
passing — the planner's human-verify checkpoint should also confirm these are in fact the intended
official packages, not a similarly-named alternative.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  iOS App (SwiftUI, on-device, works fully offline after screening)  │
│                                                                       │
│  Welcome ──▶ Explanation Register ──▶ Age (Q0) ──▶ [consent check]   │
│                                                          │            │
│         ┌────────────────────────────────────────────────┘          │
│         ▼                                                            │
│   Under 13?  ──Yes──▶ Consent-required screen ──▶ [halt: see below]  │
│         │No                                                          │
│         ▼                                                            │
│   Dietary Pattern (Q0b) ──▶ Privacy Explainer ──▶ Calibration        │
│         │                                            (walk/lift/     │
│         │                                             skip)          │
│         ▼                                                            │
│   13-17? ──Yes──▶ [partial gate: track/Momentum unlocked now,        │
│         │           screening waits on parent] ──▶ (parent approves  │
│         │No                                          later, async)   │
│         ▼                                                            │
│   Gate section (G1-G7) ──▶ [clearance interstitial if any Yes]       │
│         │                                                            │
│         ▼                                                            │
│   Condition checklist ──▶ Severity follow-ups (per selected cat.)    │
│         │                        │                                   │
│         │                        └─▶ SCOFF (only if ED box checked)  │
│         ▼                                                            │
│   Gate-resolution module (pure Swift, offline) ─▶ condition tags     │
│         │                     + clearance state, HEALTH-06 applied   │
│         ▼                                                            │
│   SwiftData write (baseline, tags, register, dietary pattern) ──▶    │
│         App usable — Home screen                                     │
│                                                                       │
│  ── separate async branch, under-13 or 13-17 screening gate only ──  │
│  Parent email entry ──▶ [Universal Link deep-link target] ◀────┐     │
└──────────────────────────────────────────────────────────────┬┼─────┘
                                                                  ││
┌─────────────────────────────────────────────────────────────┐ ││
│  Minimal Backend Service (server, source-of-truth during wait)│ ││
│                                                                 │ ││
│  Receive parent email ──▶ generate signed token ──▶ send email │ ││
│  (Resend/Postmark API) with confirmation link ─────────────────┘ ││
│         │                                                        ││
│         ▼ (parent clicks, outside the app)                       ││
│  Validate token ──▶ mark consent record confirmed ──▶            ││
│  [MVP "plus" factor: send delayed 2nd confirmation email,        ││
│   wait for 2nd click before marking fully confirmed] ─────────────┘│
│         │                                                          │
│         ▼                                                          │
│  Universal Link opens app directly to "consent confirmed" state ──▶│
└──────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
RithamApp/
├── App/
│   ├── RithamApp.swift              # @main, SwiftData ModelContainer setup
│   └── UniversalLinkHandler.swift   # .onOpenURL for parent-consent confirm links
├── Onboarding/
│   ├── OnboardingFlowState.swift    # @Observable, holds in-progress answers + navigation path
│   ├── Steps/                       # one View per wizard step (Welcome, Register, Age, Diet, ...)
│   └── Navigation/                  # NavigationPath / step-enum + navigationDestination wiring
├── Screening/
│   ├── GateResolution/              # PURE Swift module, no SwiftUI/SwiftData import —
│   │                                 #   HEALTH-06 escalation logic lives here, unit-testable
│   │                                 #   in isolation (see Validation Architecture)
│   ├── Models/                      # ConditionTag, ClearanceGate enum, SCOFFResult, etc.
│   └── Views/                       # Gate section, checklist, SCOFF, interstitials
├── Calibration/
│   ├── PedometerSession.swift       # CMPedometer wrapper for walk calibration
│   ├── StopwatchSession.swift       # manual fallback per D-02
│   └── Views/
├── Consent/
│   ├── ConsentState.swift           # state machine: pending → email_sent → link_clicked → confirmed
│   └── Views/                       # under-13 halt, 13-17 partial-gate notice
├── Persistence/
│   └── SwiftDataModels/             # @Model types: UserProfile, ConditionTagRecord (expiresAt),
│                                     #   CalibrationBaseline, DietaryPattern
├── DesignSystem/
│   ├── RithamColor.swift            # per UI-SPEC's theme-object requirement
│   └── BandMotif.swift              # custom Shape, path(in:) recomputes geometry from rect
└── Tests/
    └── GateResolutionTests/         # Swift Testing, exercises HEALTH-06's 16 escalation rules
```

### Pattern 1: Wizard flow via `NavigationStack` + shared `@Observable` flow-state

**What:** A single `NavigationStack` bound to a navigation path, pushing one View per step via
`navigationDestination(for:)`; all in-progress answers live in one `@Observable` object shared
down the hierarchy (via `@Environment` or direct injection), not scattered across per-step
`@State`.

**When to use:** Any multi-step flow with conditional branching — exactly HEALTH-01's requirement
that SCOFF only appears if the eating-disorder checkbox was checked, that severity follow-ups only
appear for selected condition categories, and that the 18+/13-17/under-13 tiers push different next
steps from the same Age screen without ever forking into a separate view hierarchy (CROSSGEN-05).

**Example:**
```swift
// Source: WebSearch, cross-referenced against current SwiftUI NavigationStack patterns
@Observable
final class OnboardingFlowState {
    var register: ExplanationRegister?
    var age: Int?
    var dietaryPattern: DietaryPattern?
    var consentTier: ConsentTier?          // computed from age once known
    var conditionTags: Set<ConditionTag> = []
    var scoffAnswers: SCOFFResponses?
    // ...

    /// Computes the next step given current answers — the single source of truth
    /// for branching, so no View makes its own routing decision.
    func nextStep(after current: OnboardingStep) -> OnboardingStep? { ... }
}

struct OnboardingRootView: View {
    @State private var flow = OnboardingFlowState()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStepView()
                .navigationDestination(for: OnboardingStep.self) { step in
                    step.view(flow: flow)
                }
        }
        .environment(flow)
    }
}
```

### Pattern 2: Custom `Shape` recomputing geometry from its own `rect`

**What:** `Shape.path(in rect: CGRect) -> Path` receives the actual rect it will render into at
call time — this rect *is* the runtime dimension information; no separate `GeometryReader` is
needed inside the shape itself to know the header's real width/height.

**When to use:** The band-motif header, per UI-SPEC's requirement to recompute flat-margin
percentages for the actual portrait render target rather than porting sketch-003's 1440×720
polygon coordinates verbatim.

**Example:**
```swift
// Source: WebSearch, cross-referenced against SwiftUI Shape protocol documentation
struct BandMotif: Shape {
    let angleDegrees: Double = 57 // fixed, matches sketch 003

    func path(in rect: CGRect) -> Path {
        // rect.width / rect.height ARE this call's real dimensions —
        // recompute left/right flat-margin fractions for THIS aspect ratio,
        // do not reuse sketch 003's 1440×720-solved ~25%/~20% figures.
        var path = Path()
        // ... edge-crossing computation per sketch 003's README "Geometry note",
        // re-derived against rect.width/rect.height, verified computationally.
        return path
    }
}

// Host view: drop the header entirely at accessibility sizes, per UI-SPEC's reflow rule
struct ScreenHeader: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !typeSize.isAccessibilitySize {
            BandMotif()
                .fill(RithamColor.hot)
                .frame(height: 250) // within UI-SPEC's 220-280pt recommendation
        }
        // else: header compresses out of layout entirely, content reflows onto flat charcoal
    }
}
```

### Pattern 3: Calibration walk via `CMPedometer`, no location prompt required

**What:** `CMPedometer.startUpdates(from:withHandler:)` streams live step count, distance, and pace
using only `NSMotionUsageDescription` — no `CoreLocation` authorization needed for the baseline
walk-completion determination (10+ continuous minutes per D-01).

**When to use:** As the default/no-permission-prompt-required path for ONBOARD-01's walk
calibration; GPS (CoreLocation) is layered in only when the user has already granted location
access, per D-02, as an enrichment (route/pace precision) rather than the gate for "did the walk
happen."

**Example:**
```swift
// Source: WebSearch cross-referenced against developer.apple.com/documentation/coremotion/cmpedometer
import CoreMotion

final class PedometerSession {
    private let pedometer = CMPedometer()

    func start(onUpdate: @escaping (CMPedometerData) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            // Device has no pedometer hardware — fall back to manual stopwatch per D-02
            return
        }
        pedometer.startUpdates(from: Date(), withHandler: { data, error in
            guard let data else { return }
            onUpdate(data) // caller determines "10+ continuous minutes" completion
        })
    }

    func stop() { pedometer.stopUpdates() }
}
```

### Anti-Patterns to Avoid

- **Per-step local `@State` for wizard answers:** loses answers on back-navigation and makes
  cross-step branching logic (e.g., "was the ED checkbox checked earlier") awkward to query. Use
  one shared flow-state object instead.
- **Porting sketch-003's SVG polygon coordinates directly into a SwiftUI `Path`:** UI-SPEC
  explicitly documents this as a real, verified bug (the portrait-crop problem) — coordinates were
  solved for a 1440×720 canvas and do not transfer to a ~390×844 portrait viewport. Always
  recompute from `rect` inside `path(in:)`.
- **Using `CoreLocation` as the primary gate for walk-completion:** would reintroduce the blocking
  GPS permission prompt D-02 explicitly forbids. GPS is enrichment, not the completion gate.
- **A boolean `consentConfirmed` field on the user record:** forecloses Phase 5's ability to swap
  in a stronger COPPA method without a data migration. Use a state-machine enum instead (see
  Conflict 2).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local persistence with expiring records | A custom file-based store or raw `UserDefaults` for condition tags/calibration data | SwiftData `@Model` with a computed `isExpired` check against a stored `expiresAt` date | SwiftData handles schema, migrations (within its supported scope), and SwiftUI `@Query` reactivity for free; hand-rolling risks silent data-loss bugs on schema changes |
| Step/distance measurement for the walk calibration | Manual accelerometer processing | `CMPedometer` | Apple's CoreMotion stack already does sensor fusion, low-power background processing, and device-capability detection (`isStepCountingAvailable()`) — reimplementing this is significant, unnecessary engineering risk for a v1 |
| Secure token generation for the parent-consent link | A custom random-string generator | Server-side cryptographically-secure token generation (standard library `crypto.randomBytes` equivalent on whatever backend runtime is chosen) | Consent-link tokens are a real security surface (guessable tokens = an attacker can approve their own under-13 account) — use vetted crypto primitives, never a homebrew RNG |
| Universal Link domain verification | Manually crafting `apple-app-site-association` and hoping | Apple's documented AASA setup + `swcutil` / Associated Domains capability in Xcode, tested per Apple's own QA1916 email-yourself-the-link method | This is a well-documented, narrow surface where deviating from Apple's exact JSON format silently breaks the whole flow |

**Key insight:** Almost everything client-side in this phase has a first-party Apple framework
that does the job correctly — the temptation to hand-roll is highest on the backend half (consent
token/email flow), which is exactly the half with the most real security and compliance exposure.

## Common Pitfalls

### Pitfall 1: Slice-cropping sketch-003's coordinates for the band motif (already flagged in UI-SPEC, restated here for planner visibility)

**What goes wrong:** The 1440×720 landscape SVG's polygon points, if copied into a SwiftUI `Path`
verbatim and scaled/cropped to a ~390×844 portrait screen, discard both flat margins and produce a
screen that's mostly diagonal band with no room for text.
**Why it happens:** `xMidYMid slice`-style cropping keeps the *middle* of a wide composition; a
tall narrow viewport crops away exactly the flat regions that made the original composition work.
**How to avoid:** Bound the motif to a fixed-height header region and recompute the flat-margin
fractions from that header's own aspect ratio inside `path(in:)`, per Pattern 2 above.
**Warning signs:** Any hardcoded numeric coordinate in the `Shape` implementation that traces back
to sketch-003's SVG file rather than being derived from `rect.width`/`rect.height` at call time.

### Pitfall 2: Treating email-plus as a single click (Conflict 2, restated as an implementation pitfall)

**What goes wrong:** Shipping D-05 exactly as written risks building a consent flow that doesn't
meet the FTC's own definition of the method it's implicitly claiming to use, discovered only at
Phase 5's LAUNCH-05 compliance review — after the data model and UX are already built around
`pending → confirmed` in one hop.
**Why it happens:** "Email verification link" sounds self-evidently sufficient; the FTC's specific
"plus" requirement is a non-obvious regulatory detail, not a UX assumption.
**How to avoid:** Model consent as a state machine with room for a second confirming step from day
one (see Conflict 2's recommendation), even if the MVP only implements the simplest compliant
variant.
**Warning signs:** A `Bool` field for consent status anywhere in the schema; a data model where
"parent clicked the link" and "consent is legally valid" are treated as the same event.

### Pitfall 3: Universal Link redirect breaking inside transactional email clients

**What goes wrong:** Some email clients rewrite or wrap outbound links with tracking redirects,
which can break `apple-app-site-association` domain verification, causing the link to open in
Safari instead of routing into the app.
**Why it happens:** Universal Links require the *exact* verified domain in the tapped URL; a
tracking-wrapped redirect URL (e.g., `click.provider.com/...`) is a different domain than the
app's registered one.
**How to avoid:** Test the actual confirmation email through whichever transactional email
provider is chosen (Resend/Postmark/SendGrid) on a real device before shipping — per Apple's own
documented QA1916 method (email yourself the link, long-press to confirm "Open in [App]" appears).
**Warning signs:** The confirmation link opens in Safari/Mail's in-app browser instead of directly
launching the app.

### Pitfall 4: CMPedometer availability varies by device/simulator

**What goes wrong:** Not all devices have the hardware coprocessor CMPedometer relies on, and the
iOS Simulator does not produce real motion data at all.
**Why it happens:** CMPedometer depends on the M-series motion coprocessor present in modern
iPhones; testing exclusively in Simulator will never exercise the real code path.
**How to avoid:** Always guard with `CMPedometer.isStepCountingAvailable()` before starting
updates, and plan for on-device testing (or a manual-stopwatch-only test pass) since Simulator
cannot validate this path — flag as a Wave 0/testing consideration, not just a runtime guard.
**Warning signs:** Calibration walk logic that was only ever exercised in Simulator.

## Code Examples

See Architecture Patterns above for the three load-bearing patterns (wizard state, custom `Shape`,
`CMPedometer` session) with inline source annotations.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Core Data as the default SwiftUI persistence choice | SwiftData as Apple's recommended default for new iOS 17+ apps | SwiftData introduced WWDC23, matured through 2024-2026 | Less boilerplate, native `@Query`/SwiftUI integration; Core Data now positioned as the legacy/advanced-migration choice, not the default |
| XCTest for all new tests | Swift Testing for new unit/business-logic tests; XCTest retained only for `XCUITest`/`XCTMetric` | Introduced WWDC24, ships with Xcode 16+ | Cleaner `#expect`-based syntax, parallel-by-default test execution — directly relevant to this phase's safety-critical gate-resolution logic |
| `NavigationView` | `NavigationStack` | iOS 16 (2022) | `NavigationView` is deprecated; any wizard-flow guidance referencing it is stale |
| COPPA's pre-2025 consent methods | Amended COPPA Rule (published April 2025, compliance required April 22, 2026 — now in force) adds "text plus," facial-recognition-to-ID matching, and other methods alongside the retained "email plus" | April 22, 2026 compliance deadline | The consent-method landscape D-05/MINOR-01/02/LAUNCH-05 must be evaluated against is the *current* amended rule, not a pre-2025 understanding of COPPA — this research confirms email-plus survives the amendment largely unchanged, so the Conflict 2 finding is not based on stale rule text |

**Deprecated/outdated:**
- `NSFileProtectionNone`/no explicit file protection class for health-adjacent SwiftData stores:
  should not be the default for condition tags/SCOFF-derived data given LAUNCH-04's GDPR/CCPA
  review scope names this data explicitly as sensitive.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CoreLocation is layered in as GPS *enrichment* on top of a CMPedometer-driven baseline, not as a replacement gate, when the user grants location access | Standard Stack, Pattern 3 | If the plan instead makes GPS the primary completion gate, D-02's "no blocking permission prompt" requirement is violated; low risk since this is a straightforward reading of D-02, but the exact GPS/motion integration wasn't independently verified against a working code sample this session |
| A2 | Supabase + Resend (or an equivalent minimal serverless-function + transactional-email-API stack) is an appropriate backend for the parent-consent flow | Standard Stack, Package Legitimacy Audit | LOW confidence per the `research-store` tag on this finding — it's a reasonable, well-precedented pattern but was not validated against Ritham's actual (not-yet-chosen) backend infrastructure; if the team has an existing backend preference this recommendation should defer to it |
| A3 | A "service provider" relationship with a third-party email API (Resend/Postmark/etc.) does not itself trigger email-plus's "no third-party disclosure" limitation | Conflicts block, Conflict 2 | This is explicitly flagged as an open legal question, not asserted as fact — if wrong, it could mean email-plus is unavailable to Ritham entirely regardless of the "plus" factor added, forcing a stronger (and costlier) consent method |
| A4 | The delayed-second-confirmation-email pattern is an FTC-recognized implementation of the "plus" factor (not just a plausible-sounding invention) | Conflicts block, Conflict 2 | Cross-referenced across 2+ independent WebSearch sources describing this exact pattern, but never confirmed against FTC/eCFR primary text directly (both fetches returned HTTP 403 this session) — moderate confidence, worth a direct primary-source check before Phase 5 counsel review, not before Phase 1 planning |
| A5 | Xcode 16+/iOS 17+ is the intended minimum deployment target | Standard Stack, Version Verification | REQUIREMENTS.md/PROJECT.md specify "native iOS, Swift/SwiftUI" but do not state a minimum OS version explicitly; SwiftData itself requires iOS 17+, so this assumption is load-bearing for the persistence recommendation — if a lower floor is actually required, Core Data becomes the correct choice instead |

**If this table is empty:** N/A — see entries above; all five need at least a light confirmation
pass, A3/A4 specifically before Phase 5, A1/A2/A5 before or during Phase 1 planning.

## Open Questions

1. **Does using a third-party transactional email vendor (Resend/Postmark/etc.) for the parent
   consent email count as "disclosure to a third party" under email-plus's internal-use-only
   limitation?**
   - What we know: Service-provider relationships under a data-processing agreement are commonly
     treated differently from true third-party disclosure in privacy law generally, but this is a
     COPPA-specific determination this research did not confirm.
   - What's unclear: Whether FTC guidance draws that same distinction for COPPA's email-plus method
     specifically.
   - Recommendation: Flag for LAUNCH-05's counsel review; do not let this block Phase 1
     implementation (the technical architecture — state machine, not boolean — is correct either
     way), but don't let the planner or executor present the backend choice as legally settled.

2. **Does the "plus" factor need to be added to D-05 now, or can Phase 1 ship the single-click
   version with the state-machine data model in place, deferring the actual second-confirmation
   step to a fast-follow before Phase 5's compliance gate?**
   - What we know: LAUNCH-05 gates public App Store submission, not Phase 1 completion — Phase 1
     can technically ship without full COPPA compliance if the roadmap's sequencing intends
     Phase 5 to close this gap.
   - What's unclear: Whether "fully locked" for under-13 (D-06) combined with a non-compliant
     consent mechanism creates any interim risk (e.g., if the app is in TestFlight/beta with real
     under-13 users before Phase 5 lands).
   - Recommendation: Route this back to the user/planner explicitly — this is a product-sequencing
     decision (build the state machine now vs. build the full "plus" step now), not something
     research can resolve unilaterally.

3. **What exact GPS/CMPedometer integration does the walk calibration need — does granted location
   access change what "10+ continuous minutes" means (e.g., a GPS-verified distance replacing a
   motion-only step count as the source of truth), or is it purely additive precision?**
   - What we know: D-02 requires the manual-stopwatch and (per this research) CMPedometer-only
     paths to work fully standalone without a location prompt.
   - What's unclear: The product intent for what changes, if anything, when a user *does* grant
     location — this wasn't discussed in CONTEXT.md and isn't specified in docs/health-screening.md
     (which doesn't cover calibration mechanics at all, only the screening questionnaire).
   - Recommendation: Claude's Discretion during planning — a reasonable default is "GPS enriches
     the displayed pace/distance once the session is already motion-confirmed as 10+ continuous
     minutes," treating CMPedometer as the single source of truth for completion regardless of
     location permission state.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / iOS SDK | Entire phase (greenfield project has no `.xcodeproj` yet) | ✗ (not verified this session — no Xcode project exists in this repo yet) | — | Wave 0 must create the Xcode project targeting the intended iOS floor (recommend 17+, see A5) before any other Phase 1 work begins |
| A domain for Universal Links / `apple-app-site-association` hosting | MINOR-01's parent-consent confirm-in-app step | ✗ (no backend/domain infrastructure exists yet per this research) | — | No viable client-only fallback — a custom URL scheme is a degraded fallback (confirmation-prompt UX, less trustworthy in email clients) if Universal Link domain setup can't land in time, but this blocks a locked requirement (MINOR-01) so should be resolved, not silently descoped |
| Backend service for parent-consent email (Supabase, or Cloudflare Workers/Lambda + Resend/Postmark) | MINOR-01/MINOR-02 | ✗ (no backend chosen or provisioned yet) | — | No fallback exists for this capability — it is genuinely required infrastructure, not an optional enhancement; must be selected and stood up as part of this phase's plan, not deferred |

**Missing dependencies with no fallback:**
- Universal Links domain + `apple-app-site-association` hosting, and the backend service itself —
  both are hard requirements for MINOR-01's under-13 gate to function at all. The plan must include
  provisioning these, not assume they pre-exist.

**Missing dependencies with fallback:**
- Xcode project scaffold — trivially created in Wave 0, not a blocking external dependency, just
  not yet done.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16+) for unit/business-logic tests; `XCUITest` (via XCTest) reserved for any UI-flow smoke tests this phase's wizard might warrant |
| Config file | none — greenfield project, Wave 0 must scaffold the test target alongside the app target |
| Quick run command | `xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RithamTests/GateResolutionTests` (adjust scheme/target names once Wave 0 names them) |
| Full suite command | `xcodebuild test -scheme Ritham -destination 'platform=iOS Simulator,name=iPhone 15'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HEALTH-06 | "Not sure" always resolves to the more cautious branch (16 documented escalation rules in docs/health-screening.md §5) | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testNotSureResolvesCautious` | ❌ Wave 0 |
| HEALTH-06 | 2+ red-flag tags → single most restrictive gate wins, never averaged | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testMultiTagMostRestrictiveWins` | ❌ Wave 0 |
| HEALTH-01 | SCOFF fires only when ED checkbox is checked; score ≥2 → positive screen | unit | `xcodebuild test ... -only-testing:RithamTests/GateResolutionTests/testSCOFFTrigger` | ❌ Wave 0 |
| MINOR-01 | Age routes correctly to under-13 / 13-17 / 18+ tiers | unit | `xcodebuild test ... -only-testing:RithamTests/ConsentTierTests` | ❌ Wave 0 |
| HEALTH-02 | Condition tag `isExpired` computes correctly at 12-month boundary | unit | `xcodebuild test ... -only-testing:RithamTests/ConditionTagExpiryTests` | ❌ Wave 0 |
| ONBOARD-01 | Calibration bar (walk 10+min, lift — pending Conflict 1 resolution) correctly determines session completion | unit | `xcodebuild test ... -only-testing:RithamTests/CalibrationThresholdTests` | ❌ Wave 0 |
| CROSSGEN-05 | No age value ever routes to a structurally distinct view hierarchy (only content/step differs) | unit (routing logic, not full UI test) | `xcodebuild test ... -only-testing:RithamTests/OnboardingFlowStateTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted `-only-testing:` run for the module just touched
- **Per wave merge:** full `GateResolutionTests` + `ConsentTierTests` suite (the safety-critical
  core)
- **Phase gate:** full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `RithamTests/GateResolutionTests.swift` — covers HEALTH-01, HEALTH-06 (recommend building the
  gate-resolution logic as a pure Swift module per the project structure above, so these tests need
  no SwiftUI/SwiftData host and can run fast/in-parallel)
- [ ] `RithamTests/ConsentTierTests.swift` — covers MINOR-01
- [ ] `RithamTests/ConditionTagExpiryTests.swift` — covers HEALTH-02
- [ ] `RithamTests/CalibrationThresholdTests.swift` — covers ONBOARD-01 (blocked on Conflict 1
  resolution — the exact threshold to test against isn't settled yet)
- [ ] Xcode project + test target scaffold itself — none exists yet, this is Wave 0's first task
- [ ] `RithamTests/OnboardingFlowStateTests.swift` — covers CROSSGEN-05's no-fork guarantee at the
  routing-logic level

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Partial — no user login exists in Phase 1 (local-first, no account system yet), but the parent-consent link IS a bearer-token-style authentication event for a non-user (the parent) | Server-side cryptographically-secure, single-use, time-limited tokens for the consent link (see Don't Hand-Roll) |
| V3 Session Management | No | No session/login concept in this phase |
| V4 Access Control | Yes | The under-13 full-lock (D-06) and 13-17 partial-gate (MINOR-01) are access-control states that must be enforced consistently — recommend gating at the data-query layer (e.g., a computed `canAccessScreening` check consulted everywhere screening data is read/written), not just at the UI navigation layer, so a bug in one screen's navigation logic can't bypass the gate |
| V5 Input Validation | Yes | Age input bounded 1-120 (already specified in UI-SPEC copy); fixed-choice questionnaire has no free-text injection surface by design (HEALTH-01) |
| V6 Cryptography | Yes | Consent tokens: never hand-roll (see Don't Hand-Roll); SwiftData store: apply an explicit file protection class (see below), never rely on the platform default alone for condition-tag/SCOFF-derived data |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Guessable/brute-forceable parental-consent token | Spoofing | Cryptographically-secure random token generation, sufficient length/entropy, single-use, time-limited expiry, invalidated after use |
| An under-13 or 13-17 account bypassing its gate via a UI navigation bug (e.g., deep-linking past the consent screen) | Elevation of Privilege | Enforce the gate at the data layer (a query-time check on every screening read/write), not only at the navigation-graph level, per V4 above |
| SwiftData store readable by another app or extracted from an unencrypted backup on a jailbroken/compromised device | Information Disclosure | Explicit file protection class (`NSFileProtectionComplete` or at minimum `NSFileProtectionCompleteUntilFirstUserAuthentication`) on the SwiftData store, given condition tags and SCOFF-derived data are named explicitly as sensitive in LAUNCH-04's GDPR/CCPA review scope `[CITED: WebSearch, cross-referenced against Apple's Data Protection documentation]` |
| Raw SCOFF answers (the 5 individual booleans) persisted and later exposed via a data export, debug log, or future feature | Information Disclosure | docs/health-screening.md §1.5 states individual SCOFF answers are "never shown to us as a score or a label" — this research recommends treating that as a storage decision too: consider persisting only the derived tag (`positiveScreen: Bool` or the resulting condition tag), not the 5 raw ED-1..ED-5 booleans, unless a product reason requires keeping them (e.g., allowing edit-in-place). Flagging this for the planner to decide explicitly rather than defaulting silently either way. |
| Universal Link token leaking via email client link-preview/prefetching (some email clients "click" links automatically to generate previews, which could consume a single-use token before the real parent clicks) | Information Disclosure / Denial of Service | A known general email-link pitfall — recommend the token remain valid for a short grace window and support at least one re-send/regenerate action (already Claude's Discretion per CONTEXT.md) so a prefetch-consumed token doesn't permanently strand the parent |

> **Superseded 2026-08-23:** The first, second, and fourth rows above (consent-token guessability,
> gate-bypass-via-navigation for an under-13/13-17 account, and Universal Link token
> prefetch/leakage) are all threat entries for the now-removed parental-consent flow — there is no
> consent token, no consent gate, and no Universal Link left to threat-model. See `01-CONTEXT.md`
> D-14/D-15. The third row (SwiftData file protection on the store) and the SCOFF-answer-persistence
> row are unaffected and still apply.

## Sources

### Primary (HIGH confidence)
- None fetched this session at HIGH confidence — the two candidate primary sources
  (`ftc.gov/business-guidance/...`, `developer.apple.com` via WebFetch) both route through this
  session's WebFetch tool, which the `classify-confidence` seam classifies as LOW even when
  successfully retrieved (see Metadata below for why this matters for the COPPA finding
  specifically).

### Secondary (MEDIUM confidence)
- WebSearch results cross-referenced across 2+ independent sources, per `classify-confidence
  --provider websearch --verified`:
  - SwiftData vs. Core Data recommendation for new iOS 17+ SwiftUI apps
  - Custom `Shape.path(in:)` receiving the real render-time `rect` (no `GeometryReader` needed
    inside the shape)
  - `dynamicTypeSize.isAccessibilitySize` as the AX1-AX5 conditional-drop mechanism
  - Universal Links as the 2026-current pattern for email-to-app confirmation
  - COPPA's amended rule (effective April 22, 2026) retaining "email plus" essentially unchanged,
    cross-referenced across `blog.promise.legal`, Mayer Brown, Securiti, and Taft Privacy summaries
  - `CMPedometer` requiring only `NSMotionUsageDescription`, not `CoreLocation` authorization
  - Swift Testing as Apple's 2026 default recommendation for new unit/business-logic tests

### Tertiary (LOW confidence)
- `developer.apple.com/documentation/coremotion/cmpedometer` (via WebFetch) — content itself is
  from an authoritative source, but the seam scores the WebFetch provider LOW even when verified;
  treat the underlying facts (step/distance/pace/floors, `NSMotionUsageDescription`-only,
  `startUpdates`/`queryPedometerData` split) as trustworthy given the source, but the confidence
  label follows the tool's classification, not an independent judgment call
- Backend/email-vendor recommendation (Supabase + Resend, or equivalent) — single-pass WebSearch,
  not independently cross-checked against Ritham's actual infrastructure preferences (none exist
  yet); flagged as Assumption A2

## Metadata

**Confidence breakdown:**
- Standard stack (SwiftData, NavigationStack, CMPedometer, Swift Testing): MEDIUM — WebSearch
  cross-referenced across multiple sources and, for CMPedometer, directly against Apple's own
  documentation page; no code sample was compiled/run this session to independently verify
- Architecture (wizard pattern, custom Shape, consent state machine): MEDIUM — patterns are
  standard/idiomatic per multiple sources, but this session did not have access to Context7 or an
  Xcode environment to compile-verify any example
- Pitfalls: MEDIUM — Pitfalls 1 and 2 are drawn directly from this project's own documents
  (UI-SPEC's already-verified portrait-crop bug; the COPPA email-plus gap this research
  independently found) rather than generic web research, so confidence in *those two* specifically
  is higher than the MEDIUM label suggests; Pitfalls 3-4 are standard WebSearch-sourced findings
- Conflicts block (D-01, D-05): D-01 is `[VERIFIED]` — a direct textual comparison of two files
  already in this repository, no external research needed. D-05 is MEDIUM per the
  `classify-confidence` seam's `websearch --verified` tier — cross-referenced across independent
  sources but not confirmed against FTC.gov or eCFR primary text directly (both blocked this
  session)

**Research date:** 2026-08-23
**Valid until:** 30 days for the SwiftUI/SwiftData technical findings (stable Apple-framework
guidance); **7 days for the COPPA/email-plus finding specifically** — this sits inside an actively
enforced rule-amendment window (compliance required as of April 22, 2026) and this research
explicitly could not reach FTC.gov or eCFR directly this session; re-verify against primary source
text before Phase 5's LAUNCH-05 review regardless of how much time has passed.

