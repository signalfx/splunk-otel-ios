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
#   ./scripts/build-plcrash-xcframeworks.sh [--plcrash-version VERSION] [--ios-only]
#
# Prerequisites:
#   - Xcode 16+ with command-line tools
#   - Tuist (install via: brew install tuist)
#   - git (for cloning PLCrashReporter source)
#
# Environment variables:
#   PLCRASH_VERSION  - Git tag to checkout (default: 1.12.2)
#   PLCRASH_REPO     - Git URL for PLCrashReporter (default: upstream GitHub)
#   IOS_ONLY         - When true, build only iOS device and simulator slices
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
PLCRASH_VERSION="${PLCRASH_VERSION:-1.12.2}"
PLCRASH_REPO="${PLCRASH_REPO:-https://github.com/microsoft/plcrashreporter.git}"
IOS_ONLY="${IOS_ONLY:-false}"

# Build configuration
CONFIGURATION="Release"

# Scheme to build (must match target name in plcrash/Project.swift)
SCHEME="CrashReporter"

# Platform matrix for PLCrashReporter: iOS, tvOS, macCatalyst (no visionOS)
FULL_PLATFORM_DESTINATIONS=(
    "ios|generic/platform=iOS"
    "ios-simulator|generic/platform=iOS Simulator"
    "tvos|generic/platform=tvOS"
    "tvos-simulator|generic/platform=tvOS Simulator"
    "maccatalyst|generic/platform=macOS,variant=Mac Catalyst"
)

IOS_PLATFORM_DESTINATIONS=(
    "ios|generic/platform=iOS"
    "ios-simulator|generic/platform=iOS Simulator"
)

PLATFORM_DESTINATIONS=("${FULL_PLATFORM_DESTINATIONS[@]}")


# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plcrash-version)
            PLCRASH_VERSION="$2"
            shift 2
            ;;
        --ios-only)
            IOS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [[ "${IOS_ONLY}" == "true" ]]; then
    PLATFORM_DESTINATIONS=("${IOS_PLATFORM_DESTINATIONS[@]}")
fi


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
# Step 2: Generate Xcode project with Tuist
# ---------------------------------------------------------------------------

generate_xcode_project() {
    log_step "Step 2: Generate Xcode project with Tuist"

    cd "${PLCRASH_PROJECT_DIR}"

    tuist generate --no-open

    # Fix deprecated build settings injected by Tuist
    "${SCRIPT_DIR}/fix-tuist-warnings.sh" "${PLCRASH_PROJECT_DIR}/PLCrashReporterXCFrameworks.xcodeproj"

    log "Xcode project generated at ${PLCRASH_PROJECT_DIR}"
}


# ---------------------------------------------------------------------------
# Step 3: Archive for each platform
# ---------------------------------------------------------------------------

archive_frameworks() {
    if [[ "${IOS_ONLY}" == "true" ]]; then
        log_step "Step 3: Archive CrashReporter for iOS platforms"
    else
        log_step "Step 3: Archive CrashReporter for all platforms"
    fi

    rm -rf "${ARCHIVES_DIR}"
    mkdir -p "${ARCHIVES_DIR}"

    for platform_entry in "${PLATFORM_DESTINATIONS[@]}"; do
        local label
        label="$(platform_label "${platform_entry}")"
        local destination
        destination="$(platform_destination "${platform_entry}")"
        local archive_path="${ARCHIVES_DIR}/${SCHEME}-${label}.xcarchive"

        log "Archiving ${SCHEME} for ${label}..."

        local xcodebuild_args=(
            archive
            -workspace "${PLCRASH_PROJECT_DIR}/PLCrashReporterXCFrameworks.xcworkspace"
            -scheme "${SCHEME}"
            -configuration "${CONFIGURATION}"
            -destination "${destination}"
            -archivePath "${archive_path}"
            SKIP_INSTALL=NO
        )
        if [[ "${label}" == "maccatalyst" ]]; then
            xcodebuild_args+=("IPHONEOS_DEPLOYMENT_TARGET=15.0")
        fi

        xcodebuild "${xcodebuild_args[@]}" 2>&1 | tail -5

        if [[ ! -d "${archive_path}" ]]; then
            echo "ERROR: Archive failed for ${SCHEME} (${label})"
            exit 1
        fi

        log "  ✓ ${SCHEME}-${label}.xcarchive"
    done
}


# ---------------------------------------------------------------------------
# Step 4: Create xcframework from archives
# ---------------------------------------------------------------------------

create_xcframework() {
    log_step "Step 4: Create CrashReporter.xcframework"

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
# Step 5: Verify xcframework
# ---------------------------------------------------------------------------

verify_xcframework() {
    log_step "Step 5: Verify CrashReporter.xcframework"

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
    local expected_slices=("ios-arm64" "ios-arm64_x86_64-simulator")
    if [[ "${IOS_ONLY}" != "true" ]]; then
        expected_slices+=("tvos-arm64" "tvos-arm64_x86_64-simulator")
    fi
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

    if [[ "${IOS_ONLY}" != "true" ]]; then
        if [[ "${has_catalyst}" == "true" ]]; then
            echo "  ✓ Slice: maccatalyst"
        else
            echo "  FAIL: Missing slice: maccatalyst"
            all_passed=false
        fi
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

    echo ""
    if [[ "${all_passed}" == "true" ]]; then
        log "All verification checks passed ✓"
    else
        echo "ERROR: Some verification checks failed."
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Step 6: Summary
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
    echo "Configuration: ${CONFIGURATION}"
    echo "Linking: Dynamic (MH_DYLIB)"
    if [[ "${IOS_ONLY}" == "true" ]]; then
        echo "Variant: iOS-only"
    else
        echo "Variant: all platforms"
    fi
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log "Building PLCrashReporter xcframework (version ${PLCRASH_VERSION})"
    log "Tools root: ${TOOLS_ROOT}"
    log "iOS-only: ${IOS_ONLY}"

    checkout_plcrash_source
    generate_xcode_project
    archive_frameworks
    create_xcframework
    verify_xcframework
    print_summary
}

main "$@"
