---
phase: 01-onboarding-safety-intake
plan: 01
subsystem: ios-core
tags: [swift, swift-package-manager, swift-testing, ios17, macos14]

# Dependency graph
requires: []
provides:
  - "RithamCore Swift package (Foundation-only, macOS 14 / iOS 17 platform floor)"
  - "Scripts/test-core.sh — toolchain-adaptive test runner (CommandLineTools vs Xcode)"
  - "ScreeningCopy — all seven HEALTH-05 disclaimer/legal copy blocks, addressable by name"
  - "OnboardingCopy — nine nested screen-copy namespaces including the AgeGate (MINOR-01) strings"
affects: [01-03, 01-05, 01-06, 01-07, 01-09, 01-10, 01-11, 01-12, 01-13, 01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: [swift-testing]
  patterns:
    - "Copy catalogs (ScreeningCopy, OnboardingCopy) as public enum namespaces of static string constants — downstream view plans reference identifiers, never re-transcribe locked copy"
    - "Toolchain-adaptive test script that branches on `xcode-select -p` so the same invocation works before and after the Wave 4 Xcode install"

key-files:
  created:
    - RithamCore/Package.swift
    - RithamCore/Scripts/test-core.sh
    - RithamCore/Sources/RithamCore/RithamCore.swift
    - RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift
    - RithamCore/Sources/RithamCore/Copy/OnboardingCopy.swift
    - RithamCore/Tests/RithamCoreTests/HarnessTests.swift
    - RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift
    - RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift
  modified: []

key-decisions:
  - "Extracted CTA label text without brackets for routineClearanceCTA/urgentClearanceCTA per the plan's 'bracketed CTA label text' instruction — the brackets in docs/health-screening.md are markdown button-affordance notation, not literal characters to ship"
  - "OnboardingCopy.HealthProfile splits the spec's combined 'body + CTA' table cell into emptyStateBody and emptyStateCTA as two separate constants, matching the plan's explicit member list"

patterns-established:
  - "Pattern: verbatim legal/medical copy lives in a single enum namespace per domain (ScreeningCopy for health-screening.md, OnboardingCopy for the UI spec's Copywriting Contract), with tests asserting load-bearing substrings (911 carve-out, forbidden terms) survive transcription rather than diffing the whole string"

requirements-completed: [HEALTH-05, MINOR-01]

coverage:
  - id: D1
    description: "RithamCore Swift package builds and its Swift Testing suite runs green via a toolchain-adaptive script, with no Xcode installed"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/HarnessTests.swift#schemaVersionIsOne"
        status: pass
      - kind: other
        ref: "cd RithamCore && swift build"
        status: pass
    human_judgment: false
  - id: D2
    description: "All seven HEALTH-05 disclaimer/legal copy blocks plus section framing copy exist verbatim in ScreeningCopy, addressable by name, with the 911 emergency line and D-12 multi-condition listing verified"
    requirement: "HEALTH-05"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift (6 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every onboarding screen string, including the permanent 13+ AgeGate copy, is addressable from OnboardingCopy with no consent-concept or 'senior mode' language anywhere in the catalog"
    requirement: "MINOR-01"
    verification:
      - kind: unit
        ref: "RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift (7 tests)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-25
status: complete
---

# Phase 01 Plan 01: RithamCore Package & Copy Catalogs Summary

**Foundation-only RithamCore Swift package with a toolchain-adaptive Swift Testing harness, plus verbatim ScreeningCopy and OnboardingCopy catalogs covering all locked HEALTH-05/MINOR-01 strings.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-25T16:45:30Z
- **Completed:** 2026-08-25T16:52:12Z
- **Tasks:** 3
- **Files modified:** 8 (all created)

## Accomplishments
- Stood up the `RithamCore` Swift package (macOS 14 / iOS 17 floor) and `Scripts/test-core.sh`, which detects a Command Line Tools-only developer directory and injects the Swift Testing framework search path plus two rpaths — verified green with `swift build` and the harness test on a machine with no Xcode installed
- Single-sourced all seven HEALTH-05 disclaimer/legal copy blocks (plus gate framing/pass/checklist/SCOFF intro copy and the two D-12 multi-condition-aware functions) into `ScreeningCopy`, transcribed verbatim from `docs/health-screening.md`
- Single-sourced every onboarding screen string from `01-UI-SPEC.md`'s Copywriting Contract into `OnboardingCopy`, including the permanent 13+ `AgeGate` copy with no parental-consent or age-segmented-mode language anywhere in the catalog

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold the RithamCore package and its toolchain-adaptive test harness** - `80e515a` (feat)
2. **Task 2: Single-source HEALTH-05's disclaimer and legal copy blocks** - `ffc1e61` (feat)
3. **Task 3: Single-source the onboarding screen copy from the UI design contract** - `5852068` (feat)

## Files Created/Modified
- `RithamCore/Package.swift` - swift-tools-version 6.0, macOS(.v14)/iOS(.v17) platforms, RithamCore library product + RithamCoreTests test target
- `RithamCore/.gitignore` - ignores `.build/` and `.swiftpm/`
- `RithamCore/Scripts/test-core.sh` - executable; branches on `xcode-select -p` to run `swift test` with the verified CommandLineTools flag sequence, or plain `swift test` once Xcode is installed
- `RithamCore/Sources/RithamCore/RithamCore.swift` - root `RithamCore` enum with `schemaVersion = 1`; header comment records the Foundation-only import constraint
- `RithamCore/Sources/RithamCore/Copy/ScreeningCopy.swift` - all seven HEALTH-05 blocks, gate framing/affirmation, checklist/SCOFF intros, rationale lines, and the two D-12 parameterised functions
- `RithamCore/Sources/RithamCore/Copy/OnboardingCopy.swift` - nine nested screen namespaces (Welcome, Register, Age, Diet, AgeGate, Privacy, Calibration, HealthProfile, Errors)
- `RithamCore/Tests/RithamCoreTests/HarnessTests.swift` - proves the Swift Testing harness executes
- `RithamCore/Tests/RithamCoreTests/ScreeningCopyTests.swift` - 6 tests covering 911 carve-out, PAR-Q-name absence, D-12 multi-condition listing, and non-empty/trimmed constants
- `RithamCore/Tests/RithamCoreTests/OnboardingCopyTests.swift` - 7 tests covering the CROSSGEN-05/DIET-01/CROSSGEN-03/MINOR-01 promise strings and the consent/"senior mode" absence checks

## Decisions Made
- Extracted `routineClearanceCTA`/`urgentClearanceCTA` as the bracketed label text with the brackets stripped, per the plan's explicit instruction — the source document's `[...]` notation marks a button affordance, not literal ship-text
- Split the UI spec's combined "Empty state body" table cell (body text + CTA) into `HealthProfile.emptyStateBody` and `HealthProfile.emptyStateCTA` as two separate constants, matching the plan's member list exactly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Toolchain facts from the plan's `<interfaces>` block (CommandLineTools-only developer directory, Swift Testing framework/rpath locations, the macOS 14 platform-floor requirement) were reproduced exactly as documented and worked on the first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `RithamCore` is buildable and its full Swift Testing suite (14 tests, 3 suites) runs green via `./Scripts/test-core.sh`, giving every subsequent Wave 1-3 plan a working automated feedback loop before the Wave 4 Xcode install
- `ScreeningCopy` and `OnboardingCopy` are ready for downstream view plans to reference by identifier instead of re-transcribing locked legal/UI copy
- No blockers for plan 01-03 (next in wave sequence per dependency graph)

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-25*

## Self-Check: PASSED

All 9 created files verified present on disk; all 4 commit hashes (80e515a, ffc1e61, 5852068, 8c4cd37) verified in git log.
