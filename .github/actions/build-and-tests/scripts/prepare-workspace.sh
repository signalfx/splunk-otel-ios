#!/usr/bin/env bash
set -euo pipefail
echo "[prepare-workspace] no inputs"
xcodebuild -resolvePackageDependencies

# Only open Xcode if not in CI environment
if [ -z "${CI:-}" ]; then
  xed -b . 2>/dev/null || echo "[prepare-workspace] Skipping xed (not in GUI environment)"
else
  echo "[prepare-workspace] Skipping xed in CI environment"
fi

echo "[prepare-workspace] outputs: workspace prepared"