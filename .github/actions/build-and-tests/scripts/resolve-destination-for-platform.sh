#!/usr/bin/env bash
# Resolves destination for a single platform on the current machine
# Usage: SCHEME=MyScheme PLATFORM=ios resolve-destination-for-platform.sh
set -euo pipefail
: "${SCHEME:?}"
: "${PLATFORM:?}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
LOG_PREFIX="[resolve-destination-for-platform:$PLATFORM]"

echo "$LOG_PREFIX inputs: WORKSPACE=$WS SCHEME=$SCHEME PLATFORM=$PLATFORM"

if ! command -v jq >/dev/null 2>&1; then
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Get available destinations from xcodebuild
SHOW="$(xcodebuild -showdestinations -workspace "$WS" -scheme "$SCHEME" -json 2>/dev/null | sed -n '/^{/,$p' || true)"

# Pick the first available destination for a given platform
# Prioritizes by: 1) available=YES, 2) newest OS version, 3) first in list
pick_destination() {
  local platform="$1"
  local sel='.destinations[]? | select(.platform=="'"$platform"'" and .available=="YES")'

  # Try to get the first available destination, sorted by OS version (newest first)
  local dest="$(echo "$SHOW" | jq -r "$sel | \"\(.OS // \"latest\")|\(.name)\"" | sort -Vr | head -n1 || true)"

  if [ -z "$dest" ] || [ "$dest" = "null" ] || [ "$dest" = "|" ]; then
    echo ""
    return 1
  fi

  local os="${dest%%|*}"
  local name="${dest##*|}"

  # Fallback to "latest" if OS is empty
  if [ -z "$os" ]; then os="latest"; fi

  echo "OS=$os,name=$name"
  return 0
}

# Fallback: Check if runtime exists, if so find device with REAL OS version
# This will be handled by ensure-destination.sh which downloads/creates as needed
pick_fallback_destination() {
  local platform_family="$1"  # e.g., "iOS", "tvOS", "visionOS"
  local device_pattern="$2"   # e.g., "iPhone", "Apple TV", "Apple Vision"
  local default_device="$3"   # e.g., "iPhone 16", "Apple TV"

  # Get the latest runtime with its actual OS version (major.minor from name, not full version)
  local runtime_info="$(xcrun simctl list -j runtimes 2>/dev/null \
    | jq -r --arg f "$platform_family" '.runtimes[]|select(.platform==$f and .isAvailable==true)|"\(.name)|\(.identifier)"' \
    | sort -Vr | head -n1 || true)"

  if [ -n "$runtime_info" ]; then
    local runtime_name="${runtime_info%%|*}"
    local runtime_id="${runtime_info##*|}"
    # Extract version from name like "iOS 26.0" -> "26.0"
    local os_version="$(echo "$runtime_name" | grep -oE '[0-9]+\.[0-9]+' | head -n1 || echo "latest")"

    # Try to find existing device for this runtime
    local device_name="$(xcrun simctl list -j devices available 2>/dev/null \
      | jq -r --arg r "$runtime_id" --arg p "$device_pattern" '.devices[$r][]?|select(.name|test($p))|.name' \
      | head -n1 || true)"

    if [ -n "$device_name" ]; then
      echo "OS=$os_version,name=$device_name"
      return 0
    else
      # Runtime exists but no matching device - return with OS version for ensure-destination
      echo "OS=$os_version,name=$default_device"
      return 0
    fi
  fi

  # No runtime at all - return latest as fallback
  echo "OS=latest,name=$default_device"
  return 0
}

# Resolve destination based on platform (case-insensitive)
PLATFORM_LOWER="$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')"

case "$PLATFORM_LOWER" in
  ios)
    if PAIR="$(pick_destination 'iOS Simulator')"; then
      DEST="platform=iOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX xcodebuild found no iOS Simulator, using fallback"
      PAIR="$(pick_fallback_destination 'iOS' 'iPhone' 'iPhone 16')"
      DEST="platform=iOS Simulator,${PAIR}"
    fi
    ;;
  tvos)
    if PAIR="$(pick_destination 'tvOS Simulator')"; then
      DEST="platform=tvOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX xcodebuild found no tvOS Simulator, using fallback"
      PAIR="$(pick_fallback_destination 'tvOS' 'Apple TV' 'Apple TV')"
      DEST="platform=tvOS Simulator,${PAIR}"
    fi
    ;;
  visionos)
    if PAIR="$(pick_destination 'visionOS Simulator')"; then
      DEST="platform=visionOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX xcodebuild found no visionOS Simulator, using fallback"
      PAIR="$(pick_fallback_destination 'visionOS' 'Apple Vision' 'Apple Vision Pro')"
      DEST="platform=visionOS Simulator,${PAIR}"
    fi
    ;;
  maccatalyst)
    DEST="platform=macOS,variant=Mac Catalyst"
    ;;
  *)
    echo "::error::Unknown platform: $PLATFORM"
    exit 1
    ;;
esac

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "destination=$DEST" >> "$GITHUB_OUTPUT"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "DEST=$DEST" >> "$GITHUB_ENV"
fi

echo "$LOG_PREFIX output: destination=$DEST"
