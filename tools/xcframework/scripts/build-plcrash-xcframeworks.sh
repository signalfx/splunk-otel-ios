#!/bin/bash
# tools/xcframework/scripts/build-plcrash-xcframeworks.sh
#
# Builds CrashReporter (PLCrashReporter) as a dynamic xcframework from source
# using Tuist-generated Xcode project + xcodebuild.
#
# This is necessary because PLCrashReporter only ships static xcframeworks
# in their GitHub releases, and our SDK requires dynamic frameworks.
#
# Usage:
#   ./scripts/build-plcrash-xcframeworks.sh [--plcrash-version VERSION]
#
# Prerequisites:
#   - Xcode 16+ with command-line tools
#   - Tuist (install via: brew install tuist)
#   - git (for cloning PLCrashReporter source)
#
# Environment variables:
#   PLCRASH_VERSION  - Git tag to checkout (default: 1.12.0)
#   PLCRASH_REPO     - Git URL for PLCrashReporter (default: upstream GitHub)
#
# Outputs:
#   output/xcframeworks/CrashReporter.xcframework

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# PLCrashReporter Tuist project directory
PLCRASH_PROJECT_DIR="${TOOLS_ROOT}/plcrash"

# Where to clone PLCrashReporter source
VENDOR_DIR="${PLCRASH_PROJECT_DIR}/vendor/plcrashreporter"

# Output directories
BUILD_DIR="${TOOLS_ROOT}/build/plcrash"
ARCHIVES_DIR="${BUILD_DIR}/archives"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

# PLCrashReporter version
PLCRASH_VERSION="${PLCRASH_VERSION:-1.12.0}"
PLCRASH_REPO="${PLCRASH_REPO:-https://github.com/microsoft/plcrashreporter.git}"

# Symbol prefix to avoid collisions when customers also use PLCrashReporter.
# This prefix is applied to all public ObjC/C symbols via PLCrashNamespace.h.
# See: https://github.com/microsoft/plcrashreporter#custom-symbol-prefix
PLCRASH_SYMBOL_PREFIX="${PLCRASH_SYMBOL_PREFIX:-Splunk}"

# Build configuration
CONFIGURATION="Release"

# Scheme to build (must match target name in plcrash/Project.swift)
SCHEME="CrashReporter"

# Platform matrix for PLCrashReporter: iOS, tvOS, macCatalyst (no visionOS)
PLATFORM_DESTINATIONS=(
    "ios|generic/platform=iOS"
    "ios-simulator|generic/platform=iOS Simulator"
    "tvos|generic/platform=tvOS"
    "tvos-simulator|generic/platform=tvOS Simulator"
    "maccatalyst|generic/platform=macOS,variant=Mac Catalyst"
)


# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plcrash-version)
            PLCRASH_VERSION="$2"
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

log_step() {
    echo ""
    echo "============================================================"
    echo "  $*"
    echo "============================================================"
}

platform_label() {
    echo "$1" | cut -d'|' -f1
}

platform_destination() {
    echo "$1" | cut -d'|' -f2
}


# ---------------------------------------------------------------------------
# Step 1: Checkout PLCrashReporter source
# ---------------------------------------------------------------------------

checkout_plcrash_source() {
    log_step "Step 1: Checkout PLCrashReporter source (${PLCRASH_VERSION})"

    if [[ -d "${VENDOR_DIR}" ]]; then
        local current_tag
        current_tag="$(cd "${VENDOR_DIR}" && git describe --tags --exact-match HEAD 2>/dev/null || echo "unknown")"

        if [[ "${current_tag}" == "${PLCRASH_VERSION}" ]]; then
            log "PLCrashReporter source already at ${PLCRASH_VERSION}, skipping clone"
            return 0
        fi

        log "Removing existing PLCrashReporter checkout (was at ${current_tag})"
        rm -rf "${VENDOR_DIR}"
    fi

    log "Cloning PLCrashReporter at tag ${PLCRASH_VERSION}..."
    git clone --depth 1 --branch "${PLCRASH_VERSION}" "${PLCRASH_REPO}" "${VENDOR_DIR}"
    log "PLCrashReporter source checked out to ${VENDOR_DIR}"
}


# ---------------------------------------------------------------------------
# Step 2: Patch PLCrashNamespace.h with symbol prefix
# ---------------------------------------------------------------------------
# PLCrashReporter provides PLCRASHREPORTER_PREFIX to rename all public symbols.
# We patch the header so that BOTH the compiled binary AND the shipped framework
# headers carry the prefix. Without the header patch, consumers of the
# xcframework would see the original (unprefixed) names in the headers but the
# binary would export the prefixed symbols, causing link failures.
#
# We use #ifndef so the header define doesn't conflict with the matching
# GCC_PREPROCESSOR_DEFINITIONS flag used during compilation.

apply_symbol_prefix() {
    log_step "Step 2: Apply symbol prefix (${PLCRASH_SYMBOL_PREFIX})"

    local namespace_header="${VENDOR_DIR}/Source/PLCrashNamespace.h"

    if [[ ! -f "${namespace_header}" ]]; then
        echo "ERROR: PLCrashNamespace.h not found at ${namespace_header}"
        exit 1
    fi

    # Check if already patched
    if grep -q "PLCRASHREPORTER_PREFIX ${PLCRASH_SYMBOL_PREFIX}" "${namespace_header}"; then
        log "PLCrashNamespace.h already patched with prefix '${PLCRASH_SYMBOL_PREFIX}', skipping"
        return 0
    fi

    # Replace the commented-out prefix line with an active #ifndef-guarded define.
    # Original line: // #define PLCRASHREPORTER_PREFIX AcmeCo
    sed -i '' \
        's|// #define PLCRASHREPORTER_PREFIX AcmeCo|// Symbol prefix applied by Splunk RUM build system to avoid collisions.\
#ifndef PLCRASHREPORTER_PREFIX\
#define PLCRASHREPORTER_PREFIX '"${PLCRASH_SYMBOL_PREFIX}"'\
#endif|' \
        "${namespace_header}"

    # Verify the patch was applied
    if ! grep -q "PLCRASHREPORTER_PREFIX ${PLCRASH_SYMBOL_PREFIX}" "${namespace_header}"; then
        echo "ERROR: Failed to patch PLCrashNamespace.h with prefix '${PLCRASH_SYMBOL_PREFIX}'"
        exit 1
    fi

    log "PLCrashNamespace.h patched: all public symbols will be prefixed with '${PLCRASH_SYMBOL_PREFIX}'"
}


# ---------------------------------------------------------------------------
# Step 3: Generate Xcode project with Tuist
# ---------------------------------------------------------------------------

generate_xcode_project() {
    log_step "Step 3: Generate Xcode project with Tuist"

    cd "${PLCRASH_PROJECT_DIR}"

    tuist generate --no-open

    # Fix deprecated build settings injected by Tuist
    "${SCRIPT_DIR}/fix-tuist-warnings.sh" "${PLCRASH_PROJECT_DIR}/PLCrashReporterXCFrameworks.xcodeproj"

    log "Xcode project generated at ${PLCRASH_PROJECT_DIR}"
}


# ---------------------------------------------------------------------------
# Step 4: Archive for each platform
# ---------------------------------------------------------------------------

archive_frameworks() {
    log_step "Step 4: Archive CrashReporter for all platforms"

    rm -rf "${ARCHIVES_DIR}"
    mkdir -p "${ARCHIVES_DIR}"

    for platform_entry in "${PLATFORM_DESTINATIONS[@]}"; do
        local label
        label="$(platform_label "${platform_entry}")"
        local destination
        destination="$(platform_destination "${platform_entry}")"
        local archive_path="${ARCHIVES_DIR}/${SCHEME}-${label}.xcarchive"

        log "Archiving ${SCHEME} for ${label}..."

        xcodebuild archive \
            -workspace "${PLCRASH_PROJECT_DIR}/PLCrashReporterXCFrameworks.xcworkspace" \
            -scheme "${SCHEME}" \
            -configuration "${CONFIGURATION}" \
            -destination "${destination}" \
            -archivePath "${archive_path}" \
            SKIP_INSTALL=NO \
            2>&1 | tail -5

        if [[ ! -d "${archive_path}" ]]; then
            echo "ERROR: Archive failed for ${SCHEME} (${label})"
            exit 1
        fi

        log "  ✓ ${SCHEME}-${label}.xcarchive"
    done
}


# ---------------------------------------------------------------------------
# Step 5: Create xcframework from archives
# ---------------------------------------------------------------------------

create_xcframework() {
    log_step "Step 5: Create CrashReporter.xcframework"

    mkdir -p "${OUTPUT_DIR}"

    local xcframework_path="${OUTPUT_DIR}/${SCHEME}.xcframework"
    rm -rf "${xcframework_path}"

    local create_args=()

    for platform_entry in "${PLATFORM_DESTINATIONS[@]}"; do
        local label
        label="$(platform_label "${platform_entry}")"
        local archive_path="${ARCHIVES_DIR}/${SCHEME}-${label}.xcarchive"

        local framework_path="${archive_path}/Products/Library/Frameworks/${SCHEME}.framework"

        if [[ ! -d "${framework_path}" ]]; then
            echo "ERROR: Framework not found at ${framework_path}"
            echo "  Archive contents:"
            find "${archive_path}/Products" -type d -maxdepth 4 2>/dev/null || true
            exit 1
        fi

        create_args+=(-framework "${framework_path}")

        # Include dSYMs if present
        local dsym_path="${archive_path}/dSYMs/${SCHEME}.framework.dSYM"
        if [[ -d "${dsym_path}" ]]; then
            create_args+=(-debug-symbols "${dsym_path}")
        fi
    done

    log "Creating ${SCHEME}.xcframework..."
    xcodebuild -create-xcframework \
        "${create_args[@]}" \
        -output "${xcframework_path}"

    if [[ ! -d "${xcframework_path}" ]]; then
        echo "ERROR: Failed to create ${SCHEME}.xcframework"
        exit 1
    fi

    log "  ✓ ${xcframework_path}"
}


# ---------------------------------------------------------------------------
# Step 6: Verify xcframework
# ---------------------------------------------------------------------------

verify_xcframework() {
    log_step "Step 6: Verify CrashReporter.xcframework"

    local xcframework_path="${OUTPUT_DIR}/${SCHEME}.xcframework"
    local all_passed=true

    # Check 1: Info.plist exists
    if [[ ! -f "${xcframework_path}/Info.plist" ]]; then
        echo "  FAIL: Info.plist missing"
        all_passed=false
    else
        echo "  ✓ Info.plist exists"
    fi

    # Check 2: Expected platform slices
    local expected_slices=("ios-arm64" "ios-arm64_x86_64-simulator" "tvos-arm64" "tvos-arm64_x86_64-simulator")
    local has_catalyst=false

    for slice_dir in "${xcframework_path}"/*/; do
        local dirname
        dirname="$(basename "${slice_dir}")"
        if [[ "${dirname}" == *"maccatalyst"* ]] || [[ "${dirname}" == *"macOS"* ]]; then
            has_catalyst=true
        fi
    done

    for slice in "${expected_slices[@]}"; do
        if ls -d "${xcframework_path}/${slice}"* &>/dev/null; then
            echo "  ✓ Slice: ${slice}"
        else
            echo "  FAIL: Missing slice: ${slice}"
            all_passed=false
        fi
    done

    if [[ "${has_catalyst}" == "true" ]]; then
        echo "  ✓ Slice: maccatalyst"
    else
        echo "  FAIL: Missing slice: maccatalyst"
        all_passed=false
    fi

    # Check 3: Verify Mach-O type is dynamic (MH_DYLIB)
    local any_binary
    any_binary="$(find "${xcframework_path}" -name "${SCHEME}" -type f 2>/dev/null | head -1)"
    if [[ -n "${any_binary}" ]]; then
        local mach_type
        mach_type="$(file "${any_binary}" 2>/dev/null || true)"
        if echo "${mach_type}" | grep -q "dynamically linked"; then
            echo "  ✓ Binary is dynamic (MH_DYLIB)"
        else
            echo "  FAIL: Binary is NOT dynamic. Type: ${mach_type}"
            all_passed=false
        fi
    else
        echo "  FAIL: No binary found"
        all_passed=false
    fi

    # Check 4: Public headers present
    local header_count
    header_count="$(find "${xcframework_path}" -name "*.h" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${header_count}" -gt 0 ]]; then
        echo "  ✓ Public headers found (${header_count})"
    else
        echo "  FAIL: No public headers found"
        all_passed=false
    fi

    # Check 5: Symbol prefix applied
    if [[ -n "${PLCRASH_SYMBOL_PREFIX}" && -n "${any_binary}" ]]; then
        local prefixed_symbols
        prefixed_symbols="$(nm -gU "${any_binary}" 2>/dev/null | grep "${PLCRASH_SYMBOL_PREFIX}PLCrash" | head -5)"
        local unprefixed_symbols
        unprefixed_symbols="$(nm -gU "${any_binary}" 2>/dev/null | grep '_OBJC_CLASS_\$_PLCrash[A-Z]' | grep -v "${PLCRASH_SYMBOL_PREFIX}" || true)"

        if [[ -n "${prefixed_symbols}" ]]; then
            echo "  ✓ Symbol prefix '${PLCRASH_SYMBOL_PREFIX}' applied (found prefixed symbols)"
        else
            echo "  FAIL: No prefixed symbols found (expected prefix '${PLCRASH_SYMBOL_PREFIX}')"
            all_passed=false
        fi

        if [[ -z "${unprefixed_symbols}" ]]; then
            echo "  ✓ No unprefixed PLCrashReporter ObjC class symbols found"
        else
            echo "  WARN: Found unprefixed PLCrashReporter symbols:"
            echo "${unprefixed_symbols}" | head -5 | sed 's/^/    /'
        fi
    fi

    echo ""
    if [[ "${all_passed}" == "true" ]]; then
        log "All verification checks passed ✓"
    else
        echo "ERROR: Some verification checks failed."
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Step 7: Summary
# ---------------------------------------------------------------------------

print_summary() {
    log_step "Build complete"

    local xcframework_path="${OUTPUT_DIR}/${SCHEME}.xcframework"
    local size
    size="$(du -sh "${xcframework_path}" 2>/dev/null | cut -f1 || echo "?")"

    echo "XCFramework built at:"
    echo "  ${xcframework_path} (${size})"
    echo ""
    echo "Platform slices:"
    for dir in "${xcframework_path}"/*/; do
        local dirname
        dirname="$(basename "${dir}")"
        [[ "${dirname}" == "_CodeSignature" ]] && continue
        echo "  - ${dirname}"
    done
    echo ""
    echo "PLCrashReporter version: ${PLCRASH_VERSION}"
    echo "Symbol prefix: ${PLCRASH_SYMBOL_PREFIX}"
    echo "Configuration: ${CONFIGURATION}"
    echo "Linking: Dynamic (MH_DYLIB)"
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log "Building PLCrashReporter xcframework (version ${PLCRASH_VERSION})"
    log "Tools root: ${TOOLS_ROOT}"

    checkout_plcrash_source
    apply_symbol_prefix
    generate_xcode_project
    archive_frameworks
    create_xcframework
    verify_xcframework
    print_summary
}

main "$@"
