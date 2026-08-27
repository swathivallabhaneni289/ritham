---
phase: 01-onboarding-safety-intake
plan: 09
subsystem: ios-app-shell
tags: [swiftui, xcodegen, navigationstack, swift6, ios17, xcodebuild]

# Dependency graph
requires:
  - phase: 01-01
    provides: "RithamCore Swift package (Foundation-only, macOS 14 / iOS 17 platform floor)"
  - phase: 01-07
    provides: "OnboardingStep, OnboardingAnswers, OnboardingRouter.nextStep(after:answers:)/.isReachable(_:answers:) — the single branching authority"
provides:
  - "RithamApp/Ritham.xcodeproj (xcodegen-generated, committed) and RithamApp/project.yml — the reproducible iOS app + test target definitions, iOS 17.0 floor, Swift 6 strict concurrency, local RithamCore package dependency"
  - "Scripts/build-app.sh — stable build/test entry point resolving an available iPhone simulator UDID dynamically"
  - "OnboardingRootView — the single NavigationStack + navigationDestination(for: OnboardingStep) for the whole app (CROSSGEN-05)"
  - "OnboardingStepPresenting protocol + StepRegistry (register/view(for:flow:)/unregisteredSteps) — the screen-contribution contract every later screen plan implements"
  - "OnboardingFlow (@Observable, @MainActor) — advance(from:)/goBack() delegating wholly to OnboardingRouter.nextStep, no local branching"
affects: [01-10, 01-11, 01-12, 01-13, 01-15, 01-16, 01-17, 01-18]

# Tech tracking
tech-stack:
  added: [xcodegen, "Swift 6 strict concurrency (SWIFT_STRICT_CONCURRENCY: complete)"]
  patterns:
    - "xcodegen-generated .xcodeproj from a checked-in project.yml, regenerated whenever source files are added (folder references in xcodegen are a file list snapshot, not a live sync)"
    - "@MainActor isolation on StepRegistry/OnboardingFlow/OnboardingStepPresenting to satisfy Swift 6 strict concurrency for a static registry of non-Sendable view-factory closures — registration happens at launch, resolution inside navigationDestination, both already main-actor"
    - "Step-identity guard (next != step) in OnboardingFlow.advance to prevent unbounded path growth when the router intentionally holds at the same step (ageIneligible), distinguished explicitly from an age/tier/consent branch"
    - "Dynamic simulator UDID resolution in build-app.sh via `xcrun simctl list devices available` instead of a hardcoded device name"

key-files:
  created:
    - RithamApp/project.yml
    - RithamApp/Ritham.xcodeproj/project.pbxproj
    - RithamApp/Ritham/Resources/Info.plist
    - RithamApp/Ritham/App/RithamApp.swift
    - RithamApp/Ritham/App/OnboardingRootView.swift
    - RithamApp/Ritham/App/OnboardingStepPresenting.swift
    - RithamApp/Ritham/App/StepRegistry.swift
    - RithamApp/RithamTests/AppShellTests.swift
    - RithamApp/.gitignore
    - Scripts/build-app.sh
  modified: []

key-decisions:
  - "Deployment floor confirmed at iOS 17.0 against the installed iPhoneSimulator26.5 SDK — clean build, no deployment-target warning, as the plan asked this task to confirm"
  - "Simulator destination resolved as a UDID (platform=iOS Simulator,id=<udid>), not a bare generic destination or a device name — a UDID works for both `build` and `test`, where a name can be ambiguous across runtimes and a generic destination cannot run a test bundle"
  - "RithamTests links both the Ritham app target and the RithamCore package directly (as the plan specifies) rather than inheriting RithamCore transitively; no duplicate-symbol warnings were observed, so no deviation was needed here"

patterns-established:
  - "Pattern: a screen is contributed by conforming to OnboardingStepPresenting and calling StepRegistry.register(_:) — never by editing OnboardingRootView or StepRegistry's lookup switch"

requirements-completed: [CROSSGEN-05]

coverage:
  - id: D1
    description: "The iOS app target builds against a real iOS SDK (Xcode 26.6, iPhoneSimulator26.5) and links RithamCore as a local package dependency"
    requirement: "CROSSGEN-05"
    verification:
      - kind: other
        ref: "./Scripts/build-app.sh build (BUILD SUCCEEDED)"
        status: pass
      - kind: other
        ref: "grep -c 'RithamCore' RithamApp/project.yml == 4"
        status: pass
    human_judgment: false
  - id: D2
    description: "Exactly one NavigationStack hosts every onboarding step, for every user regardless of age, resolved through one StepRegistry lookup that never traps for an unregistered step"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/AppShellTests.swift#viewResolvesEveryStepWithoutTrapping, #registeringShrinksUnregisteredStepsByExactlyOneStep"
        status: pass
      - kind: other
        ref: "grep -rl 'NavigationStack' RithamApp/Ritham lists only OnboardingRootView.swift"
        status: pass
    human_judgment: false
  - id: D3
    description: "OnboardingFlow.advance delegates wholly to OnboardingRouter.nextStep with no local branching on age/tier/consent, and does not grow the path unboundedly when the router holds at the same step (under-13/ageIneligible) or returns nil (after .home)"
    requirement: "CROSSGEN-05"
    verification:
      - kind: unit
        ref: "RithamApp/RithamTests/AppShellTests.swift#advanceAppendsExactlyWhatRouterReturns, #advanceAppendsForEligibleAge, #advanceDoesNotGrowPathWhenRouterHoldsAtSameStep, #advanceIsNoOpAfterHome, #goBackRemovesLastPathElement, #goBackIsNoOpOnEmptyPath"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 09: iOS App Target & Navigation Shell Summary

**Xcodegen-generated iOS app target (iOS 17.0, Swift 6 strict concurrency) wired to RithamCore, with a single `NavigationStack`-based `OnboardingRootView` and a `StepRegistry`/`OnboardingStepPresenting` protocol pair that structurally enforces CROSSGEN-05's one-container guarantee.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3 (Task 1 pre-verified by orchestrator; Tasks 2 and 3 executed)
- **Files modified:** 10 (9 created, 1 regenerated — the xcodeproj)

## Accomplishments
- Cleared the phase's environment blocker: Xcode 26.6 confirmed installed and selected (`xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`), iPhoneSimulator26.5 SDK present, 5 available iPhone simulators, `RithamCore/Scripts/test-core.sh` still green (153 tests, 11 suites) on its non-CommandLineTools branch
- `xcodegen` installed via Homebrew (2.46.0); `RithamApp/project.yml` generates a reproducible `Ritham.xcodeproj` defining the `Ritham` app target and `RithamTests` unit-test target, both iOS 17.0, Swift 6 with `SWIFT_STRICT_CONCURRENCY: complete`, both depending on the local `../RithamCore` package
- `Info.plist` declares `NSMotionUsageDescription` and `NSLocationWhenInUseUsageDescription` (worded to match D-02's "declining location blocks nothing" promise), portrait-only, no ATS exceptions, no Associated Domains entitlement — confirmed no universal-link/consent-email concept exists anywhere in this product
- `Scripts/build-app.sh` self-locates to the repo root and resolves an available iPhone simulator's UDID dynamically via `xcrun simctl list devices available`, rather than hardcoding a device name that may not exist on every machine
- `RithamApp.swift` is the `@main` entry point with a header comment recording its three owners in wave order (01-09 → 01-11 → 01-18)
- `OnboardingRootView` — the single `NavigationStack` + `navigationDestination(for: OnboardingStep.self)` for the entire app, resolved through `StepRegistry.view`; confirmed by grep to be the only file in `RithamApp/Ritham` declaring `NavigationStack`
- `OnboardingStepPresenting` (`@MainActor` protocol) — the contract later plans conform to in order to contribute a screen
- `StepRegistry` (`@MainActor enum`) — dictionary-backed `register(_:)`/`view(for:flow:)` that never traps for an unregistered step (returns a labelled placeholder instead), plus `unregisteredSteps` for 01-18's final coverage assertion, plus a test-only `reset()` hook
- `OnboardingFlow` (`@Observable`, `@MainActor final class`) — `advance(from:)` delegates entirely to `OnboardingRouter.nextStep`, with a step-identity guard (not an age check) preventing unbounded path growth when the router intentionally holds at the same step; `goBack()` pops and no-ops on empty
- `AppShellTests` (8 tests, all green): no-trap resolution across every `OnboardingStep`, registration shrinking `unregisteredSteps` by exactly one, `advance` matching the router's output for both an unset-answers case and an age-eligible case, the under-13 same-step guard across repeated calls, the post-`.home` nil case, and both `goBack` behaviors

## Task Commits

Each task was committed atomically:

1. **Task 1: Install Xcode and select it as the active developer directory** — pre-verified by the orchestrator before this plan started (no commit; environment-only, not a repository change)
2. **Task 2: Generate the iOS app target and wire in RithamCore** - `ed7c319` (feat)
3. **Task 3: One shared navigation container and the step registry** - `08487af` (feat)

## Files Created/Modified
- `RithamApp/project.yml` - xcodegen spec: Ritham app target + RithamTests unit-test target, iOS 17.0, Swift 6 strict concurrency, local RithamCore package dependency, TARGETED_DEVICE_FAMILY "1" (iPhone only)
- `RithamApp/Ritham.xcodeproj/` - generated via `xcodegen generate`, committed for reproducibility
- `RithamApp/Ritham/Resources/Info.plist` - NSMotionUsageDescription, NSLocationWhenInUseUsageDescription, portrait-only orientation, standard CFBundle* keys (required once GENERATE_INFOPLIST_FILE is NO), no ATS exceptions, no Associated Domains entitlement
- `RithamApp/.gitignore` - ignores xcuserdata/, build/, DerivedData/, .swiftpm/ — does NOT ignore the committed .xcodeproj
- `Scripts/build-app.sh` - executable; `build`/`test` subcommands, dynamic simulator UDID resolution, self-locating to repo root
- `RithamApp/Ritham/App/RithamApp.swift` - `@main` App entry point rendering `OnboardingRootView`; header comment names the three owners (01-09, 01-11, 01-18)
- `RithamApp/Ritham/App/OnboardingRootView.swift` - the sole `NavigationStack` + `navigationDestination(for: OnboardingStep.self)`
- `RithamApp/Ritham/App/OnboardingStepPresenting.swift` - `@MainActor protocol OnboardingStepPresenting { static var step; static func makeView(flow:) -> AnyView }`
- `RithamApp/Ritham/App/StepRegistry.swift` - `OnboardingFlow` (advance/goBack) and `StepRegistry` (register/view(for:flow:)/unregisteredSteps/reset)
- `RithamApp/RithamTests/AppShellTests.swift` - 8 Swift Testing tests, `.serialized` suite (shared static registry state), `@MainActor`

## Decisions Made
- Confirmed iOS 17.0 as the deployment floor against the installed iPhoneSimulator26.5 SDK — clean build, no warning, so no floor change was needed
- Resolved the build/test destination as a simulator UDID rather than a device name or a generic destination, since a UDID is unambiguous and works for both `xcodebuild build` and `xcodebuild test`
- `RithamTests` links both `Ritham` and the `RithamCore` package directly, per the plan's literal instruction ("linked into both targets") — no duplicate-symbol warning appeared, so this was kept as specified rather than deviated from

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Placeholder `OnboardingRootView.swift` and `AppShellTests.swift` created in Task 2**
- **Found during:** Task 2, immediately on attempting `./Scripts/build-app.sh build`
- **Issue:** Task 2's own action instructs `RithamApp.swift` to render `OnboardingRootView` inside its `WindowGroup`, and its own `<verify>` gate requires `BUILD SUCCEEDED` — but `OnboardingRootView.swift` is a Task 3 deliverable that did not exist yet, and the `RithamTests` target had no source file for xcodegen's `sources: RithamTests` path to reference. Task 2's gate was unreachable as literally sequenced.
- **Fix:** Created a minimal placeholder `OnboardingRootView.swift` (a bare `Text("Ritham")` view) and a minimal placeholder `AppShellTests.swift` (a single trivial passing test) in Task 2's commit, so the app target and test target both compile. Task 3 then overwrote both files in full with their real implementations. Both files were already listed in this plan's `files_modified`, so no new file was introduced outside the plan's declared scope.
- **Files modified:** `RithamApp/Ritham/App/OnboardingRootView.swift`, `RithamApp/RithamTests/AppShellTests.swift`
- **Verification:** `./Scripts/build-app.sh build` reached `BUILD SUCCEEDED` in Task 2; Task 3's full rewrite of both files was verified independently (8/8 `AppShellTests` green)
- **Committed in:** `ed7c319` (Task 2 commit); superseded by `08487af` (Task 3 commit)

**2. [Rule 1 - Bug] Header comment in `StepRegistry.swift` tripped the plan's own `NavigationStack` grep**
- **Found during:** Task 3, verifying acceptance criteria after first writing all four files
- **Issue:** `grep -rl 'NavigationStack' RithamApp/Ritham` is required to list only `OnboardingRootView.swift`, but an explanatory comment in `OnboardingFlow`'s header (documenting why it is `@MainActor`) used the literal string `NavigationStack(path:)` when describing SwiftUI's path binding — the same forbidden-term-in-comment failure mode this repo's 01-07 plan hit (its Deviation #2).
- **Fix:** Reworded the comment to describe "the single shared navigation container's path binding" without spelling `NavigationStack` literally, preserving the same documented rationale.
- **Files modified:** `RithamApp/Ritham/App/StepRegistry.swift`
- **Verification:** `grep -rl 'NavigationStack' RithamApp/Ritham` now returns exactly `OnboardingRootView.swift`; re-ran `./Scripts/build-app.sh test -only-testing:RithamTests/AppShellTests` after the edit (8/8 green, unaffected)
- **Committed in:** `08487af` (Task 3 commit) — caught and fixed before committing, not a follow-up

**3. [Rule 3 - Blocking] `RithamTests` target failed to code-sign with `GENERATE_INFOPLIST_FILE: NO` (implicit default)**
- **Found during:** Task 3, first `./Scripts/build-app.sh test` run
- **Issue:** xcodegen's `bundle.unit-test` target had no explicit Info.plist configuration, and xcodebuild refused to code-sign it: "Cannot code sign because the target does not have an Info.plist file and one is not being generated automatically."
- **Fix:** Added `GENERATE_INFOPLIST_FILE: YES` and an explicit `PRODUCT_BUNDLE_IDENTIFIER` to the `RithamTests` target's settings in `project.yml`, then regenerated the project.
- **Files modified:** `RithamApp/project.yml`
- **Verification:** `./Scripts/build-app.sh test -only-testing:RithamTests/AppShellTests` reached `TEST SUCCEEDED`
- **Committed in:** `08487af` (Task 3 commit)

**4. [Rule 3 - Blocking] Main app's hand-authored `Info.plist` was missing `CFBundleIdentifier` and lacked a bundle ID at install time**
- **Found during:** Task 3, first `./Scripts/build-app.sh test` run (after fixing #3), simulator install failed with "Missing bundle ID"
- **Issue:** With `GENERATE_INFOPLIST_FILE: NO` on the `Ritham` app target (required so the hand-authored `Info.plist` — with its usage-description keys — is the one actually shipped), Xcode does not auto-inject `CFBundleIdentifier` or the other standard `CFBundle*` keys the way it does when a plist is auto-generated; the plist must supply them itself.
- **Fix:** Added `CFBundleIdentifier` (`$(PRODUCT_BUNDLE_IDENTIFIER)`), `CFBundleExecutable`, `CFBundleName`, `CFBundlePackageType`, `CFBundleShortVersionString`, `CFBundleVersion`, `CFBundleInfoDictionaryVersion`, and `CFBundleDevelopmentRegion` to `Info.plist`, using the standard Xcode build-setting macros so they resolve correctly via `-expandbuildsettings`.
- **Files modified:** `RithamApp/Ritham/Resources/Info.plist`
- **Verification:** `./Scripts/build-app.sh test -only-testing:RithamTests/AppShellTests` and the full `./Scripts/build-app.sh test` both installed and ran successfully on the simulator
- **Committed in:** `ed7c319` (Task 2 commit, since `Info.plist` is a Task 2 file — caught while verifying Task 3, fixed retroactively in the already-committed file before Task 3's own commit)

---

**Total deviations:** 4 auto-fixed (2 blocking build-config issues, 1 blocking sequencing issue, 1 bug in a self-referential grep)
**Impact on plan:** All four were necessary for the plan's own literal gates to be reachable (Task 2's build gate needed Task 3's files to exist in placeholder form; xcodegen's default Info.plist handling needed explicit overrides for both targets) or for the plan's own acceptance criteria to hold simultaneously with its own instructions (the comment-wording issue mirrors 01-07's identical pattern in this repo). No scope creep and no architectural change — every fix stayed within files already in this plan's `files_modified`.

## Issues Encountered
One transient simulator/test-runner failure ("Busy" / "Application failed preflight checks") on a second `./Scripts/build-app.sh test` invocation immediately after a prior test run — resolved by `xcrun simctl shutdown all` and retrying; not caused by anything in this plan's code and did not recur.

## User Setup Required

None - Task 1 (Xcode installation) was the phase's one piece of required user setup, and the orchestrator had already verified it complete before this plan began.

## Next Phase Readiness
- The iOS app target builds and tests green against a real SDK (Xcode 26.6, iPhoneSimulator26.5), consuming `RithamCore` as a local package — every rule wave 1-3 already proved correct is the one the app runs
- `OnboardingStepPresenting` and `StepRegistry.register(_:)` are ready for plans 01-10/01-12/01-13/01-15/01-16/01-17 to conform their screens to, without ever touching `OnboardingRootView.swift` or `StepRegistry.swift`'s lookup
- `OnboardingFlow` is ready for 01-11's SwiftData model container attachment (its second owner of `RithamApp.swift`) and 01-18's `StepBootstrap.registerAllSteps()` call (its third owner)
- `StepRegistry.unregisteredSteps` currently returns all 18 `OnboardingStep` cases (nothing registered yet) — 01-18's `PhaseCoverageTests` is expected to assert this is empty once every screen plan has landed
- No blockers for the next plan in wave sequence

---
*Phase: 01-onboarding-safety-intake*
*Completed: 2026-08-27*

## Self-Check: PASSED

All 10 created/modified files verified present on disk; both task commit hashes (ed7c319, 08487af) verified in git log.
