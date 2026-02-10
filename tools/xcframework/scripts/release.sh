#!/bin/bash
# tools/xcframework/scripts/release.sh
#
# Packages all built xcframeworks into a zip archive and optionally
# uploads to GitHub releases.
#
# Usage:
#   ./scripts/release.sh VERSION [--upload]
#
# Options:
#   --upload    Upload to GitHub releases using `gh` CLI
#               (requires GITHUB_TOKEN or `gh auth login`)
#
# Prerequisites:
#   - All xcframeworks built in output/xcframeworks/
#   - dependency-manifest.json generated
#   - gh CLI installed (only for --upload)
#
# Output:
#   output/SplunkAgent-xcframeworks-VERSION.zip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output"
XCFW_DIR="${OUTPUT_DIR}/xcframeworks"

VERSION="${1:-}"
UPLOAD=false

if [[ -z "${VERSION}" ]]; then
    echo "ERROR: Version required."
    echo "  Usage: $0 VERSION [--upload]"
    exit 1
fi

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --upload) UPLOAD=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

log() {
    echo "==> $*"
}

ZIP_NAME="SplunkAgent-xcframeworks-${VERSION}.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

# ---------------------------------------------------------------------------
# Step 1: Generate dependency manifest
# ---------------------------------------------------------------------------

log "Generating dependency manifest..."
"${SCRIPT_DIR}/generate-dependency-manifest.sh" --version "${VERSION}"


# ---------------------------------------------------------------------------
# Step 2: Package into zip
# ---------------------------------------------------------------------------

log "Packaging xcframeworks into ${ZIP_NAME}..."

# Remove existing zip
rm -f "${ZIP_PATH}"

# Create zip from the xcframeworks directory
# Include the manifest alongside the xcframeworks
cd "${OUTPUT_DIR}"
zip -r -y "${ZIP_NAME}" \
    xcframeworks/*.xcframework \
    dependency-manifest.json \
    -x "*.DS_Store"

ZIP_SIZE="$(du -sh "${ZIP_PATH}" | cut -f1)"
log "Package created: ${ZIP_PATH} (${ZIP_SIZE})"


# ---------------------------------------------------------------------------
# Step 3: Upload to GitHub (optional)
# ---------------------------------------------------------------------------

if [[ "${UPLOAD}" == "true" ]]; then
    log "Uploading to GitHub releases..."

    if ! command -v gh &> /dev/null; then
        echo "ERROR: gh CLI not installed. Install with: brew install gh"
        exit 1
    fi

    REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"
    cd "${REPO_ROOT}"

    # Create release and upload asset
    gh release create "v${VERSION}" \
        --title "v${VERSION}" \
        --notes "SplunkAgent iOS SDK v${VERSION} - XCFramework distribution" \
        "${ZIP_PATH}"

    log "Release v${VERSION} created and asset uploaded ✓"
else
    log "Skipping upload (use --upload to upload to GitHub releases)"
fi


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "============================================================"
echo "  Release Package Ready"
echo "============================================================"
echo "  Version:  ${VERSION}"
echo "  Package:  ${ZIP_PATH}"
echo "  Size:     ${ZIP_SIZE}"
echo ""
echo "Contents:"
unzip -l "${ZIP_PATH}" | grep "\.xcframework/" | awk '{print "  " $NF}' | sed 's|xcframeworks/||' | sort -u | head -30
echo ""
