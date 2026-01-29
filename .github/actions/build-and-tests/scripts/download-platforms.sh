#!/usr/bin/env bash
set -euo pipefail

# Xcode 26+ no longer bundles iOS/tvOS/visionOS SDKs.
# They must be downloaded separately before simulators are available.

PLATFORMS=("${@-}")
if [ ${#PLATFORMS[@]} -eq 0 ] || [ -z "${PLATFORMS[0]}" ]; then
  PLATFORMS=(iOS tvOS visionOS)
fi

FAILED=()
for p in "${PLATFORMS[@]}"; do
  echo "[download-platforms] Downloading $p platform SDK..."
  if ! xcodebuild -downloadPlatform "$p"; then
    echo "::warning::[download-platforms] Failed to download $p (exit $?). Build for this platform may fail."
    FAILED+=("$p")
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "[download-platforms] Warning: failed to download: ${FAILED[*]}"
fi

echo "[download-platforms] Done."
