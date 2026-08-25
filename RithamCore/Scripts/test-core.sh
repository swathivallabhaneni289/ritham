#!/usr/bin/env bash
# Toolchain-adaptive test runner for the RithamCore package.
#
# Xcode is not installed on every development machine this script runs on. When the
# active developer directory is a Command Line Tools instance, Swift Testing is present
# but not on the default search path, and `swift test` needs an explicit framework
# search path plus two rpaths to find it. When a real Xcode.app is selected instead
# (which is what Wave 4 of this phase produces), none of that is needed and plain
# `swift test` works. This script detects which situation it's in and branches, so the
# exact same command keeps working before and after the Wave 4 Xcode install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PACKAGE_ROOT"

DEV_DIR="$(xcode-select -p)"

if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  FW="$DEV_DIR/Library/Developer/Frameworks"
  LIB="$DEV_DIR/Library/Developer/usr/lib"
  exec swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$LIB" \
    "$@"
else
  exec swift test "$@"
fi
