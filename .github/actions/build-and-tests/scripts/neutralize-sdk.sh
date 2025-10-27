#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_ENV:?}"
echo "[neutralize-sdk] no inputs"
printf 'MD_APPLE_SDK_ROOT=\n' >> "$GITHUB_ENV"
echo "[neutralize-sdk] outputs: MD_APPLE_SDK_ROOT unset"