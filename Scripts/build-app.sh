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

XCODEBUILD_ACTION="build"
if [[ "$SUBCOMMAND" == "test" ]]; then
  XCODEBUILD_ACTION="test"
fi

xcodebuild "$XCODEBUILD_ACTION" \
  -project RithamApp/Ritham.xcodeproj \
  -scheme Ritham \
  -destination "$DESTINATION" \
  "$@"
