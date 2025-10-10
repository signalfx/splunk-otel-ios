#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_OUTPUT:?}"
echo "[prepare-scheme] inputs: WORKSPACE=${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"

WS="${WORKSPACE:-.swiftpm/xcode/package.xcworkspace}"
RAW="$(xcodebuild -list -workspace "$WS" -json 2>/dev/null | sed -n '/^{/,$p' || true)"

if [ -n "$RAW" ] && command -v jq >/dev/null 2>&1 && echo "$RAW" | jq -e '.workspace.schemes | length > 0' >/dev/null 2>&1; then
  NAME="$(echo "$RAW" | jq -r '.workspace.schemes[] | select(test("-Package$"))' | head -n1)"
  if [ -z "${NAME:-}" ] || [ "$NAME" = "null" ]; then
    NAME="$(echo "$RAW" | jq -r '.workspace.schemes[0]')"
  fi
else
  PKG="$(swift package describe --type json 2>/dev/null | jq -r '.name' || true)"
  NAME="${PKG}-Package"
fi

printf 'scheme=%s\n' "$NAME" >> "$GITHUB_OUTPUT"
echo "[prepare-scheme] outputs: scheme=$NAME"