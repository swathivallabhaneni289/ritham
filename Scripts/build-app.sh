#!/bin/bash
# Stable entry point for building/testing the Ritham iOS app target, so no later plan repeats a
# long xcodebuild destination string or hardcodes a simulator model that may not exist on every
# machine (01-VALIDATION.md's example commands name "iPhone 15", which is not guaranteed to be
# installed). The destination's simulator UDID is resolved dynamically from
# `xcrun simctl list devices available` instead.
#
# Usage:
#   Scripts/build-app.sh build [extra xcodebuild args]
#   Scripts/build-app.sh test  [extra xcodebuild args, e.g. -only-testing:RithamTests/AppShellTests]
set -euo pipefail

# Self-locate at the repo root regardless of the caller's working directory.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SUBCOMMAND="${1:-}"
if [[ "$SUBCOMMAND" != "build" && "$SUBCOMMAND" != "test" ]]; then
  echo "Usage: $0 {build|test} [extra xcodebuild args]" >&2
  exit 1
fi
shift

# Resolve an available iPhone simulator's UDID dynamically. A UDID destination works for both
# `build` and `test` (a bare `generic/platform=iOS Simulator` destination works for build but not
# for test, which needs a concrete device to run the test bundle on).
DEVICE_UDID="$(
  xcrun simctl list devices available 2>/dev/null \
    | grep -E '^\s+iPhone' \
    | head -n 1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]+)\).*/\1/'
)"

if [[ -z "$DEVICE_UDID" ]]; then
  echo "ERROR: No available iPhone simulator found via 'xcrun simctl list devices available'." >&2
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=${DEVICE_UDID}"

XCODEBUILD_ACTION="$SUBCOMMAND"

if [[ "$SUBCOMMAND" == "test" ]]; then
  # `StepRegistry` (App/StepRegistry.swift) is shared static state that several test suites
  # (AppShellTests, AboutYouStepTests, CalibrationSourceTests, ScreeningFlowTests,
  # PhaseCoverageTests) reset and register into during their own `init()`. Swift Testing
  # parallelizes independent suites against each other by default, and full-suite runs were
  # observed to race across those suites -- one suite's `StepRegistry.reset()` interleaving
  # with another's assertions, non-deterministically failing `unregisteredSteps`/
  # registration-count checks that pass every time in isolation (01-18's PhaseCoverageTests
  # made this collision consistent rather than occasional, since it's the one suite that
  # registers every step). `-parallel-testing-enabled NO` serializes the whole test run so
  # suites never interleave, matching what every affected suite's own header comment already
  # assumed ("running concurrently... would make them order-dependent"). Kept as a plain,
  # bash-3.2-safe conditional (rather than an optionally-empty array under `set -u`) since
  # macOS ships bash 3.2 by default and `"${arr[@]}"` on an empty array errors there.
  xcodebuild "$XCODEBUILD_ACTION" \
    -project RithamApp/Ritham.xcodeproj \
    -scheme Ritham \
    -destination "$DESTINATION" \
    -parallel-testing-enabled NO \
    "$@"
else
  xcodebuild "$XCODEBUILD_ACTION" \
    -project RithamApp/Ritham.xcodeproj \
    -scheme Ritham \
    -destination "$DESTINATION" \
    "$@"
fi
