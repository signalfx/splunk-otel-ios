#!/bin/bash
# tools/xcframework/scripts/build-otel-xcframeworks.sh
#
# Builds OpenTelemetryApi and OpenTelemetrySdk as dynamic xcframeworks
# from source using Tuist-generated Xcode project + xcodebuild.
#
# Usage:
#   ./scripts/build-otel-xcframeworks.sh [--otel-version VERSION]
#
# Prerequisites:
#   - Xcode 16+ with command-line tools
#   - Tuist (install via: brew install tuist)
#   - git (for cloning OTel source)
#
# Environment variables:
#   OTEL_VERSION   - Git tag of opentelemetry-swift-core to checkout (default: 2.3.0)
#   OTEL_REPO      - Git URL for opentelemetry-swift-core (default: upstream GitHub)
#
# Outputs:
#   output/xcframeworks/OpenTelemetryApi.xcframework
#   output/xcframeworks/OpenTelemetrySdk.xcframework

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Script directory (tools/xcframework/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Root of the xcframework tooling (tools/xcframework/)
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# OTel Tuist project directory
OTEL_PROJECT_DIR="${TOOLS_ROOT}/otel"

# Where to clone OTel source
VENDOR_DIR="${OTEL_PROJECT_DIR}/vendor/opentelemetry-swift-core"

# Output directories
BUILD_DIR="${TOOLS_ROOT}/build/otel"
ARCHIVES_DIR="${BUILD_DIR}/archives"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

# OTel version: can be overridden via env var or --otel-version flag
OTEL_VERSION="${OTEL_VERSION:-2.3.0}"
OTEL_REPO="${OTEL_REPO:-https://github.com/open-telemetry/opentelemetry-swift-core.git}"

# Build configuration (always Release for distribution)
CONFIGURATION="Release"

# Schemes to build (must match target names in Project.swift)
SCHEMES=("OpenTelemetryApi" "OpenTelemetrySdk")

# Platform matrix for OTel: all platforms supported
# Format: "platform destination" pairs for xcodebuild -destination
# Each entry: "platform_label|xcodebuild_destination"
PLATFORM_DESTINATIONS=(
    "ios|generic/platform=iOS"
    "ios-simulator|generic/platform=iOS Simulator"
    "tvos|generic/platform=tvOS"
    "tvos-simulator|generic/platform=tvOS Simulator"
    "xros|generic/platform=visionOS"
    "xros-simulator|generic/platform=visionOS Simulator"
    "maccatalyst|generic/platform=macOS,variant=Mac Catalyst"
)


# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --otel-version)
            OTEL_VERSION="$2"
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

# Extracts the platform label from a PLATFORM_DESTINATIONS entry.
# e.g., "ios|generic/platform=iOS" → "ios"
platform_label() {
    echo "$1" | cut -d'|' -f1
}

# Extracts the xcodebuild destination from a PLATFORM_DESTINATIONS entry.
# e.g., "ios|generic/platform=iOS" → "generic/platform=iOS"
platform_destination() {
    echo "$1" | cut -d'|' -f2
}


# ---------------------------------------------------------------------------
# Step 1: Checkout OpenTelemetry source
# ---------------------------------------------------------------------------

checkout_otel_source() {
    log_step "Step 1: Checkout OpenTelemetry source (${OTEL_VERSION})"

    if [[ -d "${VENDOR_DIR}" ]]; then
        # Check if existing checkout is at the right version
        local current_tag
        current_tag="$(cd "${VENDOR_DIR}" && git describe --tags --exact-match HEAD 2>/dev/null || echo "unknown")"

        if [[ "${current_tag}" == "${OTEL_VERSION}" ]]; then
            log "OTel source already at ${OTEL_VERSION}, skipping clone"
            return 0
        fi

        log "Removing existing OTel checkout (was at ${current_tag})"
        rm -rf "${VENDOR_DIR}"
    fi

    log "Cloning opentelemetry-swift-core at tag ${OTEL_VERSION}..."
    git clone --depth 1 --branch "${OTEL_VERSION}" "${OTEL_REPO}" "${VENDOR_DIR}"
    log "OTel source checked out to ${VENDOR_DIR}"
}


# ---------------------------------------------------------------------------
# Step 2: Generate Xcode project with Tuist
# ---------------------------------------------------------------------------

generate_xcode_project() {
    log_step "Step 2: Generate Xcode project with Tuist"

    cd "${OTEL_PROJECT_DIR}"

    # Generate without opening Xcode
    tuist generate --no-open

    # Fix deprecated build settings injected by Tuist
    "${SCRIPT_DIR}/fix-tuist-warnings.sh" "${OTEL_PROJECT_DIR}/OpenTelemetryXCFrameworks.xcodeproj"

    log "Xcode project generated at ${OTEL_PROJECT_DIR}"
}


# ---------------------------------------------------------------------------
# Step 3: Archive each scheme for each platform
# ---------------------------------------------------------------------------
# This creates .xcarchive bundles containing the framework + dSYMs.
# Each archive targets a single platform/destination.

archive_frameworks() {
    log_step "Step 3: Archive frameworks for all platforms"

    # Clean previous archives
    rm -rf "${ARCHIVES_DIR}"
    mkdir -p "${ARCHIVES_DIR}"

    for scheme in "${SCHEMES[@]}"; do
        for platform_entry in "${PLATFORM_DESTINATIONS[@]}"; do
            local label
            label="$(platform_label "${platform_entry}")"
            local destination
            destination="$(platform_destination "${platform_entry}")"
            local archive_path="${ARCHIVES_DIR}/${scheme}-${label}.xcarchive"

            log "Archiving ${scheme} for ${label}..."

            local xcodebuild_args=(
                archive
                -workspace "${OTEL_PROJECT_DIR}/OpenTelemetryXCFrameworks.xcworkspace"
                -scheme "${scheme}"
                -configuration "${CONFIGURATION}"
                -destination "${destination}"
                -archivePath "${archive_path}"
                SKIP_INSTALL=NO
                BUILD_LIBRARY_FOR_DISTRIBUTION=YES
                "OTHER_SWIFT_FLAGS=-package-name opentelemetry-swift-core"
            )
            if [[ "${label}" == "maccatalyst" ]]; then
                xcodebuild_args+=("IPHONEOS_DEPLOYMENT_TARGET=15.0")
            fi

            xcodebuild "${xcodebuild_args[@]}" 2>&1 | tail -5

            # Verify the archive was created
            if [[ ! -d "${archive_path}" ]]; then
                echo "ERROR: Archive failed for ${scheme} (${label})"
                exit 1
            fi

            log "  ✓ ${scheme}-${label}.xcarchive"
        done
    done
}


# ---------------------------------------------------------------------------
# Step 4: Create xcframeworks from archives
# ---------------------------------------------------------------------------
# Combines all platform archives for each scheme into a single .xcframework.

create_xcframeworks() {
    log_step "Step 4: Create xcframeworks"

    mkdir -p "${OUTPUT_DIR}"

    for scheme in "${SCHEMES[@]}"; do
        local xcframework_path="${OUTPUT_DIR}/${scheme}.xcframework"

        # Remove existing xcframework if present
        rm -rf "${xcframework_path}"

        # Build the -create-xcframework arguments:
        # For each platform archive, add -framework <path> and -debug-symbols <dSYM path>
        local create_args=()

        for platform_entry in "${PLATFORM_DESTINATIONS[@]}"; do
            local label
            label="$(platform_label "${platform_entry}")"
            local archive_path="${ARCHIVES_DIR}/${scheme}-${label}.xcarchive"

            # Path to the framework inside the archive
            local framework_path="${archive_path}/Products/Library/Frameworks/${scheme}.framework"

            if [[ ! -d "${framework_path}" ]]; then
                echo "ERROR: Framework not found at ${framework_path}"
                echo "  Archive contents:"
                find "${archive_path}/Products" -type d -maxdepth 4 2>/dev/null || true
                exit 1
            fi

            create_args+=(-framework "${framework_path}")

            # Include dSYMs if present
            local dsym_path="${archive_path}/dSYMs/${scheme}.framework.dSYM"
            if [[ -d "${dsym_path}" ]]; then
                create_args+=(-debug-symbols "${dsym_path}")
            fi
        done

        log "Creating ${scheme}.xcframework..."
        xcodebuild -create-xcframework \
            "${create_args[@]}" \
            -output "${xcframework_path}"

        # Verify the xcframework was created
        if [[ ! -d "${xcframework_path}" ]]; then
            echo "ERROR: Failed to create ${scheme}.xcframework"
            exit 1
        fi

        log "  ✓ ${xcframework_path}"
    done
}


# ---------------------------------------------------------------------------
# Step 5: Verify xcframework contents
# ---------------------------------------------------------------------------
# Quick sanity checks on the produced xcframeworks.

verify_xcframeworks() {
    log_step "Step 5: Verify xcframeworks"

    local all_passed=true

    for scheme in "${SCHEMES[@]}"; do
        local xcframework_path="${OUTPUT_DIR}/${scheme}.xcframework"

        log "Verifying ${scheme}.xcframework..."

        # Check 1: Info.plist exists
        if [[ ! -f "${xcframework_path}/Info.plist" ]]; then
            echo "  FAIL: Info.plist missing"
            all_passed=false
            continue
        fi
        echo "  ✓ Info.plist exists"

        # Check 2: Expected platform slices exist
        local expected_slices=("ios-arm64" "ios-arm64_x86_64-simulator" "tvos-arm64" "tvos-arm64_x86_64-simulator" "xros-arm64" "xros-arm64_x86_64-simulator")
        # Mac Catalyst slice naming varies; check for it separately
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

        # Check 3: .swiftinterface files exist in at least one slice
        local swiftinterface_count
        swiftinterface_count="$(find "${xcframework_path}" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "${swiftinterface_count}" -gt 0 ]]; then
            echo "  ✓ .swiftinterface files found (${swiftinterface_count} total)"
        else
            echo "  FAIL: No .swiftinterface files found"
            all_passed=false
        fi

        # Check 4: Verify 'package' keyword does NOT appear in .swiftinterface
        # This confirms that -package-name correctly excluded package members.
        local package_in_interface
        package_in_interface="$(grep -r "package " "${xcframework_path}" --include="*.swiftinterface" 2>/dev/null | grep -v "// package" || true)"
        if [[ -z "${package_in_interface}" ]]; then
            echo "  ✓ No 'package' declarations in .swiftinterface (correctly excluded)"
        else
            echo "  WARNING: 'package' found in .swiftinterface:"
            echo "${package_in_interface}" | head -5
            all_passed=false
        fi

        # Check 5: dSYMs present
        local dsym_count
        dsym_count="$(find "${xcframework_path}" -name "*.dSYM" -type d 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "${dsym_count}" -gt 0 ]]; then
            echo "  ✓ dSYM bundles found (${dsym_count})"
        else
            echo "  ⚠ No dSYM bundles found (may be expected if dSYMs are alongside xcframework)"
        fi

        echo ""
    done

    if [[ "${all_passed}" == "true" ]]; then
        log "All verification checks passed ✓"
    else
        echo ""
        echo "ERROR: Some verification checks failed. See above."
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Step 6: Print summary
# ---------------------------------------------------------------------------

print_summary() {
    log_step "Build complete"

    echo "XCFrameworks built at:"
    for scheme in "${SCHEMES[@]}"; do
        local xcframework_path="${OUTPUT_DIR}/${scheme}.xcframework"
        local size
        size="$(du -sh "${xcframework_path}" 2>/dev/null | cut -f1 || echo "?")"
        echo "  ${xcframework_path} (${size})"
    done

    echo ""
    echo "Platform slices per xcframework:"
    for scheme in "${SCHEMES[@]}"; do
        local xcframework_path="${OUTPUT_DIR}/${scheme}.xcframework"
        echo "  ${scheme}:"
        for dir in "${xcframework_path}"/*/; do
            local dirname
            dirname="$(basename "${dir}")"
            # Skip non-platform directories
            [[ "${dirname}" == "_CodeSignature" ]] && continue
            echo "    - ${dirname}"
        done
    done

    echo ""
    echo "OTel version: ${OTEL_VERSION}"
    echo "Configuration: ${CONFIGURATION}"
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log "Building OTel xcframeworks (version ${OTEL_VERSION})"
    log "Tools root: ${TOOLS_ROOT}"

    checkout_otel_source
    generate_xcode_project
    archive_frameworks
    create_xcframeworks
    verify_xcframeworks
    print_summary
}

main "$@"
