#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_OUTPUT:?}"
echo "[test] inputs: WORKSPACE=${WORKSPACE:-.swiftpm/xcode/package.xcworkspace} SCHEME=${SCHEME:?} DESTINATION=${DESTINATION:?} OUT_DIR=${OUT_DIR:-reports}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
SCHEME="${SCHEME:?}"
DESTINATION="${DESTINATION:?}"
OUT_DIR="${OUT_DIR:-reports}"

mkdir -p "$OUT_DIR"
command -v xcbeautify >/dev/null 2>&1 || { brew update && brew install -q xcbeautify; }
LOG="$OUT_DIR/xcodebuild-ios.log"
JUNIT="$OUT_DIR/junit-ios.xml"
XCRESULT="${XCRESULT_PATH:-TestResults_iOS.xcresult}"

set +e
xcodebuild -workspace "$WS" -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$XCRESULT" clean test 2>&1 | tee "$LOG" | xcbeautify --report junit --junit-report-filename "$(basename "$JUNIT")" --report-path "$OUT_DIR"
STATUS=${PIPESTATUS[0]}
set -e

printf 'xcode_status=%s\n' "$STATUS" >> "$GITHUB_OUTPUT"
echo "[test] outputs: xcode_status=$STATUS"