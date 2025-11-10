#!/usr/bin/env bash
set -euo pipefail
: "${SCHEME:?}"
WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"

echo "[resolve-destinations] inputs: WORKSPACE=$WS SCHEME=$SCHEME"

if ! command -v jq >/dev/null 2>&1; then
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Xcode někdy vypíše před JSONem hlášky - sed odřízne vše před prvním '{'
SHOW="$(xcodebuild -showdestinations -workspace "$WS" -scheme "$SCHEME" -json 2>/dev/null | sed -n '/^{/,$p' || true)"

pick_name_os() {
  local platform="$1" name_re="$2" fallback_name="$3" fallback_os="$4"
  # vezmeme první dostupnou destinaci dané platformy, která sedí na jméno zařízení
  local sel='.destinations[]? | select(.platform=="'"$platform"'" and .available=="YES")'
  local name="$(echo "$SHOW" | jq -r "$sel | .name" | grep -E "$name_re" | head -n1 || true)"
  local os="$(echo "$SHOW" | jq -r "$sel | .OS" | head -n1 || true)"

  # fallbacky
  if [ -z "${name:-}" ] || [ "$name" = "null" ]; then name="$fallback_name"; fi
  if [ -z "${os:-}" ]   || [ "$os"   = "null" ]; then os="$fallback_os"; fi

  # vrátíme "OS=…,name=…"
  echo "OS=$os,name=$name"
}

IOS_PAIR="$(pick_name_os 'iOS Simulator' 'iPhone|iPad' 'iPhone 16' 'latest')"
TVOS_PAIR="$(pick_name_os 'tvOS Simulator' 'Apple TV' 'Apple TV 4K (3rd generation)' 'latest')"
VOS_PAIR="$(pick_name_os 'visionOS Simulator' 'Apple Vision' 'Apple Vision Pro' 'latest')"

IOS_DEST="platform=iOS Simulator,${IOS_PAIR}"
TVOS_DEST="platform=tvOS Simulator,${TVOS_PAIR}"
VISIONOS_DEST="platform=visionOS Simulator,${VOS_PAIR}"
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