#!/bin/bash
# tools/xcframework/scripts/refresh-cisco-xcframeworks.sh
#
# Replaces Cisco xcframeworks in a directory with freshly downloaded copies
# resolved from Package.swift. This is used by release flows to ensure we
# package untouched vendor-signed artifacts rather than copies that may have
# lost signature metadata during artifact transport.
#
# Usage:
#   ./scripts/refresh-cisco-xcframeworks.sh [--output-dir DIR]
#   ./scripts/refresh-cisco-xcframeworks.sh [--output-dir DIR] [--manifest PATH]
#   ./scripts/refresh-cisco-xcframeworks.sh [--output-dir DIR] [--package-swift PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"
MANIFEST_PATH=""
PACKAGE_SWIFT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --manifest)
            MANIFEST_PATH="$2"
            shift 2
            ;;
        --package-swift)
            PACKAGE_SWIFT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

log() {
    echo "==> $*"
}

resolve_manifest_path() {
    if [[ -n "${MANIFEST_PATH}" ]]; then
        echo "${MANIFEST_PATH}"
        return
    fi

    local default_manifest="${OUTPUT_DIR}/cisco-release-manifest.txt"
    if [[ -f "${default_manifest}" ]]; then
        echo "${default_manifest}"
    fi
}

log "Refreshing Cisco xcframeworks in ${OUTPUT_DIR}"

RESOLVED_MANIFEST="$(resolve_manifest_path)"

DOWNLOAD_ARGS=(--output-dir "${OUTPUT_DIR}")
if [[ -n "${RESOLVED_MANIFEST}" ]]; then
    log "Using Cisco manifest ${RESOLVED_MANIFEST}"
    DOWNLOAD_ARGS+=(--manifest "${RESOLVED_MANIFEST}")
elif [[ -n "${PACKAGE_SWIFT}" ]]; then
    log "Using Package.swift at ${PACKAGE_SWIFT}"
    DOWNLOAD_ARGS+=(--package-swift "${PACKAGE_SWIFT}")
else
    echo "ERROR: No Cisco manifest found in ${OUTPUT_DIR} and no --package-swift provided."
    echo "  Expected manifest: ${OUTPUT_DIR}/cisco-release-manifest.txt"
    exit 1
fi

rm -rf "${OUTPUT_DIR}"/Cisco*.xcframework

"${SCRIPT_DIR}/download-cisco-xcframeworks.sh" "${DOWNLOAD_ARGS[@]}"
