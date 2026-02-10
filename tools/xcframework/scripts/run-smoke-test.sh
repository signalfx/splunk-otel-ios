#!/bin/bash
# tools/xcframework/scripts/run-smoke-test.sh
#
# Builds the XCFramework smoke test app to verify all built xcframeworks
# can be linked and basic types are accessible.
#
# This script:
#   1. Generates the Tuist project for the smoke test
#   2. Builds for iOS Simulator
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
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"
DEPS_DIR="${TOOLS_ROOT}/dependencies"


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

# Built frameworks (in output/xcframeworks/)
BUILT_FRAMEWORKS=(
    "SplunkAgent"
    "SplunkCommon"
    "OpenTelemetryApi"
    "OpenTelemetrySdk"
    "CrashReporter"
)

# External frameworks (in dependencies/)
EXTERNAL_FRAMEWORKS=(
    "CiscoLogger"
    "CiscoSessionReplay"
)

ALL_PRESENT=true
for fw in "${BUILT_FRAMEWORKS[@]}"; do
    if [[ -d "${OUTPUT_DIR}/${fw}.xcframework" ]]; then
        echo "  ✓ ${fw}.xcframework (output)"
    else
        echo "  ✗ ${fw}.xcframework MISSING from output/"
        ALL_PRESENT=false
    fi
done

for fw in "${EXTERNAL_FRAMEWORKS[@]}"; do
    if [[ -d "${DEPS_DIR}/${fw}.xcframework" ]]; then
        echo "  ✓ ${fw}.xcframework (dependencies)"
    else
        echo "  ✗ ${fw}.xcframework MISSING from dependencies/"
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
log "Xcode project generated"


# ---------------------------------------------------------------------------
# Step 3: Build for iOS Simulator
# ---------------------------------------------------------------------------

log_step "Step 3: Build smoke test app for iOS Simulator"

# Resolve a simulator destination
DESTINATION="generic/platform=iOS Simulator"

xcodebuild build \
    -workspace "${SMOKE_TEST_DIR}/XCFrameworkSmokeTest.xcworkspace" \
    -scheme "XCFrameworkSmokeTest" \
    -destination "${DESTINATION}" \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tail -20

BUILD_EXIT=$?

if [[ ${BUILD_EXIT} -ne 0 ]]; then
    echo ""
    echo "ERROR: Smoke test build FAILED"
    exit 1
fi


# ---------------------------------------------------------------------------
# Step 4: Report
# ---------------------------------------------------------------------------

log_step "Smoke test passed"

echo "All xcframeworks linked successfully."
echo "Built frameworks verified:"
for fw in "${OUTPUT_DIR}"/*.xcframework; do
    echo "  ✓ $(basename "${fw}")"
done
echo "External frameworks verified:"
for fw in "${DEPS_DIR}"/*.xcframework; do
    echo "  ✓ $(basename "${fw}")"
done
