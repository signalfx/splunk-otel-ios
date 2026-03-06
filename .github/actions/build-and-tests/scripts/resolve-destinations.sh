#!/usr/bin/env bash
set -euo pipefail
: "${SCHEME:?}"

echo "[resolve-destinations] inputs: SCHEME=$SCHEME"

if ! command -v jq >/dev/null 2>&1; then
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Use name + OS destinations instead of UUIDs.
# UUIDs are runner-specific and break when prepare and build/test run on
# different runner instances. Name + OS avoids implicit OS:latest matching.

pick_name_and_runtime() {
  local runtime_prefix="$1"
  local name_pattern="$2"
  xcrun simctl list -j devices available \
    | jq -r --arg prefix "$runtime_prefix" --arg pat "$name_pattern" '
        .devices
        | to_entries
        | map(select(.key | startswith("com.apple.CoreSimulator.SimRuntime." + $prefix + "-")))
        | map({
            runtime: .key,
            version: (.key | sub("^com.apple.CoreSimulator.SimRuntime\\." + $prefix + "-"; "") | gsub("-"; ".")),
            name: ([.value[] | select(.isAvailable==true and (.name | test($pat))) | .name] | first)
          })
        | map(select(.name != null))
        | sort_by(.version | split(".") | map((tonumber? // 0)))
        | last
        | select(. != null)
        | "\(.name)|\(.runtime)|\(.version)"
      '
}

IOS_PICK="$(pick_name_and_runtime 'iOS' 'iPhone')"
if [ -n "${IOS_PICK:-}" ]; then
  IFS='|' read -r IOS_NAME _IOS_RUNTIME_ID IOS_OS_VERSION <<< "$IOS_PICK"
  IOS_DEST="platform=iOS Simulator,OS=$IOS_OS_VERSION,name=$IOS_NAME"
else
  IOS_DEST="platform=iOS Simulator,name=iPhone 16"
fi

TVOS_PICK="$(pick_name_and_runtime 'tvOS' 'Apple TV')"
if [ -n "${TVOS_PICK:-}" ]; then
  IFS='|' read -r TVOS_NAME _TVOS_RUNTIME_ID TVOS_OS_VERSION <<< "$TVOS_PICK"
  TVOS_DEST="platform=tvOS Simulator,OS=$TVOS_OS_VERSION,name=$TVOS_NAME"
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
