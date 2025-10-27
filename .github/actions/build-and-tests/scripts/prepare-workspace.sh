#!/usr/bin/env bash
set -euo pipefail
echo "[prepare-workspace] no inputs"
xcodebuild -resolvePackageDependencies
xed -b .
echo "[prepare-workspace] outputs: workspace prepared"