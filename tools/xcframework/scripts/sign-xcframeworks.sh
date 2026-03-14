#!/bin/bash
# tools/xcframework/scripts/sign-xcframeworks.sh
#
# Signs .xcframework bundles in the output directory using codesign.
# Signing protects all files inside the xcframework including privacy manifests.
# Cisco Session Replay xcframeworks are vendor-signed externals and are
# intentionally skipped to preserve the upstream signature that release
# validation later verifies.
#
# Usage:
#   ./scripts/sign-xcframeworks.sh "Apple Distribution: Splunk Inc. (TEAMID)"
#
# The signing identity must be available in the keychain. For CI, the
# identity is typically imported from a certificate stored in CI secrets.
#
# Reference: WWDC 2023 "Verify app dependencies with digital signatures"
# https://developer.apple.com/videos/play/wwdc2023/10061/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

SIGNING_IDENTITY="${1:-}"

if [[ -z "${SIGNING_IDENTITY}" ]]; then
    echo "ERROR: Signing identity required."
    echo "  Usage: $0 \"Apple Distribution: Splunk Inc. (TEAMID)\""
    exit 1
fi

log() {
    echo "==> $*"
}

is_vendor_signed_xcframework() {
    local name="$1"
    [[ "${name}" == Cisco*.xcframework ]]
}

log "Signing xcframeworks with identity: ${SIGNING_IDENTITY}"

SIGN_CISCO_FRAMEWORKS="${SIGN_CISCO_FRAMEWORKS:-false}"

SIGNED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for xcfw in "${OUTPUT_DIR}"/*.xcframework; do
    [[ -d "${xcfw}" ]] || continue
    name="$(basename "${xcfw}")"

    if [[ "${SIGN_CISCO_FRAMEWORKS}" != "true" ]] && is_vendor_signed_xcframework "${name}"; then
        echo "  Skipping ${name} (pre-signed external framework)"
        ((SKIPPED_COUNT++))
        continue
    fi

    echo -n "  Signing ${name}..."

    error_log="$(mktemp /tmp/sign-xcframeworks.XXXXXX.log)"
    if codesign --force --timestamp -v --sign "${SIGNING_IDENTITY}" "${xcfw}" 2>"${error_log}"; then
        echo " ✓"
        ((SIGNED_COUNT++))
        rm -f "${error_log}"
    else
        echo " FAILED"
        if [[ -s "${error_log}" ]]; then
            sed 's/^/    /' "${error_log}"
        fi
        rm -f "${error_log}"
        ((FAILED_COUNT++))
    fi
done

echo ""
log "Signed: ${SIGNED_COUNT}, Skipped: ${SKIPPED_COUNT}, Failed: ${FAILED_COUNT}"

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
    echo "ERROR: ${FAILED_COUNT} xcframeworks failed to sign."
    exit 1
fi
