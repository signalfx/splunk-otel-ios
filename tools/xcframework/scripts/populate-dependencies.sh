#!/bin/bash
# tools/xcframework/scripts/populate-dependencies.sh
#
# Populates the `dependencies/` directory with all pre-built xcframeworks
# needed by the SplunkAgent Tuist project. This script must be run before
# `tuist generate` on the main Project.swift.
#
# Sources:
#   - OpenTelemetryApi/Sdk: Built by build-otel-xcframeworks.sh → output/xcframeworks/
#   - Cisco modules: Built locally as dynamic xcframeworks by build-cisco-xcframeworks.sh
#                    (or linked from a legacy local path via --cisco-path)
#   - CrashReporter: Downloaded from PLCrashReporter GitHub releases
#
# Usage:
#   ./scripts/populate-dependencies.sh [options]
#
# Options:
#   --cisco-path PATH     Legacy path to directory containing dynamic Cisco xcframeworks
#   --plcrash-version VER PLCrashReporter version (default: 1.12.2)
#   --skip-otel           Skip OTel (assumes already built in output/xcframeworks/)
#   --skip-cisco          Skip Cisco staging
#   --skip-plcrash        Skip PLCrashReporter download
#   --download-cisco      Legacy mode: download Cisco from Package.swift registry
#
# Environment variables:
#   CISCO_XCFRAMEWORKS_PATH  Same as --cisco-path (legacy)
#   PLCRASH_VERSION          Same as --plcrash-version

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Where pre-built xcframeworks are staged for the Tuist project
DEPS_DIR="${TOOLS_ROOT}/dependencies"

# Where OTel xcframeworks are built
OTEL_OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

# PLCrashReporter settings (built from source by build-plcrash-xcframeworks.sh)
PLCRASH_VERSION="${PLCRASH_VERSION:-1.12.2}"

# Cisco xcframeworks path (can be overridden)
CISCO_XCFRAMEWORKS_PATH="${CISCO_XCFRAMEWORKS_PATH:-}"

# Control flags
SKIP_OTEL=false
SKIP_CISCO=false
SKIP_PLCRASH=false
DOWNLOAD_CISCO=false

# Expected xcframeworks
OTEL_FRAMEWORKS=("OpenTelemetryApi" "OpenTelemetrySdk")
CISCO_FRAMEWORKS=("CiscoCommon" "CiscoLogger" "CiscoEncryption" "CiscoSwizzling" "CiscoInteractions" "CiscoDiskStorage" "CiscoSessionReplay" "CiscoInstanceManager" "CiscoRuntimeCache")


# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cisco-path)
            CISCO_XCFRAMEWORKS_PATH="$2"
            shift 2
            ;;
        --plcrash-version)
            PLCRASH_VERSION="$2"
            shift 2
            ;;
        --skip-otel) SKIP_OTEL=true; shift ;;
        --skip-cisco) SKIP_CISCO=true; shift ;;
        --skip-plcrash) SKIP_PLCRASH=true; shift ;;
        --download-cisco) DOWNLOAD_CISCO=true; shift ;;
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
# Step 1: Prepare dependencies directory
# ---------------------------------------------------------------------------

log "Populating dependencies directory at ${DEPS_DIR}"
mkdir -p "${DEPS_DIR}"


# ---------------------------------------------------------------------------
# Step 2: Link OTel xcframeworks
# ---------------------------------------------------------------------------

if [[ "${SKIP_OTEL}" == "false" ]]; then
    log "Linking OTel xcframeworks from ${OTEL_OUTPUT_DIR}"

    for fw in "${OTEL_FRAMEWORKS[@]}"; do
        src="${OTEL_OUTPUT_DIR}/${fw}.xcframework"
        dst="${DEPS_DIR}/${fw}.xcframework"

        if [[ ! -d "${src}" ]]; then
            echo "ERROR: OTel xcframework not found: ${src}"
            echo "  Run build-otel-xcframeworks.sh first."
            exit 1
        fi

        # Remove existing link/copy and create symlink
        rm -rf "${dst}"
        ln -s "${src}" "${dst}"
        echo "  ✓ ${fw}.xcframework (symlinked)"
    done
fi


# ---------------------------------------------------------------------------
# Step 3: Link Cisco xcframeworks
# ---------------------------------------------------------------------------

if [[ "${SKIP_CISCO}" == "false" ]]; then
    if [[ -n "${CISCO_XCFRAMEWORKS_PATH}" ]]; then
        # Use legacy local path: symlink each Cisco xcframework
        log "Linking Cisco xcframeworks from ${CISCO_XCFRAMEWORKS_PATH}"

        for fw in "${CISCO_FRAMEWORKS[@]}"; do
            src="${CISCO_XCFRAMEWORKS_PATH}/${fw}.xcframework"
            dst="${DEPS_DIR}/${fw}.xcframework"

            if [[ ! -d "${src}" ]]; then
                echo "ERROR: Cisco xcframework not found: ${src}"
                exit 1
            fi

            rm -rf "${dst}"
            ln -s "$(cd "$(dirname "${src}")" && pwd)/$(basename "${src}")" "${dst}"
            echo "  ✓ ${fw}.xcframework (symlinked)"
        done
    elif [[ "${DOWNLOAD_CISCO}" == "true" ]]; then
        # Legacy mode only: Package.swift now intentionally points to static
        # Cisco artifacts, so this must never be the default xcframework path.
        log "Downloading Cisco xcframeworks from Package.swift registry (legacy mode)"
        "${SCRIPT_DIR}/download-cisco-xcframeworks.sh" --output-dir "${DEPS_DIR}"
    else
        log "Using Cisco xcframeworks already staged in ${DEPS_DIR}"

        for fw in "${CISCO_FRAMEWORKS[@]}"; do
            dst="${DEPS_DIR}/${fw}.xcframework"

            if [[ ! -d "${dst}" ]]; then
                echo "ERROR: Cisco xcframework not found: ${dst}"
                echo "  Run build-cisco-xcframeworks.sh first with SESSION_REPLAY_LOCAL_PATH set,"
                echo "  or pass --cisco-path with prebuilt dynamic Cisco xcframeworks."
                exit 1
            fi
        done
    fi
fi


# ---------------------------------------------------------------------------
# Step 4: Link PLCrashReporter xcframework (built from source)
# ---------------------------------------------------------------------------

if [[ "${SKIP_PLCRASH}" == "false" ]]; then
    log "Linking CrashReporter xcframework from build output"

    PLCRASH_SRC="${OTEL_OUTPUT_DIR}/CrashReporter.xcframework"
    PLCRASH_DST="${DEPS_DIR}/CrashReporter.xcframework"

    if [[ ! -d "${PLCRASH_SRC}" ]]; then
        echo "ERROR: CrashReporter.xcframework not found at ${PLCRASH_SRC}"
        echo "  Run build-plcrash-xcframeworks.sh first."
        exit 1
    fi

    rm -rf "${PLCRASH_DST}"
    ln -s "${PLCRASH_SRC}" "${PLCRASH_DST}"
    echo "  ✓ CrashReporter.xcframework (symlinked from build output)"
fi


# ---------------------------------------------------------------------------
# Step 5: Copy Cisco xcframeworks into the output directory
# ---------------------------------------------------------------------------
# The output/ directory is the single distribution artifact. It already
# contains built-from-source frameworks (OTel, PLCrash, Agent modules).
# Cisco SR frameworks are pre-built externals that also need to be in
# the output so customers get everything from one folder.

if [[ "${SKIP_CISCO}" == "false" ]]; then
    mkdir -p "${OTEL_OUTPUT_DIR}"
    log "Copying Cisco xcframeworks to output directory"

    for fw in "${CISCO_FRAMEWORKS[@]}"; do
        src="${DEPS_DIR}/${fw}.xcframework"
        dst="${OTEL_OUTPUT_DIR}/${fw}.xcframework"

        if [[ -d "${src}" ]]; then
            if [[ -L "${src}" && "$(readlink "${src}")" == "${dst}" ]]; then
                echo "  ✓ ${fw}.xcframework already in output/"
                continue
            fi

            # Use ditto to preserve code signatures and extended attributes
            rm -rf "${dst}"
            ditto "${src}" "${dst}"
            echo "  ✓ ${fw}.xcframework → output/"
        fi
    done
fi


# ---------------------------------------------------------------------------
# Step 6: Verify
# ---------------------------------------------------------------------------

log "Dependencies directory contents:"
for item in "${DEPS_DIR}"/*.xcframework; do
    if [[ -L "${item}" ]]; then
        echo "  → $(basename "${item}") -> $(readlink "${item}")"
    elif [[ -d "${item}" ]]; then
        echo "  ● $(basename "${item}")"
    fi
done

log "Done."
