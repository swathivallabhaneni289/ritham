---
phase: 01-onboarding-safety-intake
plan: 11
subsystem: persistence
tags: [swiftdata, ios, file-protection, health-data, swift-testing]

# Dependency graph
requires:
  - phase: 01-09
    provides: "RithamApp.swift @main entry point (second of its three sequenced owners), OnboardingRootView/StepRegistry app shell"
  - phase: 01-06
    provides: "GateResolution.resolve(answers:ageDerivedTags:) / GateResolutionResult / ConditionTag vocabulary this plan persists"
  - phase: 01-03
    provides: "ConditionTagValidity, TagValidity, ProfessionalClearance — the twelve-month validity rule this plan's models delegate to"
provides:
  - "UserProfile / ConditionTagRecord / CalibrationBaselineRecord — the three @Model classes persisting profile, condition tags, and calibration baseline, with optional-returning computed accessors over raw-value-stored enums"
  - "RithamModelContainer.make(inMemory:)/.shared — the app's ModelContainer, store file protected with .completeUntilFirstUserAuthentication and verified via read-back"
  - "HealthDataStore + UserProfileDraft + HealthDataStoreError — the single facade every screening read/write passes through: loadProfile/updateProfile, saveScreeningResult, activeConditionTags, isReScreenDue, invalidateSection, recordProfessionalClearance/clearancesNeedingReConfirmation, saveCalibrationBaseline/loadCalibrationBaseline"
  - "RithamApp.swift now attaches RithamModelContainer.shared via .modelContainer(_:), additive to 01-09's entry point, header comment's three-owner sequence intact for 01-18"
affects: [01-12, 01-13, 01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftData @Model enum fields stored by String raw value with a computed accessor returning the core type as Optional, never force-unwrapped — a future case rename/removal returns nil instead of trapping"
    - "HealthDataStore.updateProfile's partial-update semantics: a nil field in UserProfileDraft means 'leave unchanged,' not 'clear' — only invalidateSection clears explanationRegister/dietaryPattern back to unanswered"
    - "invalidateSection deletes matching ConditionTagRecords rather than stamping editedAt on them, so an in-progress edit can never silently reset an already-overdue tag's re-screen clock before a re-answer actually lands"
    - "#if targetEnvironment(simulator) as the boundary for a runtime capability the Simulator's host filesystem cannot honor (Data Protection) — log instead of throw there, throw on device where the OS enforces it"

key-files:
  created:
    - RithamApp/Ritham/Persistence/UserProfile.swift
    - RithamApp/Ritham/Persistence/ConditionTagRecord.swift
    - RithamApp/Ritham/Persistence/CalibrationBaselineRecord.swift
    - RithamApp/Ritham/Persistence/RithamModelContainer.swift
    - RithamApp/Ritham/Persistence/HealthDataStore.swift
    - RithamApp/RithamTests/PersistenceTests.swift
    - RithamApp/RithamTests/HealthDataStoreTests.swift
  modified:
    - RithamApp/Ritham/App/RithamApp.swift
    - RithamApp/Ritham.xcodeproj/project.pbxproj

key-decisions:
  - "Only the derived eating-disorder outcome is stored (UserProfile.edScreenOutcomeRaw, holding one of the two eatingDisorder* ConditionTag raw values); the five raw SCOFF answers have no persisted home anywhere in this model layer (T-01-60)"
  - "updateProfile's nil-means-unchanged semantics for explanationRegister/dietaryPattern — filled in an implementation detail the plan left unspecified, checked against 01-13's/01-16's described call sites (a register-only update must not null out an already-set dietary pattern)"
  - "invalidateSection deletes the edited section's ConditionTagRecords instead of stamping editedAt on them (Rule 1 fix during design, before implementation) — stamping would have reset an already-overdue tag's twelve-month window and silently discharged the D-07 re-screen banner the moment an edit began, before the user re-answered anything"
  - "File protection read-back verification throws on-device only, logs on Simulator (#if targetEnvironment(simulator)) — confirmed empirically that the Simulator's host APFS volume does not honor Data Protection classes, so RithamModelContainer.shared's unconditional fatalError-on-throw would otherwise crash every simulator test/app launch once Task 2 attached it in RithamApp.swift"

patterns-established:
  - "Pattern: a facade's write method that accepts a partial draft treats a nil optional field as 'do not touch this field,' with a separate explicit clear-only operation (invalidateSection) as the sole way to null a field back to unanswered — prevents a caller supplying one field from silently wiping another"

requirements-completed: [HEALTH-02, MINOR-01, DIET-01, ONBOARD-01, EXPLAIN-01]

coverage:
  - id: D1
    description: "Three SwiftData models persist the profile, condition tags, and calibration baseline; ConditionTagRecord's validity/re-screen delegate entirely to RithamCore's ConditionTagValidity; only the derived eating-disorder outcome is stored, never the five raw SCOFF answers"
    requirement: "HEALTH-02"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/PersistenceTests.swift (10 tests)"
        status: pass
      - kind: other
        ref: "grep -c 'ConditionTagValidity' RithamApp/Ritham/Persistence/ConditionTagRecord.swift >= 1; no byAdding/TimeInterval( literal in that file"
        status: pass
    human_judgment: false
  - id: D2
    description: "The SwiftData store carries an explicit .completeUntilFirstUserAuthentication file-protection class on the store file and its -wal/-shm sidecars, read back and verified rather than assumed; RithamApp.swift attaches the container additively, three-owner header comment intact"
    requirement: "HEALTH-02"
    verification:
      - kind: unit
        ref: "./Scripts/build-app.sh test -only-testing:RithamTests (full app launch with the container attached; 37 tests, 4 suites, pass)"
        status: pass
      - kind: other
        ref: "grep -c 'protectionKey'/'completeUntilFirstUserAuthentication'/'attributesOfItem' in RithamModelContainer.swift; grep -c 'modelContainer' in RithamApp.swift"
        status: pass
    human_judgment: false
  - id: D3
    description: "HealthDataStore is the single facade for every screening read/write, with no consent-gate concept of any kind (T-01-65); updateProfile rejects an incoming age under 13 against an existing profile with zero partial writes; overdue condition tags are still returned by activeConditionTags/isReScreenDue per D-08; invalidateSection clears only the edited section, leaving dietary pattern/register untouched for a checklist edit"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/HealthDataStoreTests.swift (12 tests)"
        status: pass
      - kind: other
        ref: "grep -vE comment-stripped HealthDataStore.swift | grep -ciE 'ConsentGate|allows\\(\\.healthScreening\\)|consentRequired' == 0"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 11: Local-First Health Data Persistence Summary

**Three SwiftData `@Model` classes (`UserProfile`, `ConditionTagRecord`, `CalibrationBaselineRecord`) behind `HealthDataStore`, a single ungated facade, backed by a `ModelContainer` whose store file carries an explicit, read-back-verified `.completeUntilFirstUserAuthentication` protection class.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 3
- **Files modified:** 9 (7 created, 2 modified — `RithamApp.swift` and the regenerated `.xcodeproj`)

## Accomplishments
- `UserProfile`, `ConditionTagRecord`, `CalibrationBaselineRecord` persist the profile, condition tags, and calibration baseline; every enum field is stored by raw value with a computed accessor that returns `nil` rather than force-unwrapping an unrecognised value (T-01-64)
- Resolved 01-RESEARCH.md's flagged storage question: only the derived eating-disorder outcome (`edScreenOutcomeRaw`) is stored on `UserProfile`; the five raw SCOFF answers (ED-1 through ED-5) have no persisted home anywhere — verified by a `Mirror`-based reflection test with a positive control (asserting `Mirror` actually sees `age`/`dietaryPattern` first) so the negative assertion can't pass vacuously against SwiftData's macro-rewritten stored properties
- `ConditionTagRecord.validity`/`.isReScreenDue` delegate entirely to `ConditionTagValidity` (RithamCore) — no date arithmetic of its own (T-01-62)
- `RithamModelContainer` applies `.completeUntilFirstUserAuthentication` to the store file and its `-wal`/`-shm` sidecars, then reads the attribute back via `attributesOfItem` to confirm it actually took effect rather than assuming a silent no-op succeeded (T-01-59)
- `RithamApp.swift` attaches `RithamModelContainer.shared` via `.modelContainer(_:)`, additive to 01-09's entry point; the three-owner header comment (01-09 → 01-11 → 01-18) is unchanged
- `HealthDataStore` is the single facade every screening read/write passes through — `loadProfile`/`updateProfile`, `saveScreeningResult`, `activeConditionTags`, `isReScreenDue`, `invalidateSection`, `recordProfessionalClearance`/`clearancesNeedingReConfirmation`, `saveCalibrationBaseline`/`loadCalibrationBaseline` — with genuinely no consent-gate concept anywhere (T-01-65)
- `updateProfile` compares an incoming age against the stored age before any mutation and throws `ageBelowFloor` with zero partial writes when it's under 13 (T-01-66); the check only applies once a profile already exists
- `activeConditionTags` returns both `.active` and `.expiredStillApplied` tags per D-08 (T-01-61); `invalidateSection` clears only the edited section's records, leaving dietary pattern/register untouched for a checklist edit
- Full `RithamTests` suite: 37 tests across 4 suites, green, including a real simulator app launch with the model container attached

## Task Commits

Each task was committed atomically:

1. **Task 1: The three SwiftData models** - `32f93c5` (feat)
2. **Task 2: A model container with explicit file protection** - `a8a68ee` (feat)
3. **Task 3: The health data store facade** - `e53cac9` (feat)

## Files Created/Modified
- `RithamApp/Ritham/Persistence/UserProfile.swift` - `@Model` profile: age, explanationRegisterRaw, dietaryPatternRaw, edScreenOutcomeRaw, createdAt/updatedAt, plus optional-returning computed accessors
- `RithamApp/Ritham/Persistence/ConditionTagRecord.swift` - `@Model` condition tag: tagRaw, recordedAt, editedAt, professionalClearanceGrantedAt; `validity`/`isReScreenDue` delegate to `ConditionTagValidity`
- `RithamApp/Ritham/Persistence/CalibrationBaselineRecord.swift` - `@Model` calibration baseline mirroring `CalibrationBaseline`'s own fields, with a `baseline` computed accessor
- `RithamApp/Ritham/Persistence/RithamModelContainer.swift` - `make(inMemory:)`/`.shared`, fixed store URL, file-protection apply + read-back verification, Simulator-only log/on-device throw split
- `RithamApp/Ritham/Persistence/HealthDataStore.swift` - the facade, `UserProfileDraft`, `HealthDataStoreError`
- `RithamApp/RithamTests/PersistenceTests.swift` - 10 tests: round-trip, validity boundary, editedAt-resets-window, nil-on-unrecognised-raw-value, reflection (with positive control)
- `RithamApp/RithamTests/HealthDataStoreTests.swift` - 12 tests covering every operation, profileMissing, ageBelowFloor + full-field preservation, overdue-tag-still-active, invalidateSection scoping, provisional-calibration-fallback
- `RithamApp/Ritham/App/RithamApp.swift` - added `import SwiftData` and `.modelContainer(RithamModelContainer.shared)`
- `RithamApp/Ritham.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to pick up the new `Persistence/` and test files (established pattern from 01-09)

## Decisions Made
- Only the derived eating-disorder outcome is stored; the five raw SCOFF answers are never persisted (see key-decisions for full rationale)
- `updateProfile`'s nil-means-unchanged semantics for `explanationRegister`/`dietaryPattern` — an implementation detail the plan left unspecified at the single-parameter `updateProfile(_:)` level; resolved by checking 01-13's and 01-16's described call sites (a register-only update must not silently null out an already-set dietary pattern), and confirmed as correct by advisor review before implementation
- `invalidateSection` deletes matching `ConditionTagRecord`s rather than stamping `editedAt` on them — the original plan text read "stamps editedAt," but tracing through `ConditionTagValidity`'s `editedAt ?? recordedAt` resolution showed that stamping an already-overdue record's `editedAt = now` would silently reset its twelve-month window and discharge the D-07 re-screen banner the instant an edit began, before any re-answer actually landed. §1.6 itself says an edit *shortens* the window, never extends it. Caught during advisor review, before any code was written, and pinned by a dedicated test (`invalidateSection deletes rather than extends an overdue tag's window`)
- File-protection read-back verification throws on-device only, logs on Simulator — confirmed empirically (not assumed) by running the full `RithamTests` suite immediately after Task 2, before building Task 3 on top of it, per advisor guidance

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] File-protection read-back verification is unreachable as literally written on the Simulator**
- **Found during:** Task 2, running the full `RithamTests` suite immediately after attaching `RithamModelContainer.shared` in `RithamApp.swift`
- **Issue:** The plan's literal instruction — throw a descriptive error whenever the read-back protection attribute doesn't match what was just set — is correct behavior for a physical device, but the iOS Simulator's host filesystem (ordinary macOS APFS) does not implement Data Protection at all. `setAttributes(_:ofItemAtPath:)` with `.protectionKey` does not throw, but `attributesOfItem`'s read-back never reports `.completeUntilFirstUserAuthentication` there. Because `RithamModelContainer.shared` calls `fatalError` on any throw from `make(inMemory: false)`, and Task 2's own edit to `RithamApp.swift` means *any* simulator test run or app launch now initializes `.shared`, the plan's own gate (`./Scripts/build-app.sh test -only-testing:RithamTests/PersistenceTests`) would have crashed the test host every time — not a clean assertion failure, a preflight-style crash, exactly like 01-09's Deviation #1.
- **Fix:** Wrapped the throw in `#if targetEnvironment(simulator)` — on Simulator, log the mismatch (filename only, no stored value) and continue; on-device, throw as originally specified. This preserves the plan's actual intent (a silent failure surfacing at startup) on the one environment where the OS can enforce the protection class, while keeping the app runnable in the only environment this repo can currently test in.
- **Files modified:** `RithamApp/Ritham/Persistence/RithamModelContainer.swift`
- **Verification:** Ran the full `RithamTests` suite before adding the guard to confirm the failure mode empirically (log output showed "file protection not verified... (expected on Simulator)" for all three candidate files); after adding the guard, the full suite passes (37 tests, 4 suites) with the model container genuinely attached and initialized during a real app launch
- **Committed in:** `a8a68ee` (Task 2 commit) — caught and fixed before committing, not a follow-up

---

**Total deviations:** 1 auto-fixed (1 blocking, environment-specific — a plan gate unreachable as literally written on the only runnable environment)
**Impact on plan:** Necessary for the plan's own test gate to be reachable at all; no scope creep, no architectural change, and the on-device behavior (the behavior LAUNCH-04's review actually cares about) is exactly as specified. The `invalidateSection` deletion-vs-stamping change (see Decisions Made) was resolved during design, before any code was written, so it isn't tracked as a deviation from committed code — it's a correction to an underspecified detail caught before implementation.

## Issues Encountered
One transient simulator failure ("Busy" / "Application failed preflight checks") on the first full-`RithamTests` run after Task 3 — same failure mode 01-09-SUMMARY.md documented, resolved identically via `xcrun simctl shutdown all` and retrying; not caused by anything in this plan's code and did not recur.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `HealthDataStore` and `UserProfileDraft` are ready for plan 01-13's `AgeStepView`/`ExplanationRegisterStepView` (`updateProfile`), plan 01-15's calibration screens (`saveCalibrationBaseline`/`loadCalibrationBaseline`), plan 01-16's screening result screen (`saveScreeningResult`, `activeConditionTags`), and plan 01-17's edit-answer flow (`invalidateSection`, `recordProfessionalClearance`, `clearancesNeedingReConfirmation`) — every method these plans reference by name in their own `<context>` sections now exists with the exact signature described there
- `RithamApp.swift` is ready for plan 01-18's third and final edit (`StepBootstrap.registerAllSteps()`); the three-owner header comment is unchanged and this plan's edit stayed strictly additive
- Full `RithamTests` suite green: 37 tests, 4 suites (10 `PersistenceTests`, 12 `HealthDataStoreTests`, 8 `AppShellTests`, 7 `BandGeometryTests`)
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 8 created/modified files verified present on disk; all 3 task commit hashes
(32f93c5, a8a68ee, e53cac9) verified in git log.
