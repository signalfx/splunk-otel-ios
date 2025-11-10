#!/usr/bin/env bash
# Ensures that a simulator/device matching DESTINATION exists on this runner.
# Supports: iOS Simulator, tvOS Simulator, visionOS Simulator
# Usage: export DEST="platform=iOS Simulator,OS=latest,name=iPhone 16"; ensure-destination.sh
set -euo pipefail

log() { echo "[ensure-destination] $*"; }
fail() { echo "::error::$*"; exit 1; }

DEST="${DEST:-${1:-}}"
[ -n "${DEST}" ] || fail "DEST not set. Example: platform=iOS Simulator,OS=latest,name=iPhone 16"

# Require jq (install if missing)
if ! command -v jq >/dev/null 2>&1; then
  log "Installing jq…"
  brew update >/dev/null
  brew install -q jq >/dev/null
fi

# Parse DEST parts
PLATFORM="$(echo "$DEST" | sed -n 's/.*platform=\([^,]*\).*/\1/p')"
OS_REQ="$(echo "$DEST" | sed -n 's/.*OS=\([^,]*\).*/\1/p')"
NAME_REQ="$(echo "$DEST" | sed -n 's/.*name=\(.*\)$/\1/p')"

[ -n "$PLATFORM" ] || fail "Could not parse platform from DEST=$DEST"
[ -n "$NAME_REQ" ] || fail "Could not parse name=… from DEST=$DEST"

# Map "iOS Simulator" -> "iOS" etc. for xcodebuild/xcrun outputs
case "$PLATFORM" in
  "iOS Simulator")   OS_FAMILY="iOS" ;;
  "tvOS Simulator")  OS_FAMILY="tvOS" ;;
  "visionOS Simulator") OS_FAMILY="visionOS" ;;
  *) fail "Unsupported platform: $PLATFORM" ;;
esac

log "Requested: PLATFORM=$PLATFORM ($OS_FAMILY) OS=$OS_REQ NAME=$NAME_REQ"

# Make sure correct Xcode is selected (setup-xcode should have run)
sudo xcode-select -s "$(xcode-select -p)" >/dev/null 2>&1 || true

# Ensure a runtime for this platform exists (download if missing)
have_runtime_for_family() {
  xcrun simctl list -j runtimes | jq -e --arg f "$OS_FAMILY" '.runtimes[]|select(.platform==$f and .isAvailable==true)' >/dev/null
}

if ! have_runtime_for_family; then
  log "No $OS_FAMILY runtime found. Downloading platform via xcodebuild…"
  sudo xcodebuild -runFirstLaunch || true
  sudo xcodebuild -downloadPlatform "$OS_FAMILY" || true
fi

# Resolve runtime identifier
if [ "${OS_REQ:-}" = "latest" ] || [ -z "${OS_REQ:-}" ]; then
  RUNTIME_ID="$(xcrun simctl list -j runtimes \
    | jq -r --arg f "$OS_FAMILY" '.runtimes[]|select(.platform==$f and .isAvailable==true)|.identifier' \
    | sort -Vr | head -n1)"
else
  # Match either by .version (e.g., "18.0") or by suffix in .name (e.g., "iOS 18.0")
  RUNTIME_ID="$(xcrun simctl list -j runtimes \
    | jq -r --arg f "$OS_FAMILY" --arg v "$OS_REQ" \
      '.runtimes[]|select(.platform==$f and .isAvailable==true and (.version==$v or (.name|endswith($v))))|.identifier' \
    | head -n1)"
  # fallback to latest if exact not found
  if [ -z "${RUNTIME_ID:-}" ]; then
    log "Exact runtime $OS_FAMILY $OS_REQ not found, falling back to latest available."
    RUNTIME_ID="$(xcrun simctl list -j runtimes \
      | jq -r --arg f "$OS_FAMILY" '.runtimes[]|select(.platform==$f and .isAvailable==true)|.identifier' \
      | sort -Vr | head -n1)"
  fi
fi

[ -n "${RUNTIME_ID:-}" ] || { xcrun simctl list runtimes; fail "No $OS_FAMILY runtime available after download."; }
log "Using runtime: $RUNTIME_ID"

# If a device with that NAME & runtime exists and is available, we're done.
if xcrun simctl list -j devices available \
  | jq -e --arg r "$RUNTIME_ID" --arg n "$NAME_REQ" '.devices[$r][]?|select(.name==$n and .isAvailable==true)' >/dev/null; then
  log "Device '$NAME_REQ' for runtime '$RUNTIME_ID' already exists."
  exit 0
fi

# Otherwise, create the device. Find device type identifier by name, else pick a sensible default by platform.
DEVTYPE_ID="$(xcrun simctl list -j devicetypes | jq -r --arg n "$NAME_REQ" '.devicetypes[]|select(.name==$n)|.identifier' | head -n1 || true)"
if [ -z "${DEVTYPE_ID:-}" ]; then
  case "$OS_FAMILY" in
    iOS)
      # Prefer the newest iPhone type if exact name not found
      DEVTYPE_ID="$(xcrun simctl list -j devicetypes | jq -r '.devicetypes[]|select(.name|test("iPhone"))|.identifier' | sort -Vr | head -n1)"
      [ -n "$DEVTYPE_ID" ] || DEVTYPE_ID="com.apple.CoreSimulator.SimDeviceType.iPhone-16"
      ;;
    tvOS)
      DEVTYPE_ID="$(xcrun simctl list -j devicetypes | jq -r '.devicetypes[]|select(.name|test("Apple TV"))|.identifier' | sort -Vr | head -n1)"
      [ -n "$DEVTYPE_ID" ] || DEVTYPE_ID="com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation"
      ;;
    visionOS)
      DEVTYPE_ID="$(xcrun simctl list -j devicetypes | jq -r '.devicetypes[]|select(.name|test("Apple Vision"))|.identifier' | sort -Vr | head -n1)"
      [ -n "$DEVTYPE_ID" ] || DEVTYPE_ID="com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro"
      ;;
  esac
fi

log "Creating device '$NAME_REQ' (type=$DEVTYPE_ID, runtime=$RUNTIME_ID)…"
xcrun simctl create "$NAME_REQ" "$DEVTYPE_ID" "$RUNTIME_ID" >/dev/null

# Verify
if xcrun simctl list -j devices available \
  | jq -e --arg r "$RUNTIME_ID" --arg n "$NAME_REQ" '.devices[$r][]?|select(.name==$n and .isAvailable==true)' >/dev/null; then
  log "Device created and available."
  exit 0
else
  xcrun simctl list devices | sed -n "1,120p"
  fail "Device '$NAME_REQ' could not be created or is not available."
fi