#!/usr/bin/env bash
set -euo pipefail
: "${SCHEME:?}"

echo "[resolve-destinations] inputs: SCHEME=$SCHEME"

if ! command -v jq >/dev/null 2>&1; then
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Use name-based destinations instead of UUIDs.
# UUIDs are runner-specific and break when prepare and build/test run on
# different runner instances.  Name-based specifiers are portable.

pick_name() {
  local platform="$1"
  local name_pattern="$2"
  xcrun simctl list -j devices available \
    | jq -r --arg pat "$name_pattern" \
        '.devices[][] | select(.isAvailable==true and (.name | test($pat))) | .name' \
    | head -n1
}

IOS_NAME="$(pick_name 'iOS' 'iPhone|iPad')"
if [ -n "${IOS_NAME:-}" ]; then
  IOS_DEST="platform=iOS Simulator,name=$IOS_NAME"
else
  IOS_DEST="platform=iOS Simulator,name=iPhone 16"
fi

TVOS_NAME="$(pick_name 'tvOS' 'Apple TV')"
if [ -n "${TVOS_NAME:-}" ]; then
  TVOS_DEST="platform=tvOS Simulator,name=$TVOS_NAME"
else
  TVOS_DEST="platform=tvOS Simulator,name=Apple TV 4K (3rd generation)"
fi

# visionOS is build-only (no tests), so use a generic destination that
# does not require a downloaded simulator runtime.
VISIONOS_DEST="generic/platform=visionOS Simulator"

MACCAT_DEST="platform=macOS,variant=Mac Catalyst"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "ios_dest=$IOS_DEST"
    echo "tvos_dest=$TVOS_DEST"
    echo "visionos_dest=$VISIONOS_DEST"
    echo "maccatalyst_dest=$MACCAT_DEST"
  } >> "$GITHUB_OUTPUT"
fi

echo "[resolve-destinations] outputs: ios_dest=$IOS_DEST"
echo "[resolve-destinations] outputs: tvos_dest=$TVOS_DEST"
echo "[resolve-destinations] outputs: visionos_dest=$VISIONOS_DEST"
echo "[resolve-destinations] outputs: maccatalyst_dest=$MACCAT_DEST"
