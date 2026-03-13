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

WORKSPACE="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
DESTINATIONS_TEXT=""
SHOWDESTINATIONS_STDERR="$(mktemp)"
cleanup() {
  rm -f "$SHOWDESTINATIONS_STDERR"
}
trap cleanup EXIT

if DESTINATIONS_TEXT="$(
  xcodebuild -skipPackagePluginValidation -workspace "$WORKSPACE" -scheme "$SCHEME" -showdestinations 2>"$SHOWDESTINATIONS_STDERR"
)"; then
  if [ -s "$SHOWDESTINATIONS_STDERR" ]; then
    echo "::notice::[resolve-destinations] xcodebuild -showdestinations emitted non-fatal stderr output"
    echo "::group::[resolve-destinations] xcodebuild -showdestinations stderr"
    cat "$SHOWDESTINATIONS_STDERR"
    echo "::endgroup::"
  fi
else
  SHOWDESTINATIONS_STATUS=$?
  echo "::warning::[resolve-destinations] xcodebuild -showdestinations failed for scheme '$SCHEME' (exit $SHOWDESTINATIONS_STATUS); falling back when needed"
  if [ -n "${DESTINATIONS_TEXT:-}" ]; then
    echo "::group::[resolve-destinations] xcodebuild -showdestinations stdout"
    printf '%s\n' "$DESTINATIONS_TEXT"
    echo "::endgroup::"
  fi
  if [ -s "$SHOWDESTINATIONS_STDERR" ]; then
    echo "::group::[resolve-destinations] xcodebuild -showdestinations stderr"
    cat "$SHOWDESTINATIONS_STDERR"
    echo "::endgroup::"
  fi
fi

pick_from_scheme_destinations() {
  local platform="$1"
  shift
  local name_patterns=("${@}")
  local candidates=""
  local pattern=""
  local pick=""

  # Output format: "<name>|<os_version>"
  candidates="$(
    printf '%s\n' "$DESTINATIONS_TEXT" \
    | awk -v plat="$platform" '
        /\{[[:space:]]*platform:/ {
          line = $0
          gsub(/^[[:space:]]+/, "", line)
          if (line !~ ("platform:" plat) || line ~ /error:/ || line !~ /OS:/ || line !~ /name:/) {
            next
          }

          os = line
          sub(/.*OS:/, "", os)
          sub(/,.*/, "", os)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", os)

          name = line
          sub(/.*name:/, "", name)
          sub(/[},].*/, "", name)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)

          if (os ~ /^[0-9]+(\.[0-9]+)*$/) {
            print name "|" os
          }
        }
      ' \
  )"

  for pattern in "${name_patterns[@]}"; do
    pick="$(
      printf '%s\n' "$candidates" \
        | awk -F '|' -v pat="$pattern" '$1 ~ pat { print }' \
        | sort -t '|' -k2,2V \
        | tail -n1
    )"
    if [ -n "${pick:-}" ]; then
      printf '%s\n' "$pick"
      return 0
    fi
  done

  return 0
}

pick_name_and_runtime_from_devices() {
  local runtime_prefix="$1"
  shift
  local name_patterns=("${@}")
  local candidates=""
  local pattern=""
  local pick=""

  candidates="$(
    xcrun simctl list -j devices available \
      | jq -r --arg prefix "$runtime_prefix" '
        .devices
        | to_entries
        | map(
            select(.key | startswith("com.apple.CoreSimulator.SimRuntime." + $prefix + "-"))
            | . as $runtime
            | .value[]
            | select(.isAvailable==true)
            | {
                runtime: $runtime.key,
                version: ($runtime.key | sub("^com.apple.CoreSimulator.SimRuntime\\." + $prefix + "-"; "") | gsub("-"; ".")),
                name: .name
              }
          )
        | sort_by(.version | split(".") | map((tonumber? // 0)))
        | .[]
        | "\(.name)|\(.runtime)|\(.version)"
      '
  )"

  for pattern in "${name_patterns[@]}"; do
    pick="$(
      printf '%s\n' "$candidates" \
        | awk -F '|' -v pat="$pattern" '$1 ~ pat { print }' \
        | tail -n1
    )"
    if [ -n "${pick:-}" ]; then
      printf '%s\n' "$pick"
      return 0
    fi
  done

  return 0
}

IOS_PICK="$(pick_from_scheme_destinations 'iOS Simulator' 'iPhone' 'iPad')"
if [ -n "${IOS_PICK:-}" ]; then
  IFS='|' read -r IOS_NAME IOS_OS_VERSION <<< "$IOS_PICK"
  IOS_DEST="platform=iOS Simulator,OS=$IOS_OS_VERSION,name=$IOS_NAME"
  echo "::notice::[resolve-destinations] Using scheme-aware iOS simulator destination: $IOS_DEST"
else
  echo "::notice::[resolve-destinations] No scheme-aware iOS simulator destination matched iPhone/iPad; falling back to simctl"
  IOS_PICK="$(pick_name_and_runtime_from_devices 'iOS' 'iPhone' 'iPad')"
  if [ -n "${IOS_PICK:-}" ]; then
    IFS='|' read -r IOS_NAME _IOS_RUNTIME_ID IOS_OS_VERSION <<< "$IOS_PICK"
    IOS_DEST="platform=iOS Simulator,OS=$IOS_OS_VERSION,name=$IOS_NAME"
  else
    echo "::warning::[resolve-destinations] No available iOS simulator found; using default iPhone 16 destination"
    IOS_DEST="platform=iOS Simulator,name=iPhone 16"
  fi
fi

TVOS_PICK="$(pick_from_scheme_destinations 'tvOS Simulator' 'Apple TV')"
if [ -n "${TVOS_PICK:-}" ]; then
  IFS='|' read -r TVOS_NAME TVOS_OS_VERSION <<< "$TVOS_PICK"
  TVOS_DEST="platform=tvOS Simulator,OS=$TVOS_OS_VERSION,name=$TVOS_NAME"
  echo "::notice::[resolve-destinations] Using scheme-aware tvOS simulator destination: $TVOS_DEST"
else
  echo "::notice::[resolve-destinations] No scheme-aware tvOS simulator destination matched Apple TV; falling back to simctl"
  TVOS_PICK="$(pick_name_and_runtime_from_devices 'tvOS' 'Apple TV')"
  if [ -n "${TVOS_PICK:-}" ]; then
    IFS='|' read -r TVOS_NAME _TVOS_RUNTIME_ID TVOS_OS_VERSION <<< "$TVOS_PICK"
    TVOS_DEST="platform=tvOS Simulator,OS=$TVOS_OS_VERSION,name=$TVOS_NAME"
  else
    echo "::warning::[resolve-destinations] No available tvOS simulator found; using default Apple TV 4K (3rd generation) destination"
    TVOS_DEST="platform=tvOS Simulator,name=Apple TV 4K (3rd generation)"
  fi
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
