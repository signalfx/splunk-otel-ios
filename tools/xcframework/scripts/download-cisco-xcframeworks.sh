#!/bin/bash
# tools/xcframework/scripts/download-cisco-xcframeworks.sh
#
# Downloads Cisco Session Replay xcframeworks by parsing the
# SessionReplayBinaryRegistry in Package.swift.
#
# Each registry entry has a `name` (e.g. "CiscoLogger") and a `url`
# pointing to a zip on S3 that contains <Name>.xcframework/.
#
# Usage:
#   ./scripts/download-cisco-xcframeworks.sh [--output-dir DIR]
#
# Options:
#   --output-dir DIR  Where to place extracted xcframeworks
#                     (default: dependencies/)
#   --package-swift PATH  Path to Package.swift
#                         (default: ../../Package.swift relative to tools/xcframework)
#
# The script:
#   1. Parses Package.swift for BinaryTargetInfo entries (name + url)
#   2. Downloads each zip (with checksum verification)
#   3. Extracts the xcframework from the zip
#   4. Places it in the output directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"

OUTPUT_DIR="${TOOLS_ROOT}/dependencies"
PACKAGE_SWIFT="${REPO_ROOT}/Package.swift"
DOWNLOAD_CACHE="${TOOLS_ROOT}/build/cisco-downloads"


# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

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
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    echo "==> $*"
}


# ---------------------------------------------------------------------------
# Step 1: Parse Package.swift for Cisco binary target entries
# ---------------------------------------------------------------------------
# We extract lines matching the BinaryTargetInfo pattern:
#   name: "CiscoXxx",
#   url: "https://...",
#   checksum: "...",
#
# The parsing uses awk to extract name/url/checksum triples from
# the SessionReplayBinaryRegistry block.

parse_registry() {
    echo "==> Parsing SessionReplayBinaryRegistry from ${PACKAGE_SWIFT}" >&2

    if [[ ! -f "${PACKAGE_SWIFT}" ]]; then
        echo "ERROR: Package.swift not found at ${PACKAGE_SWIFT}" >&2
        exit 1
    fi

    # Extract name, url, checksum triples.
    # Each BinaryTargetInfo block looks like:
    #   BinaryTargetInfo(
    #       name: "CiscoLogger",
    #       url: "https://...",
    #       checksum: "abc123...",
    #       ...
    #   )
    #
    # We use awk compatible with macOS (nawk) — no gawk match() with captures.
    # Instead, we use gsub to extract the quoted value.
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


# ---------------------------------------------------------------------------
# Step 2: Download and extract each xcframework
# ---------------------------------------------------------------------------

download_and_extract() {
    local name="$1"
    local url="$2"
    local checksum="$3"

    local zip_file="${DOWNLOAD_CACHE}/${name}.zip"
    local xcfw_dir="${OUTPUT_DIR}/${name}.xcframework"

    # Skip if already present
    if [[ -d "${xcfw_dir}" ]]; then
        echo "  ✓ ${name}.xcframework (already present)"
        return 0
    fi

    # Download
    echo -n "  Downloading ${name}..."
    mkdir -p "${DOWNLOAD_CACHE}"

    if [[ -f "${zip_file}" ]]; then
        echo -n " (cached)..."
    else
        curl -sL "${url}" -o "${zip_file}"
    fi

    # Verify checksum
    local actual_checksum
    actual_checksum="$(shasum -a 256 "${zip_file}" | cut -d' ' -f1)"

    if [[ "${actual_checksum}" != "${checksum}" ]]; then
        echo " FAILED (checksum mismatch)"
        echo "    Expected: ${checksum}"
        echo "    Actual:   ${actual_checksum}"
        rm -f "${zip_file}"
        return 1
    fi

    # Extract -- the zip contains <Name>.xcframework/ at root
    local tmp_extract="${DOWNLOAD_CACHE}/extract_${name}"
    rm -rf "${tmp_extract}"
    mkdir -p "${tmp_extract}"
    unzip -q "${zip_file}" -d "${tmp_extract}"

    # Find the xcframework inside the extracted content
    local extracted_xcfw
    extracted_xcfw="$(find "${tmp_extract}" -name "${name}.xcframework" -type d -maxdepth 2 | head -1)"

    if [[ -z "${extracted_xcfw}" || ! -d "${extracted_xcfw}" ]]; then
        echo " FAILED (${name}.xcframework not found in zip)"
        rm -rf "${tmp_extract}"
        return 1
    fi

    # Move to output directory
    rm -rf "${xcfw_dir}"
    mv "${extracted_xcfw}" "${xcfw_dir}"
    rm -rf "${tmp_extract}"

    echo " ✓"
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log "Downloading Cisco Session Replay xcframeworks"
    log "Output: ${OUTPUT_DIR}"

    mkdir -p "${OUTPUT_DIR}"

    local entries
    entries="$(parse_registry)"

    if [[ -z "${entries}" ]]; then
        echo "ERROR: No BinaryTargetInfo entries found in Package.swift"
        exit 1
    fi

    local total=0
    local succeeded=0
    local failed=0

    while IFS='|' read -r name url checksum; do
        total=$((total + 1))
        if download_and_extract "${name}" "${url}" "${checksum}"; then
            succeeded=$((succeeded + 1))
        else
            failed=$((failed + 1))
        fi
    done <<< "${entries}"

    echo ""
    log "Downloaded: ${succeeded}/${total}, Failed: ${failed}"

    if [[ "${failed}" -gt 0 ]]; then
        echo "ERROR: ${failed} downloads failed"
        exit 1
    fi

    log "Done."
}

main "$@"
