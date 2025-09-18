#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_OUTPUT:?}"
echo "[resolve-destinations] inputs: WORKSPACE=${WORKSPACE:-.swiftpm/xcode/package.xcworkspace} SCHEME=${SCHEME:?}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
SCHEME="${SCHEME:?}"
command -v jq >/dev/null 2>&1 || { brew update && brew install -q jq; }
SHOW="$(xcodebuild -showdestinations -workspace "$WS" -scheme "$SCHEME" -json 2>/dev/null | sed -n '/^{/,$p' || true)"

json='[]'
add_row() { json="$(jq -cn --arg p "$1" --arg d "$2" --argjson arr "$json" '$arr + [{platform:$p, destination:$d}]')"; }
pick() { echo "$SHOW" | jq -r '.destinations[]? | select(.platform=="'"$1"'" and .available=="YES") | .id' | head -n1; }

did="$(pick 'iOS Simulator' || true)"
if [ -n "${did:-}" ] && [ "$did" != "null" ]; then
  add_row ios "id=$did"
else
  id="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("iPhone|iPad"))).udid' | head -n1 || true)"
  if [ -n "${id:-}" ]; then add_row ios "platform=iOS Simulator,id=$id"; else add_row ios "platform=iOS Simulator,OS=latest,name=iPhone 16"; fi
fi

did="$(pick 'tvOS Simulator' || true)"
if [ -n "${did:-}" ] && [ "$did" != "null" ]; then
  add_row tvos "id=$did"
else
  id="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("Apple TV"))).udid' | head -n1 || true)"
  if [ -n "${id:-}" ]; then add_row tvos "platform=tvOS Simulator,id=$id"; else add_row tvos "platform=tvOS Simulator,OS=latest,name=Apple TV 4K (3rd generation)"; fi
fi

did="$(pick 'visionOS Simulator' || true)"
if [ -n "${did:-}" ] && [ "$did" != "null" ]; then
  add_row visionos "id=$did"
else
  id="$(xcrun simctl list -j devices available | jq -r '.devices[]|.[]|select(.isAvailable==true and (.name|test("Apple Vision"))).udid' | head -n1 || true)"
  if [ -n "${id:-}" ]; then add_row visionos "platform=visionOS Simulator,id=$id"; else add_row visionos "platform=visionOS Simulator,OS=latest,name=Apple Vision Pro"; fi
fi

add_row macCatalyst "platform=macOS,variant=Mac Catalyst"

BUILD_INCLUDE="$(echo "$json" | jq -c '.')"
TEST_INCLUDE="$(echo "$json" | jq -c '[.[] | select(.platform=="ios")]')"

BUILD_MATRIX="$(jq -c --argjson inc "$BUILD_INCLUDE" '{include:$inc}')"
TEST_MATRIX="$(jq -c --argjson inc "$TEST_INCLUDE"  '{include:$inc}')"

printf 'build_matrix=%s\n' "$BUILD_MATRIX" >> "$GITHUB_OUTPUT"
printf 'test_matrix=%s\n'  "$TEST_MATRIX"  >> "$GITHUB_OUTPUT"

echo "[resolve-destinations] outputs: build_matrix=$BUILD_INCLUDE"
echo "[resolve-destinations] outputs: test_matrix=$TEST_INCLUDE"
