#!/bin/bash
# tools/xcframework/scripts/run-smoke-test.sh
#
# Builds the XCFramework smoke test app to verify a clean consumer can link
# using only shipped xcframeworks.
#
# This script:
#   1. Generates the Tuist project for the smoke test
#   2. Builds for iOS, tvOS, Mac Catalyst, and visionOS
#   3. Reports success/failure
#
# Prerequisites:
#   - All xcframeworks must be built in output/xcframeworks/
#   - Tuist must be installed
#
# Usage:
#   ./scripts/run-smoke-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SMOKE_TEST_DIR="${TOOLS_ROOT}/smoke-test"
XCFW_DIR="${TOOLS_ROOT}/output/xcframeworks"


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


# ---------------------------------------------------------------------------
# Step 1: Verify xcframeworks exist
# ---------------------------------------------------------------------------

log_step "Step 1: Verify xcframeworks exist"

REQUIRED_FRAMEWORKS=(
    "SplunkAgent"
    "SplunkAgentObjC"
    "OpenTelemetryApi"
    "OpenTelemetrySdk"
    "CrashReporter"
)

ALL_PRESENT=true
for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
    if [[ -d "${XCFW_DIR}/${fw}.xcframework" ]]; then
        echo "  ✓ ${fw}.xcframework"
    else
        echo "  ✗ ${fw}.xcframework MISSING"
        ALL_PRESENT=false
    fi
done

if [[ "${ALL_PRESENT}" == "false" ]]; then
    echo ""
    echo "ERROR: Some required xcframeworks are missing."
    echo "  Run 'make build' first."
    exit 1
fi


# ---------------------------------------------------------------------------
# Step 2: Generate Tuist project
# ---------------------------------------------------------------------------

log_step "Step 2: Generate smoke test Xcode project"

cd "${SMOKE_TEST_DIR}"
tuist generate --no-open

# Fix deprecated build settings injected by Tuist
"${SCRIPT_DIR}/fix-tuist-warnings.sh" "${SMOKE_TEST_DIR}/XCFrameworkSmokeTest.xcodeproj"

log "Xcode project generated"


# ---------------------------------------------------------------------------
# Step 3: Build clean consumer matrix
# ---------------------------------------------------------------------------

log_step "Step 3: Build smoke test app for supported platforms"

DESTINATIONS=(
    "iOS Simulator|generic/platform=iOS Simulator"
    "tvOS Simulator|generic/platform=tvOS Simulator"
    "Mac Catalyst|generic/platform=macOS,variant=Mac Catalyst"
    "visionOS Simulator|generic/platform=visionOS Simulator"
)

for destination_entry in "${DESTINATIONS[@]}"; do
    label="${destination_entry%%|*}"
    destination="${destination_entry#*|}"

    echo "  Building ${label}..."
    arch_override=""
    if [[ "${label}" == "Mac Catalyst" ]]; then
        arch_override="ARCHS=arm64"
    fi

    xcodebuild build \
        -workspace "${SMOKE_TEST_DIR}/XCFrameworkSmokeTest.xcworkspace" \
        -scheme "XCFrameworkSmokeTest" \
        -destination "${destination}" \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        ${arch_override} \
        2>&1 | tail -20

    BUILD_EXIT=$?

    if [[ ${BUILD_EXIT} -ne 0 ]]; then
        echo ""
        echo "ERROR: Smoke test build FAILED for ${label}"
        exit 1
    fi
done


# ---------------------------------------------------------------------------
# Step 4: Report
# ---------------------------------------------------------------------------

log_step "Smoke test passed"

echo "All xcframeworks linked successfully."
echo "Frameworks verified:"
for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
    echo "  ✓ ${fw}.xcframework"
done
