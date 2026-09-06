---
phase: 03-momentum-recovery
plan: 10
subsystem: testing
tags: [swift-testing, xcodegen, step-registry, structural-gate, roadmap]

requires:
  - phase: 03-momentum-recovery (03-01 through 03-09)
    provides: every Momentum/Recovery/Movement-Snapshot domain type, SwiftData record, HealthDataStore
      method, step case, registrar, and view this plan's coverage suite closes out
provides:
  - Phase3CoverageTests — proves each of Phase 3's three new steps (.momentum, .sleepCheckIn,
    .movementSnapshot) resolves to its real concrete screen type, not a placeholder
  - The MOMENTUM-06 structural no-sharing gate (noMomentumSurfaceOffersASharingAffordance),
    scanning the whole Momentum/ and MovementSnapshot/ directory tree for share/pasteboard triggers
  - A dated, explained ROADMAP.md annotation recording MOMENTUM-06's scoped household-half deferral
  - A real, runnable 03-VALIDATION.md Per-Task Verification Map with actual plan/task identifiers
    and simulator-portable commands
  - Two consecutive green full-target `xcodebuild test` runs plus a green RithamCore suite and app
    build, closing Phase 3 code-complete
affects: [04-household-home]

tech-stack:
  added: []
  patterns:
    - "Directory-walk source-scan structural gate (FileManager.enumerator + #filePath-relative
      resolution), extending the single-file comment-filtered source-read technique
      RecoveryAdjustmentTests/MomentumViewTests already established, to a whole-feature-directory
      scope with a non-vacuous-pass file-count assertion"

key-files:
  created:
    - RithamApp/RithamTests/Phase3CoverageTests.swift
  modified:
    - .planning/ROADMAP.md
    - .planning/phases/03-momentum-recovery/03-VALIDATION.md
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Chose a directory-walk (FileManager.enumerator relative to #filePath) over a checked-in file-name list for the no-sharing gate, so a future file added to Momentum/ or MovementSnapshot/ is covered automatically with nothing to remember to update; guarded with a non-zero scanned-file-count assertion so the gate cannot pass vacuously if directory resolution ever silently found nothing."
  - "03-VALIDATION.md's Per-Task Verification Map rows now cite every plan/task that materially implements each requirement (e.g. MOMENTUM-01 as '03-01-T2 / 03-03-T1') rather than a single plan, since most Phase 3 requirements were built incrementally across a domain-layer plan and a later reconciliation/persistence/UI plan."
  - "Replaced every hardcoded 'iPhone 17' xcodebuild destination and the nonexistent 'MomentumTests' filter name across all of 03-VALIDATION.md (Test Infrastructure and Sampling Rate sections too, not only the Per-Task table) with RithamCore/Scripts/test-core.sh and Scripts/build-app.sh test, since leaving the same hardcoded-destination mistake elsewhere in the same document the table's own footnote calls out would be self-contradictory."

patterns-established:
  - "Phase-close coverage suite shape (Phase2CoverageTests -> Phase3CoverageTests): a table pairing each phase's new step cases to their real concrete presenter types, nested under StepRegistryTouchingSuites, plus a same-suite structural grep-style gate for the phase's own cross-cutting non-functional requirement."

requirements-completed: [MOMENTUM-05, MOMENTUM-06]

coverage:
  - id: D1
    description: "Each of Phase 3's three new steps (.momentum, .sleepCheckIn, .movementSnapshot) resolves to its real concrete screen type (MomentumView/SleepCheckInView/MovementSnapshotView), not a placeholder, and resolves without trapping; the registry reports zero unregistered steps after bootstrap"
    requirement: "MOMENTUM-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/Phase3CoverageTests.swift#eachPhase3StepResolvesToItsRealScreenType, #noPhase3StepResolvesToAPlaceholderType, #everyPhase3StepResolvesWithoutTrapping, #registryReportsNoUnregisteredSteps"
        status: pass
    human_judgment: false
  - id: D2
    description: "No share, export, copy-link, or invite-to-see affordance (ShareLink/UIActivityViewController/UIPasteboard) exists anywhere in the Momentum or MovementSnapshot feature directories, verified by a non-vacuous directory-wide scan (comment-filtered, asserts >0 files scanned)"
    requirement: "MOMENTUM-06"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/Phase3CoverageTests.swift#noMomentumSurfaceOffersASharingAffordance"
        status: pass
      - kind: other
        ref: "grep -rhE \"ShareLink|UIActivityViewController|UIPasteboard\" RithamApp/Ritham/Momentum/ RithamApp/Ritham/MovementSnapshot/ | grep -v '^\\s*//' | wc -l == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "ROADMAP.md's Phase 3 criterion 5 carries the exact dated (2026-09-06), verbatim annotation recording that only the private-by-default half of MOMENTUM-06 ships this phase, mirroring Phase 2 criterion 6's precedent"
    requirement: "MOMENTUM-06"
    verification:
      - kind: other
        ref: "awk '/^### Phase 3:/,/^### Phase 4:/' .planning/ROADMAP.md | grep -c 'Household half deferred 2026-09-06' == 1; grep -c same string in whole file == 1; git diff --stat .planning/ROADMAP.md shows only additive, scoped lines"
        status: pass
    human_judgment: false
  - id: D4
    description: "The full RithamTests target passes with no -only-testing filter on two consecutive runs (387 tests, 49 suites both times), plus a green RithamCore suite (394 tests, 30 suites) and a green app build"
    requirement: "MOMENTUM-05"
    verification:
      - kind: integration
        ref: "Scripts/build-app.sh test (run 1: 387 tests/49 suites passed in 10.1s; run 2: 387 tests/49 suites passed in 5.9s); RithamCore/Scripts/test-core.sh (394 tests/30 suites passed); Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-06
status: complete
---

# Phase 3 Plan 10: Phase Close-Out Summary

**Phase3CoverageTests proves every Phase 3 step resolves to its real screen and asserts a
directory-wide no-sharing structural gate; ROADMAP.md now carries a dated MOMENTUM-06 deferral
annotation; the full test target is green on two consecutive runs, closing Phase 3 code-complete.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-06T13:27:00Z
- **Completed:** 2026-09-06T13:46:00Z
- **Tasks:** 3 completed (Task 3 required no code changes — verification-only, already green)
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `Phase3CoverageTests` (nested under `StepRegistryTouchingSuites`) asserts each of `.momentum`,
  `.sleepCheckIn`, `.movementSnapshot` resolves to its real concrete presenter type
  (`MomentumView`/`SleepCheckInView`/`MovementSnapshotView`), not a placeholder, and resolves
  without trapping — the direct analogue of plan 02-16's `Phase2CoverageTests`.
- The same suite's `noMomentumSurfaceOffersASharingAffordance` test walks every `.swift` file under
  `RithamApp/Ritham/Momentum/` and `RithamApp/Ritham/MovementSnapshot/` (12 files found) and asserts
  zero non-comment occurrences of `ShareLink`, `UIActivityViewController`, or `UIPasteboard` — the
  structural half of MOMENTUM-06's private-by-default requirement, non-vacuous by construction
  (asserts scanned-file count > 0).
- `ROADMAP.md`'s Phase 3 criterion 5 now carries the exact verbatim, dated
  (`Household half deferred 2026-09-06`) annotation explaining that only the private-by-default
  half of MOMENTUM-06 ships this phase, mirroring Phase 2 criterion 6's own 2026-09-04 precedent.
  The diff is scoped and purely additive (10 lines added, nothing else in the file touched).
- `03-VALIDATION.md`'s Per-Task Verification Map now carries real plan/task identifiers (e.g.
  `03-03-T1 / 03-05-T3` for MOMENTUM-08) instead of `TBD-0N`/`TBD`, real threat references, and
  every hardcoded `iPhone 17` xcodebuild destination and the nonexistent `MomentumTests` filter
  replaced with the repository's own stable, simulator-portable entry points
  (`RithamCore/Scripts/test-core.sh`, `Scripts/build-app.sh test`). Every row is confirmed green
  and the document is signed off.
- The full `RithamTests` target passed with no filter on two consecutive runs (387 tests, 49
  suites, ~10s and ~6s), `RithamCore/Scripts/test-core.sh` passed (394 tests, 30 suites), and
  `Scripts/build-app.sh build` succeeded — Phase 3 closes code-complete.

## Task Commits

1. **Task 1: Phase 3 step-coverage suite and the no-sharing structural gate** - `4a5cda0` (test)
2. **Task 2: ROADMAP annotation for MOMENTUM-06's scoped deferral, and validation-map task IDs** - `9d797f3` (docs)
3. **Task 3: Full-target suite green** - no commit (verification-only; `xcodegen generate` was a
   no-op since Task 1 already regenerated the project, and every suite/build was already green —
   nothing to stage)

**Plan metadata:** (this commit)

## Files Created/Modified

- `RithamApp/RithamTests/Phase3CoverageTests.swift` - New coverage suite: real-screen-type
  assertions for the three Phase 3 steps plus the MOMENTUM-06 no-sharing structural gate
- `.planning/ROADMAP.md` - Phase 3 criterion 5 gains the dated MOMENTUM-06 deferral annotation
- `.planning/phases/03-momentum-recovery/03-VALIDATION.md` - Real task identifiers, real threat
  refs, portable commands throughout, ticked Wave 0 checkboxes, signed-off validation
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` to include
  the new test file

## Full Phase 3 Artifact Inventory

Per this plan's own instruction (Task 3), every artifact this phase produced across all ten plans,
grouped by kind, so no later drift/review pass flags any of them as unacknowledged:

**New domain types (RithamCore):**
- `MomentumWeek`, `MomentumTarget`, `MomentumLedger` (+ `MomentumVisibility`, `MomentumGuardrails`,
  `MomentumMilestone`, comeback-window value types) — 03-01
- `SleepAdjustment` — 03-02
- `MomentumCopy` (single-source copy catalog) — 03-02
- `MomentumReconciliation` (+ `MomentumWeekOutcome` enum) — 03-03

**New SwiftData `@Model` records (RithamApp):**
- `MomentumStateRecord` — 03-04
- Momentum ledger records (milestone award, comeback window) in `MomentumLedgerRecords.swift` — 03-04
- `SleepCheckInRecord` — 03-05
- (`WorkoutPreferenceRecord` gained a `movementSnapshotOptIn` column — 03-09; not a new record)

**New `HealthDataStore` methods:**
- `saveMomentumTarget`/`loadMomentumTarget`/`supportedMomentumTargets` — 03-04
- `saveMomentumLedger`/`loadMomentumLedger` — 03-04
- Recovery Week and injury-freeze persistence methods — 03-04
- Sleep check-in save/load methods — 03-05
- `movementSnapshotDays(in:)` — 03-05
- User-initiated Recovery Week and injury flag action methods — 03-05
- `MomentumSummaryReader.summary(now:)` (standalone reconciliation-on-read driver) — 03-05

**New `OnboardingStep` cases:**
- `.momentum` — 03-06
- `.sleepCheckIn` — 03-08
- `.movementSnapshot` — 03-09

**New SwiftUI views/components:**
- `MomentumProgressBlocks`, `ShieldRow`, `MilestoneBadgeList` — 03-06
- `MomentumView` — 03-06
- `MomentumTargetView` — 03-07
- `SleepCheckInView` — 03-08
- `MovementSnapshotToggleView`, `MovementSnapshotView` — 03-09

**New registrars:**
- `MomentumRegistration`, `Phase3StepRegistration` — 03-06
- `MovementSnapshotRegistration` — 03-09

**New test suites:**
- RithamCore: `MomentumWeekTests`, `MomentumTargetTests`, `MomentumLedgerTests`,
  `SleepAdjustmentTests`, `MomentumCopyTests`, `MomentumReconciliationTests`
- RithamApp: `MomentumSuiteSerialization`, `MomentumStoreTests`, `MovementSnapshotTests`,
  `MomentumSummaryTests`, `MomentumViewTests`, `MomentumTargetPickerTests`,
  `RecoveryAdjustmentTests`, `MovementSnapshotViewTests`, `Phase3CoverageTests` (this plan)

## Decisions Made

- Directory-walk source-scan (not a checked-in file list) for the no-sharing gate, guarded by a
  non-zero-file-count assertion — see key-decisions above.
- Per-requirement Verification Map rows cite every contributing plan/task, not just one, since most
  requirements were built incrementally.
- Fixed the same hardcoded-simulator-destination and nonexistent-filter-name mistake everywhere it
  appeared in 03-VALIDATION.md (Test Infrastructure and Sampling Rate sections), not only inside
  the Per-Task table the plan's action text named directly — leaving it half-fixed in the same
  document would have been self-contradictory given the new footnote calling the mistake out.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the "Test Infrastructure" and "Sampling Rate" sections of 03-VALIDATION.md, not only the Per-Task table**
- **Found during:** Task 2
- **Issue:** The plan's action text named "the two hardcoded example commands" in the Per-Task
  Verification Map as the thing to replace, but the same hardcoded `iPhone 17` xcodebuild
  destination and the nonexistent `MomentumTests` filter name also appeared in the document's
  "Test Infrastructure" and "Sampling Rate" sections above the table.
- **Fix:** Replaced those occurrences too, with the same `RithamCore/Scripts/test-core.sh` /
  `Scripts/build-app.sh test` entry points used in the table.
- **Files modified:** `.planning/phases/03-momentum-recovery/03-VALIDATION.md`
- **Verification:** Re-read the full file; no remaining `iPhone 17` or `MomentumTests` string
  anywhere in the document.
- **Committed in:** `9d797f3` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, in-scope of the same file Task 2 already edits)
**Impact on plan:** Closes a self-contradiction the plan's own new footnote would otherwise have
left standing in the same document. No scope creep — same file, same task.

## Issues Encountered

None. No occurrence of the known pre-existing low-frequency `ModelContainer` flake (`STATE.md`
Blockers/Concerns, `PersistenceTests`/`HealthDataStoreTests`/`EditAnswerFlowTests`) was observed
in either of this plan's two consecutive full-target runs — both green, 387/387 tests passing each
time. That pre-existing, unrelated flake remains open per `STATE.md` and is not this plan's to fix.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 (Momentum & Recovery) is code-complete: all nine feature plans plus this close-out plan
  are committed, the full automated suite is green on two consecutive runs, and MOMENTUM-06's
  partial delivery is a dated, explained roadmap annotation rather than a silent gap.
- Manual-only verifications (Momentum screen framing tone, milestone/shield iconography at
  AX3/AX5) remain correctly deferred to the single end-of-project batched pass per PROJECT.md's
  2026-09-06 decision — not a blocker on Phase 4.
- Phase 4 (Household & Home) can build the opt-in household visibility half of MOMENTUM-06 once
  HOUSEHOLD-01 exists: the Momentum data model already carries a `MomentumVisibility` scope
  property (D-07) with a single v1 case, so no data migration is needed when a `.household` case
  is added.

---
*Phase: 03-momentum-recovery*
*Completed: 2026-09-06*

## Self-Check: PASSED
