---
phase: 4
slug: household-home
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-08
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`/`@Suite`), bundled with the Swift 6 toolchain |
| **Config file** | None — `RithamCore/Package.swift`'s `.testTarget` and `RithamApp/project.yml`'s `RithamTests` target are the only configuration |
| **Quick run command** | `Scripts/build-app.sh test -only-testing:RithamTests/<Suite>` for whichever app-layer suite the current task touches (`HomeHubTests`, `MovementSnapshotViewTests`, `Phase3CoverageTests`, `RecommendationsTests`, or the new diet-section suite) |
| **Full suite command** | `Scripts/build-app.sh test` (resolves an available iPhone simulator UDID dynamically, never a hardcoded model name — per this repo's own precedent, not the plain `xcodebuild`/named-destination commands 04-RESEARCH.md's Validation Architecture section suggests) |
| **Estimated runtime** | ~2-5min (full xcodebuild suite; this phase touches no RithamCore pure-domain files, so `RithamCore/Scripts/test-core.sh` is not expected to change) |

---

## Sampling Rate

- **After every task commit:** `Scripts/build-app.sh test -only-testing:RithamTests/<Suite touched>` — avoid a full-target run mid-phase per the `StepRegistry` cross-suite race precedent (04-RESEARCH.md Runtime State Inventory, xcodegen note)
- **After every plan wave:** Full-target `Scripts/build-app.sh test` (no `-only-testing:` filter)
- **Before `/gsd-verify-work`:** Full-target suite green, matching every prior phase's precedent
- **Max feedback latency:** ~2-5min (full xcodebuild suite; this phase has no fast pure-Swift suite of its own since it touches no RithamCore files)

---

## Per-Task Verification Map

*Populated with real task IDs by the phase's close-out plan once the planner has produced PLAN.md files — matching Phase 3's 03-10 precedent (03-VALIDATION.md was drafted here, then rewritten with real IDs during execution). Requirements this phase must cover, pending real task assignment:*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | CROSSGEN-01 | T-4-01 | Dashboard renders logged-exercise, sleep, workout-plan, and diet-plan sections all visible without navigation (D-01/D-02/D-03/D-04/D-05) | unit | `Scripts/build-app.sh test -only-testing:RithamTests/HomeHubTests` | ❌ needs new tests | ⬜ pending |
| TBD | TBD | TBD | CROSSGEN-01 | T-4-02 | Momentum summary section's no-sharing structural gate still passes after relocation into `Ritham/Momentum/Components/` (04-RESEARCH.md Pitfall 2) | structural/source-scan | `Scripts/build-app.sh test -only-testing:RithamTests/Phase3CoverageTests` | ✅ existing, no edit needed if extraction lands under `Ritham/Momentum/` | ⬜ pending |
| TBD | TBD | TBD | CROSSGEN-01 | T-4-03 | Movement Snapshot entry stays non-adjacent to the Momentum section post-refactor (04-RESEARCH.md Pitfall 1/6) | structural/source-scan | `Scripts/build-app.sh test -only-testing:RithamTests/MovementSnapshotViewTests` | ✅ existing — requires `HomeHubView.swift`'s file path, type name, and `MARK: - D-08's Momentum summary section` comment preserved verbatim | ⬜ pending |
| TBD | TBD | TBD | CROSSGEN-01 | T-4-04 | Every `OnboardingStep` (incl. `.recommendations`, still registered though unreached via `flow.open` from the dashboard) stays registered after the rewrite | structural/registry | `Scripts/build-app.sh test -only-testing:RithamTests/PhaseCoverageTests` | ✅ existing | ⬜ pending |
| TBD | TBD | TBD | CROSSGEN-01 | T-4-05 | Diet-plan dashboard section's writes are DIET-01-isolated: only `persistDiet`/`persistAllergens`, never `GateResolution.resolve`/`saveScreeningResult` (04-CONTEXT.md D-05, narrowed; 04-RESEARCH.md Pitfall 3) | unit, new | new test asserting the dashboard's diet section calls neither `GateResolution` nor `saveScreeningResult` | ❌ Wave 0 — no dedicated diet test suite exists today (`find RithamApp/RithamTests -iname "*Diet*"` returns nothing) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Threat ref T-4-01: a dashboard section silently failing to render (e.g. a read error) collapsing into an indistinguishable empty state — mitigated by each section following `HomeHubView`'s existing WR-03 pattern (explicit `loadFailed` flag, not a silent `try?`).*

*Threat ref T-4-05: silent condition-tag corruption via a stale/empty in-memory `OnboardingFlow.answers.screening` feeding a full screening re-resolve from a screen reached fresh on every app launch — mitigated by scoping the dashboard's diet section to DIET-01-isolated calls only (04-CONTEXT.md D-05 narrowing, 04-RESEARCH.md Pitfall 3/Assumption A1). This is the phase's one safety-relevant behavior and must not regress silently.*

---

## Wave 0 Requirements

- [ ] `RithamApp/RithamTests/DashboardDietSectionTests.swift` (or equivalent) — asserts the new diet dashboard section's isolation from `GateResolution`/screening (T-4-05); no existing diet test suite to extend
- [ ] No new test framework install needed — Swift Testing is already the project standard
- [ ] No RithamCore changes expected this phase (pure SwiftUI/app-layer refactor per 04-RESEARCH.md) — `RithamCore/Scripts/test-core.sh` is a regression check only, not expected to gain new tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dashboard visually reads as "a real dashboard," not a button list (subjective layout/framing judgment) | CROSSGEN-01 (roadmap §4, revised 2026-09-08) | Visual/tone judgment call, not assertable by a unit test | Deferred to the end-of-project batched physical-device/AX3-AX5 pass per PROJECT.md's 2026-09-06 decision — not a phase-4 close-out blocker, matching Phase 1/2/3's own precedent |
| Section-card legibility and spacing at accessibility text sizes (AX3/AX5) | CROSSGEN-01 | Requires on-device/visual rendering judgment | Same batched end-of-project pass as above |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies — pending real task IDs from the planner
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify — pending real task IDs
- [x] Wave 0 covers all MISSING references (T-4-05's diet test suite gap)
- [x] No watch-mode flags
- [x] Feedback latency < 5min (full xcodebuild suite; no faster path exists since this phase touches no RithamCore files)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending — will be finalized during execution (matching Phase 3's 03-10 precedent) once the planner assigns real task/plan/wave identifiers to each row above.
