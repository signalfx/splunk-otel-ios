#!/usr/bin/env bash
set -euo pipefail

# Xcode 26+ no longer bundles iOS/tvOS/visionOS SDKs.
# They must be downloaded separately before simulators are available.

PLATFORMS=("${@-}")
if [ ${#PLATFORMS[@]} -eq 0 ] || [ -z "${PLATFORMS[0]}" ]; then
  PLATFORMS=(iOS tvOS visionOS)
fi

for p in "${PLATFORMS[@]}"; do
  echo "[download-platforms] Downloading $p platform SDK..."
  xcodebuild -downloadPlatform "$p"
done

echo "[download-platforms] Done."
