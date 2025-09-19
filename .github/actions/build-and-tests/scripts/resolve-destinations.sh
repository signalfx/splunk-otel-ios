#!/usr/bin/env bash
set -euo pipefail
: "${SCHEME:?}"
WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"

echo "[resolve-destinations] inputs: WORKSPACE=$WS SCHEME=$SCHEME"

if ! command -v jq >/dev/null 2>&1; then
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

SHOW="$(xcodebuild -showdestinations -workspace "$WS" -scheme "$SCHEME" -json 2>/dev/null | sed -n '/^{/,$p' || true)"

pick_id() { echo "$SHOW" | jq -r '.destinations[]? | select(.platform=="'"$1"'" and .available=="YES") | .id' | head -n1; }

IOS_DID="$(pick_id 'iOS Simulator' || true)"
if [ -n "${IOS_DID:-}" ] && [ "$IOS_DID" != "null" ]; then
  IOS_DEST="id=$IOS_DID"
else
  ID="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("iPhone|iPad"))).udid' | head -n1 || true)"
  if [ -n "${ID:-}" ]; then IOS_DEST="platform=iOS Simulator,id=$ID"; else IOS_DEST="platform=iOS Simulator,OS=latest,name=iPhone 16"; fi
fi

TVOS_DID="$(pick_id 'tvOS Simulator' || true)"
if [ -n "${TVOS_DID:-}" ] && [ "$TVOS_DID" != "null" ]; then
  TVOS_DEST="id=$TVOS_DID"
else
  ID="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("Apple TV"))).udid' | head -n1 || true)"
  if [ -n "${ID:-}" ]; then TVOS_DEST="platform=tvOS Simulator,id=$ID"; else TVOS_DEST="platform=tvOS Simulator,OS=latest,name=Apple TV 4K (3rd generation)"; fi
fi

VOS_DID="$(pick_id 'visionOS Simulator' || true)"
if [ -n "${VOS_DID:-}" ] && [ "$VOS_DID" != "null" ]; then
  VISIONOS_DEST="id=$VOS_DID"
else
  ID="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("Apple Vision"))).udid' | head -n1 || true)"
  if [ -n "${ID:-}" ]; then VISIONOS_DEST="platform=visionOS Simulator,id=$ID"; else VISIONOS_DEST="platform=visionOS Simulator,OS=latest,name=Apple Vision Pro"; fi
fi

MACCAT_DEST="platform=macOS,variant=Mac Catalyst"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "ios_dest=$IOS_DEST"
    echo "tvos_dest=$TVOS_DEST"
    echo "visionos_dest=$VISIONOS_DEST"
    echo "maccatalyst_dest=$MACCAT_DEST"
  } >> "$GITHUB_ENV"
fi

echo "[resolve-destinations] outputs: ios_dest=$IOS_DEST"
echo "[resolve-destinations] outputs: tvos_dest=$TVOS_DEST"
echo "[resolve-destinations] outputs: visionos_dest=$VISIONOS_DEST"
echo "[resolve-destinations] outputs: maccatalyst_dest=$MACCAT_DEST"

echo "::set-output name=ios_dest::$IOS_DEST"
echo "::set-output name=tvos_dest::$TVOS_DEST"
echo "::set-output name=visionos_dest::$VISIONOS_DEST"
echo "::set-output name=maccatalyst_dest::$MACCAT_DEST"
