#!/usr/bin/env bash
set -euo pipefail
echo "[build] inputs: WORKSPACE=${WORKSPACE:-.swiftpm/xcode/package.xcworkspace} SCHEME=${SCHEME:?} DESTINATION=${DESTINATION:?} CONFIGURATION=${CONFIGURATION:-Debug}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
SCHEME="${SCHEME:?}"
DESTINATION="${DESTINATION:?}"
CONFIG="${CONFIGURATION:-Debug}"

xcodebuild -workspace "$WS" -scheme "$SCHEME" -destination "$DESTINATION" -configuration "$CONFIG" -skipPackagePluginValidation clean build