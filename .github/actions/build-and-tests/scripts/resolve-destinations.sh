#!/usr/bin/env bash
# resolve-destinations.sh
#
# Resolves simulator destinations for xcodebuild commands.
# This script MUST be run on the same runner that will execute the build/test,
# as simulator availability varies between machines.
#
# Outputs name-based destinations (not UDIDs) to ensure portability.
# For builds: uses generic platform destinations when possible.
# For tests: uses specific simulator names discovered dynamically.

set -euo pipefail

echo "[resolve-destinations] Starting destination resolution..."

# Install jq if not available
if ! command -v jq >/dev/null 2>&1; then
  echo "[resolve-destinations] Installing jq..."
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Get all available simulators as JSON
SIMCTL_JSON="$(xcrun simctl list -j devices available 2>/dev/null || echo '{}')"

# Helper function to find first available simulator by name pattern
# Usage: find_simulator "iPhone|iPad" -> returns device name or empty
find_simulator() {
  local pattern="$1"
  echo "$SIMCTL_JSON" | jq -r --arg pat "$pattern" '
    .devices | to_entries[] | .value[] |
    select(.isAvailable == true and (.name | test($pat))) |
    .name
  ' 2>/dev/null | head -n1 || true
}

# --- iOS Simulator ---
# For builds: use generic destination (no specific device needed)
# For tests: find an actual available iPhone/iPad
IOS_BUILD_DEST="generic/platform=iOS Simulator"

IPHONE_NAME="$(find_simulator "^iPhone")"
if [ -z "$IPHONE_NAME" ]; then
  # Fallback to iPad if no iPhone available
  IPHONE_NAME="$(find_simulator "^iPad")"
fi

if [ -n "$IPHONE_NAME" ]; then
  IOS_TEST_DEST="platform=iOS Simulator,name=$IPHONE_NAME"
  echo "[resolve-destinations] Found iOS Simulator: $IPHONE_NAME"
else
  # Last resort fallback - let xcodebuild try to find something
  IOS_TEST_DEST="platform=iOS Simulator,name=iPhone 16"
  echo "::warning::[resolve-destinations] No iOS Simulator found, using fallback"
fi

# --- tvOS Simulator ---
TVOS_BUILD_DEST="generic/platform=tvOS Simulator"

TVOS_NAME="$(find_simulator "Apple TV")"
if [ -n "$TVOS_NAME" ]; then
  TVOS_TEST_DEST="platform=tvOS Simulator,name=$TVOS_NAME"
  echo "[resolve-destinations] Found tvOS Simulator: $TVOS_NAME"
else
  TVOS_TEST_DEST="platform=tvOS Simulator,name=Apple TV"
  echo "::warning::[resolve-destinations] No tvOS Simulator found, using fallback"
fi

# --- visionOS Simulator ---
VISIONOS_BUILD_DEST="generic/platform=visionOS Simulator"

VISIONOS_NAME="$(find_simulator "Apple Vision")"
if [ -n "$VISIONOS_NAME" ]; then
  VISIONOS_TEST_DEST="platform=visionOS Simulator,name=$VISIONOS_NAME"
  echo "[resolve-destinations] Found visionOS Simulator: $VISIONOS_NAME"
else
  VISIONOS_TEST_DEST="platform=visionOS Simulator,name=Apple Vision Pro"
  echo "::warning::[resolve-destinations] No visionOS Simulator found, using fallback"
fi

# --- Mac Catalyst ---
MACCAT_DEST="platform=macOS,variant=Mac Catalyst"

# Output to GITHUB_OUTPUT if available
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    # Build destinations (generic, for compile-only)
    echo "ios_build_dest=$IOS_BUILD_DEST"
    echo "tvos_build_dest=$TVOS_BUILD_DEST"
    echo "visionos_build_dest=$VISIONOS_BUILD_DEST"
    # Test destinations (specific simulators)
    echo "ios_dest=$IOS_TEST_DEST"
    echo "tvos_dest=$TVOS_TEST_DEST"
    echo "visionos_dest=$VISIONOS_TEST_DEST"
    # Mac Catalyst (same for build and test)
    echo "maccatalyst_dest=$MACCAT_DEST"
  } >> "$GITHUB_OUTPUT"
fi

# Log outputs
echo "[resolve-destinations] Build destinations:"
echo "  ios_build_dest=$IOS_BUILD_DEST"
echo "  tvos_build_dest=$TVOS_BUILD_DEST"
echo "  visionos_build_dest=$VISIONOS_BUILD_DEST"
echo "[resolve-destinations] Test destinations:"
echo "  ios_dest=$IOS_TEST_DEST"
echo "  tvos_dest=$TVOS_TEST_DEST"
echo "  visionos_dest=$VISIONOS_TEST_DEST"
echo "  maccatalyst_dest=$MACCAT_DEST"
