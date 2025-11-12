#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_OUTPUT:?}"
echo "[test] inputs: WORKSPACE=${WORKSPACE:-.swiftpm/xcode/package.xcworkspace} SCHEME=${SCHEME:?} DESTINATION=${DESTINATION:?} OUT_DIR=${OUT_DIR:-reports} PLATFORM=${PLATFORM:-ios}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
SCHEME="${SCHEME:?}"
DESTINATION="${DESTINATION:?}"
OUT_DIR="${OUT_DIR:-reports}"
PLATFORM="${PLATFORM:-ios}"

mkdir -p "$OUT_DIR"
command -v xcbeautify >/dev/null 2>&1 || { brew update && brew install -q xcbeautify; }
LOG="$OUT_DIR/xcodebuild-${PLATFORM}.log"
JUNIT="$OUT_DIR/junit-${PLATFORM}.xml"
XCRESULT="${XCRESULT_PATH:-TestResults_${PLATFORM}.xcresult}"

xcodebuild -skipPackagePluginValidation -testPlan "SplunkAgent" -workspace "$WS" -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$XCRESULT" clean test 2>&1 | tee "$LOG" | xcbeautify --report junit --junit-report-filename "$(basename "$JUNIT")" --report-path "$OUT_DIR"
