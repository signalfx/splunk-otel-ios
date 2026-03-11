#!/bin/bash
# tools/xcframework/scripts/generate-cisco-release-manifest.sh
#
# Snapshots the Cisco binary target registry used by a build into a manifest
# file that travels with the unsigned xcframework artifact. Release signing can
# then refresh Cisco xcframeworks from the exact URLs/checksums used for the
# original build, even when signing happens later from another checkout.
#
# Manifest format:
#   source_commit=<git sha>
#   generated_at=<utc timestamp>
#   <name>|<url>|<checksum>
#
# Usage:
#   ./scripts/generate-cisco-release-manifest.sh [--output-dir DIR]
#   ./scripts/generate-cisco-release-manifest.sh [--output-dir DIR] [--package-swift PATH]
#   ./scripts/generate-cisco-release-manifest.sh [--output-dir DIR] [--source-commit SHA]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"

OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"
PACKAGE_SWIFT="${REPO_ROOT}/Package.swift"
SOURCE_COMMIT=""
MANIFEST_NAME="cisco-release-manifest.txt"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --package-swift)
            PACKAGE_SWIFT="$2"
            shift 2
            ;;
        --source-commit)
            SOURCE_COMMIT="$2"
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

parse_registry() {
    if [[ ! -f "${PACKAGE_SWIFT}" ]]; then
        echo "ERROR: Package.swift not found at ${PACKAGE_SWIFT}" >&2
        exit 1
    fi

    awk '
        /BinaryTargetInfo\(/ { in_block=1; name=""; url=""; checksum="" }
        in_block && /name:/ {
            s = $0
            gsub(/.*name:[[:space:]]*"/, "", s)
            gsub(/".*/, "", s)
            name = s
        }
        in_block && /url:/ {
            s = $0
            gsub(/.*url:[[:space:]]*"/, "", s)
            gsub(/".*/, "", s)
            url = s
        }
        in_block && /checksum:/ {
            s = $0
            gsub(/.*checksum:[[:space:]]*"/, "", s)
            gsub(/".*/, "", s)
            checksum = s
        }
        in_block && /\)/ {
            if (name != "" && url != "" && checksum != "") {
                print name "|" url "|" checksum
            }
            in_block=0
        }
    ' "${PACKAGE_SWIFT}"
}

if [[ -z "${SOURCE_COMMIT}" ]]; then
    SOURCE_COMMIT="$(cd "${REPO_ROOT}" && git rev-parse HEAD)"
fi

mkdir -p "${OUTPUT_DIR}"
MANIFEST_PATH="${OUTPUT_DIR}/${MANIFEST_NAME}"
REGISTRY_ENTRIES="$(parse_registry)"

if [[ -z "${REGISTRY_ENTRIES}" ]]; then
    echo "ERROR: No Cisco BinaryTargetInfo entries found in ${PACKAGE_SWIFT}"
    exit 1
fi

log "Generating Cisco release manifest at ${MANIFEST_PATH}"

{
    echo "source_commit=${SOURCE_COMMIT}"
    echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "${REGISTRY_ENTRIES}"
} > "${MANIFEST_PATH}"

ENTRY_COUNT="$(printf '%s\n' "${REGISTRY_ENTRIES}" | wc -l | tr -d ' ')"
log "Captured ${ENTRY_COUNT} Cisco entries from ${PACKAGE_SWIFT}"
