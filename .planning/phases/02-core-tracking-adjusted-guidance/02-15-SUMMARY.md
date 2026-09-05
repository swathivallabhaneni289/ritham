---
phase: 02-core-tracking-adjusted-guidance
plan: 15
subsystem: ui
tags: [swiftui, swiftdata, strength-training, retroactive-editing]

# Dependency graph
requires:
  - phase: 02-core-tracking-adjusted-guidance
    provides: "LiftSession/MovementPattern/ExerciseCatalog domain model (02-02/02-03), SessionRevision merge/split pure functions (02-03), HealthDataStore lift-session persistence including date-range loads and applyRevision (02-08)"
provides:
  - "Strength history list, most recent first, with a multi-select movement-pattern filter that matches a compound lift under every pattern it trains"
  - "Two distinct empty states: no sessions stored at all vs. a filter matching nothing"
  - "Year-jump / month-jump date navigation limited to periods that actually contain sessions, loading through the store's date-range accessor"
  - "Composable date-range and pattern filters (both narrow the same list together)"
  - "A confirmation-gated session-edit screen (SessionEditView) that mutates existing sets in place, and delegates merge/split entirely to SessionRevision + applyRevision"
affects: [strength-progress, momentum-streak]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Model-level @Observable driver class (StrengthHistoryModel, SessionEditModel) tested directly by Swift Testing suites, never via view rendering -- same discipline as CardioHistoryModel/RouteComparisonModel"
    - "Pending-revision staging: a destructive action (merge/split) sets a `pendingRevision` value and requires a separate confirm call before any store write; abandoning clears it with no write"

key-files:
  created:
    - RithamApp/Ritham/Strength/Views/StrengthHistoryView.swift
    - RithamApp/Ritham/Strength/Views/YearJumpDatePicker.swift
    - RithamApp/Ritham/Strength/Views/SessionEditView.swift
    - RithamApp/RithamTests/StrengthHistoryTests.swift
  modified:
    - RithamApp/Ritham/Strength/StrengthHistoryRegistration.swift

key-decisions:
  - "StrengthHistoryModel.allSessionStartDates is populated only by the full unfiltered load() call (the same load the base list already needs), never by a dedicated 'load everything to compute the year list' call -- satisfies the plan's requirement that no code path loads the whole store purely to derive a month list"
  - "SessionEditView is not wired into StrengthHistoryView as a reachable sheet in this plan -- Task 3's own file list (SessionEditView.swift + StrengthHistoryTests.swift only) deliberately excludes StrengthHistoryView.swift, so the merge/split screen exists and is fully tested at the model level but has no history-row entry point yet"

requirements-completed: [STRENGTH-04, STRENGTH-05]

coverage:
  - id: D1
    description: "Strength history lists past sessions most recent first with date, exercise count, working-set count, and a multi-select movement-pattern filter; a compound lift (thruster: squat+push) is returned by a filter on each pattern it trains independently"
    requirement: STRENGTH-04
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthHistoryTests.swift#StrengthHistoryFilterTests (7 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Two distinct empty states (no sessions at all vs. filter matching nothing) never collapse into one"
    requirement: STRENGTH-04
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthHistoryTests.swift#StrengthHistoryFilterTests.filterMatchingNothingShowsNoResultsState / emptyStoreYieldsEmptyHistoryState"
        status: pass
    human_judgment: false
  - id: D3
    description: "Year-jump date navigation offers only years/months containing stored sessions, loads a selected month through the store's date-range accessor, and composes with the pattern filter"
    requirement: STRENGTH-05
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthHistoryTests.swift#YearJumpNavigationTests (7 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Retroactive session editing preserves set identity; merge produces the exact union of both sessions' sets; split partitions a session's sets exactly; degenerate merge/split attempts are refused with an explanation and write nothing; a merge/split confirmation is required before writing, and abandoning it writes nothing; total stored set count is invariant across a merge and a split"
    requirement: STRENGTH-05
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/StrengthHistoryTests.swift#SessionRevisionScreenTests (9 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "SessionEditView is reachable from a history row as a sheet in the running app"
    verification: []
    human_judgment: true
    rationale: "Not built in this plan -- Task 3's file scope (SessionEditView.swift + StrengthHistoryTests.swift only) deliberately excludes StrengthHistoryView.swift, so no history-row entry point exists yet. Needs a future plan or a follow-up task to wire a sheet presentation from StrengthHistoryView's session rows; flagged in Known Stubs below."

duration: 45min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 15: Strength Training History, Year-Jump Navigation, and Retroactive Editing Summary

**Pattern-filterable strength history with year/month-jump navigation and a confirmation-gated merge/split editing screen, all delegating identity-sensitive revision logic to `SessionRevision` and `HealthDataStore.applyRevision`**

## Performance

- **Duration:** ~45 min (this continuation run; Task 1 was built and committed in a prior, separately-timed session)
- **Completed:** 2026-09-06T01:02Z
- **Tasks:** 3 (Task 1 completed and committed in a prior run; Tasks 2-3 completed in this run)
- **Files modified:** 5 (`StrengthHistoryView.swift`, `YearJumpDatePicker.swift` [new], `SessionEditView.swift` [new], `StrengthHistoryTests.swift`, `StrengthHistoryRegistration.swift` [Task 1])

## Note on Task 1

A prior executor run built and committed Task 1 (`af69114`) but stalled before starting Task 2. Per the continuation objective, Task 1's work was **not redone** -- only sanity-checked (commit exists, `StrengthHistoryFilterTests` still passes at 7/7 alongside the new suites, `git show af69114` confirms the delivered files match the plan's Task 1 scope). This SUMMARY covers all three tasks for completeness.

## Accomplishments

- **Task 1** (prior session, `af69114`): `StrengthHistoryView` + `StrengthHistoryModel` -- sessions most recent first with date, exercise count, working-set count, and movement-pattern labels; multi-select pattern filter tests `LiftSession.movementPatterns`' precomputed union (never a per-exercise lookup); two distinct empty states; `StrengthHistoryRegistration.swift` rewritten in place to register the real screen.
- **Task 2** (`555bc3a`): `YearJumpDatePicker` offers a year list, then a month list within the selected year, both derived from `StrengthHistoryModel.allSessionStartDates` (populated only by the model's one full-store load) so no period with zero sessions is ever offered. Selecting a month calls `StrengthHistoryModel.loadDateRange(_:)`, which loads through `HealthDataStore.loadLiftSessions(in:)` -- never the full-store accessor. The picker composes with the Task 1 pattern filter: both narrow `sessions` to their intersection.
- **Task 3** (`adb885a`): `SessionEditView` + `SessionEditModel` render a past session's sets with editable weight, reps, warm-up flag, and date. Editing mutates the existing `LiftSet` value's fields in place (never rebuilding it), so `id` survives. Merge and split delegate to `SessionRevision.merge`/`.split` and write only through `HealthDataStore.applyRevision(_:replacing:)`. Both are staged as a `pendingRevision` requiring an explicit confirmation dialog before any write; abandoning clears the pending revision with no store mutation. A `nil` return from either domain function (self-merge, split at the first set or past the last) surfaces as a `refusalMessage` rather than falling through to an empty session.

## Task Commits

Each task was committed atomically:

1. **Task 1: Session history list with movement-pattern filtering** - `af69114` (feat) -- completed in a prior, separately-committed run
2. **Task 2: Year-jump date navigation** - `555bc3a` (feat)
3. **Task 3: Retroactive session editing, merge and split** - `adb885a` (feat)

**Plan metadata:** (this commit) `docs(02-15): complete strength history, year-jump, and revision editing plan`

## Files Created/Modified

- `RithamApp/Ritham/Strength/Views/StrengthHistoryView.swift` - Session list, pattern filter, date-range integration (Tasks 1 & 2)
- `RithamApp/Ritham/Strength/Views/YearJumpDatePicker.swift` - Year/month picker deriving offered periods from stored session dates (Task 2)
- `RithamApp/Ritham/Strength/Views/SessionEditView.swift` - Editable session sets, merge/split with confirmation gating (Task 3)
- `RithamApp/Ritham/Strength/StrengthHistoryRegistration.swift` - Rewritten in place to register the real screen (Task 1)
- `RithamApp/RithamTests/StrengthHistoryTests.swift` - `StrengthHistoryFilterTests` (7), `YearJumpNavigationTests` (7), `SessionRevisionScreenTests` (9) -- 23 tests total
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after each task added new source files

## Decisions Made

- `StrengthHistoryModel.allSessionStartDates` is captured only inside the model's existing `load()` (the unfiltered full-store read the base list already performs) rather than via a second dedicated call -- satisfies the plan's "no code path loads all sessions purely to derive a single month's list" constraint by construction, since that load already serves the unfiltered view.
- `SessionEditView`'s merge/split action buttons only flip `isConfirmingRevision = true` when `model.pendingRevision != nil` after the request call -- a refusal (self-merge, invalid split index) leaves `pendingRevision` nil and shows `refusalMessage` instead, so the confirmation dialog is never presented over nothing.
- Weight editing uses a text-backed `Binding<String>` rather than `TextField(_:value:format:)` against `Binding<Double?>`, since SwiftUI's numeric-format `TextField` overload requires a non-optional `FormatInput` and `Double?` doesn't satisfy it; reps (non-optional `Int`) still uses the numeric-format overload directly.

## Deviations from Plan

None beyond the two implementation choices captured above (both scoped inside Task 2/3's own files, not architectural changes) - plan executed as written for Tasks 2 and 3.

## Known Stubs

- **`SessionEditView` has no reachable entry point from `StrengthHistoryView`.** Task 3's file scope in `02-15-PLAN.md` (`SessionEditView.swift` + `StrengthHistoryTests.swift` only) deliberately excludes `StrengthHistoryView.swift`, so no history row currently presents this screen as a sheet. The screen and its `SessionEditModel` are fully built and tested at the model level (9 tests covering editing, merge, split, both refusal cases, confirmation, and the set-count invariant), and its constructor (`session:`, `mergeCandidates:`, `store:`) is ready for a future call site to present it via `.sheet(item:)` from a history row, matching `CardioHistoryView`'s `RouteComparisonView` precedent. This is a reachability gap, not a correctness gap -- flagged here per this plan's own coverage entry D5 for whichever future plan or follow-up task wires it in.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- STRENGTH-04 and STRENGTH-05 are both functionally complete and unit-tested at the model level; `xcodebuild build` succeeds and all 23 tests across the three suites in `StrengthHistoryTests.swift` pass individually via `-only-testing:`.
- Per this plan's own `<verification>` note, the full `RithamTests` target should still be run via the `-only-testing:` commands rather than a full-target run until plan 02-16 fixes the pre-existing cross-suite `StepRegistry` concurrency race (STATE.md Blockers).
- Before STRENGTH-05 can be called end-to-end complete for interactive UAT, a follow-up (either the next plan or a small addendum) needs to wire `SessionEditView` into `StrengthHistoryView`'s session rows as a `.sheet(item:)`, supplying `mergeCandidates` from the currently displayed history list.

---
*Phase: 02-core-tracking-adjusted-guidance*
*Completed: 2026-09-06*
