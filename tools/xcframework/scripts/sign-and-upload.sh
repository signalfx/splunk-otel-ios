#!/bin/bash
# tools/xcframework/scripts/sign-and-upload.sh
#
# Local signing workflow: downloads unsigned xcframeworks from CI,
# signs them with a local certificate, validates, packages, and
# uploads to an existing GitHub release.
#
# This is a temporary replacement for the automated CI signing job
# (Job 2 in build-xcframeworks.yml) while distribution certificates
# cannot be stored in GitHub secrets.
#
# Prerequisites:
#   - gh CLI installed and authenticated (brew install gh)
#   - Apple distribution certificate in your local keychain
#   - The build-xcframeworks CI workflow must have completed successfully
#
# Usage:
#   ./scripts/sign-and-upload.sh VERSION [OPTIONS]
#
# Options:
#   --run-id ID        GitHub Actions run ID to download artifact from
#                      (default: latest successful build-xcframeworks run)
#   --identity NAME    Signing identity (default: auto-detected)
#   --skip-upload      Sign and package only, don't upload to GitHub
#   --skip-cisco-refresh  Keep Cisco xcframeworks from CI artifact as-is
#                         (default: refresh from source to preserve vendor signatures)
#
# Examples:
#   ./scripts/sign-and-upload.sh 1.2.0
#   ./scripts/sign-and-upload.sh 1.2.0 --run-id 12345678
#   ./scripts/sign-and-upload.sh 1.2.0 --identity "Apple Distribution: Splunk Inc. (TEAMID)"
#   ./scripts/sign-and-upload.sh 1.2.0 --skip-upload
#   ./scripts/sign-and-upload.sh 1.2.0 --skip-cisco-refresh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

VERSION="${1:-}"
RUN_ID=""
SIGNING_IDENTITY=""
SKIP_UPLOAD=false
REFRESH_CISCO=true

if [[ -z "${VERSION}" ]]; then
    echo "ERROR: Version required."
    echo "  Usage: $0 VERSION [--run-id ID] [--identity NAME] [--skip-upload] [--skip-cisco-refresh]"
    exit 1
fi

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-id) RUN_ID="$2"; shift 2 ;;
        --identity) SIGNING_IDENTITY="$2"; shift 2 ;;
        --skip-upload) SKIP_UPLOAD=true; shift ;;
        --skip-cisco-refresh) REFRESH_CISCO=false; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

log() {
    echo ""
    echo "==> $*"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------

log "Preflight checks"

if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not installed. Install with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "ERROR: gh CLI not authenticated. Run: gh auth login"
    exit 1
fi

echo "  ✓ gh CLI authenticated"

# ---------------------------------------------------------------------------
# Step 1: Resolve signing identity
# ---------------------------------------------------------------------------

log "Resolving signing identity"

if [[ -z "${SIGNING_IDENTITY}" ]]; then
    # Auto-detect: pick the first valid codesigning identity
    RAW="$(security find-identity -v -p codesigning)"
    SIGNING_IDENTITY="$(echo "${RAW}" | grep '"' | head -1 | sed 's/.*"\(.*\)".*/\1/')"

    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        echo "ERROR: No codesigning identity found in keychain."
        echo "  Available identities:"
        security find-identity -v -p codesigning
        echo ""
        echo "  Provide one explicitly with --identity"
        exit 1
    fi
fi

echo "  Using identity: ${SIGNING_IDENTITY}"

# ---------------------------------------------------------------------------
# Step 2: Download unsigned xcframeworks from CI
# ---------------------------------------------------------------------------

log "Downloading unsigned xcframeworks from CI"

# Clean output directory
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

ARTIFACT_NAME="splunk-agent-xcframeworks-unsigned"

if [[ -n "${RUN_ID}" ]]; then
    echo "  Downloading from run ID: ${RUN_ID}"
    gh run download "${RUN_ID}" \
        -n "${ARTIFACT_NAME}" \
        -D "${OUTPUT_DIR}" \
        -R "$(cd "${REPO_ROOT}" && gh repo view --json nameWithOwner -q .nameWithOwner)" 2>&1
else
    echo "  Finding latest successful build-xcframeworks run..."
    RUN_ID="$(cd "${REPO_ROOT}" && gh run list \
        --workflow=build-xcframeworks.yml \
        --status=success \
        --limit=1 \
        --json databaseId \
        -q '.[0].databaseId')"

    if [[ -z "${RUN_ID}" || "${RUN_ID}" == "null" ]]; then
        echo "ERROR: No successful build-xcframeworks run found."
        echo "  Trigger a build first or provide a run ID with --run-id"
        exit 1
    fi

    echo "  Downloading from latest run: ${RUN_ID}"
    (cd "${REPO_ROOT}" && gh run download "${RUN_ID}" \
        -n "${ARTIFACT_NAME}" \
        -D "${OUTPUT_DIR}")
fi

# Verify download
XCFW_COUNT="$(find "${OUTPUT_DIR}" -name "*.xcframework" -maxdepth 1 -type d | wc -l | tr -d ' ')"
if [[ "${XCFW_COUNT}" -eq 0 ]]; then
    echo "ERROR: No xcframeworks found after download."
    echo "  Contents of ${OUTPUT_DIR}:"
    ls -la "${OUTPUT_DIR}"
    exit 1
fi

echo "  ✓ Downloaded ${XCFW_COUNT} xcframeworks"

# ---------------------------------------------------------------------------
# Step 2b: Refresh Cisco xcframeworks from source (default)
# ---------------------------------------------------------------------------
# Cisco frameworks are pre-built external artifacts. Refreshing them from
# source ensures we package untouched vendor binaries/signatures.

if [[ "${REFRESH_CISCO}" == "true" ]]; then
    log "Refreshing Cisco xcframeworks from source"

    # Remove Cisco frameworks from downloaded artifact first.
    rm -rf "${OUTPUT_DIR}"/Cisco*.xcframework

    # Download fresh Cisco frameworks directly from URLs/checksums in Package.swift.
    "${SCRIPT_DIR}/download-cisco-xcframeworks.sh" --output-dir "${OUTPUT_DIR}"
else
    log "Skipping Cisco refresh (--skip-cisco-refresh)"
fi

# ---------------------------------------------------------------------------
# Step 3: Sign
# ---------------------------------------------------------------------------

log "Signing xcframeworks"

"${SCRIPT_DIR}/sign-xcframeworks.sh" "${SIGNING_IDENTITY}"

# ---------------------------------------------------------------------------
# Step 4: Validate (post-signing)
# ---------------------------------------------------------------------------

log "Validating signed xcframeworks"

RELEASE=true "${SCRIPT_DIR}/validate-xcframeworks.sh"

# ---------------------------------------------------------------------------
# Step 5: Package and upload
# ---------------------------------------------------------------------------

if [[ "${SKIP_UPLOAD}" == "true" ]]; then
    log "Packaging (upload skipped)"
    "${SCRIPT_DIR}/release.sh" "${VERSION}"
else
    log "Packaging and uploading to release ${VERSION}"
    "${SCRIPT_DIR}/release.sh" "${VERSION}" --upload-to "${VERSION}"
fi

echo ""
echo "============================================================"
echo "  Local Signing Complete"
echo "============================================================"
echo "  Version:   ${VERSION}"
echo "  Identity:  ${SIGNING_IDENTITY}"
echo "  CI Run:    ${RUN_ID}"
if [[ "${SKIP_UPLOAD}" == "true" ]]; then
    echo "  Upload:    skipped (use without --skip-upload to upload)"
else
    echo "  Upload:    ✓ attached to release ${VERSION}"
fi
echo ""
