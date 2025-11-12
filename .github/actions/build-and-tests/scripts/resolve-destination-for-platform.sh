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

# Resolve destination based on platform (case-insensitive)
PLATFORM_LOWER="$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')"

case "$PLATFORM_LOWER" in
  ios)
    if PAIR="$(pick_destination 'iOS Simulator')"; then
      DEST="platform=iOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX Warning: No iOS Simulator found, using fallback"
      DEST="platform=iOS Simulator,OS=latest,name=iPhone 16"
    fi
    ;;
  tvos)
    if PAIR="$(pick_destination 'tvOS Simulator')"; then
      DEST="platform=tvOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX Warning: No tvOS Simulator found, using fallback"
      DEST="platform=tvOS Simulator,OS=latest,name=Apple TV 4K (3rd generation)"
    fi
    ;;
  visionos)
    if PAIR="$(pick_destination 'visionOS Simulator')"; then
      DEST="platform=visionOS Simulator,${PAIR}"
    else
      echo "$LOG_PREFIX Warning: No visionOS Simulator found, using fallback"
      DEST="platform=visionOS Simulator,OS=latest,name=Apple Vision Pro"
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
