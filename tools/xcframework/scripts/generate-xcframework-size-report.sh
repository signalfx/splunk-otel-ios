#!/bin/bash
# tools/xcframework/scripts/generate-xcframework-size-report.sh
#
# Measures the uncompressed XCFramework distribution and the Session Replay
# contribution. The report is packaged with the release artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output"
XCFW_DIR="${OUTPUT_DIR}/xcframeworks"
REPORT_PATH="${OUTPUT_DIR}/size-report.md"
IOS_ONLY="${IOS_ONLY:-false}"

CISCO_FRAMEWORKS=(
    "CiscoCommon"
    "CiscoLogger"
    "CiscoEncryption"
    "CiscoSwizzling"
    "CiscoInteractions"
    "CiscoDiskStorage"
    "CiscoSessionReplay"
    "CiscoInstanceManager"
    "CiscoRuntimeCache"
    "CiscoVideoEncoder"
    "CiscoScreenshot"
    "CiscoWireframe"
    "CiscoDataExporter"
    "CiscoSnapshotManager"
)

NEW_CISCO_FRAMEWORKS=(
    "CiscoVideoEncoder"
    "CiscoScreenshot"
    "CiscoWireframe"
    "CiscoDataExporter"
    "CiscoSnapshotManager"
)

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

size_kb() {
    du -sk "$1" | awk '{ print $1 }'
}

format_mib() {
    awk -v kib="$1" 'BEGIN { printf "%.2f MiB", kib / 1024 }'
}

sum_frameworks() {
    local total=0
    local framework
    for framework in "$@"; do
        local path="${XCFW_DIR}/${framework}.xcframework"
        [[ -d "${path}" ]] || fail "Required framework missing for size report: ${path}"
        total=$((total + $(size_kb "${path}")))
    done
    echo "${total}"
}

[[ -d "${XCFW_DIR}" ]] || fail "XCFramework output directory not found: ${XCFW_DIR}"

SDK_TOTAL_KB=0
FRAMEWORKS=()
for path in "${XCFW_DIR}"/*.xcframework; do
    [[ -d "${path}" ]] || continue
    FRAMEWORKS+=("$(basename "${path}" .xcframework)")
    SDK_TOTAL_KB=$((SDK_TOTAL_KB + $(size_kb "${path}")))
done
[[ "${#FRAMEWORKS[@]}" -gt 0 ]] || fail "No XCFrameworks found in ${XCFW_DIR}"

CISCO_TOTAL_KB="$(sum_frameworks "${CISCO_FRAMEWORKS[@]}")"
NEW_CISCO_TOTAL_KB="$(sum_frameworks "${NEW_CISCO_FRAMEWORKS[@]}")"
BASE_CISCO_FRAMEWORKS=("${CISCO_FRAMEWORKS[@]:0:9}")
BASE_CISCO_TOTAL_KB="$(sum_frameworks "${BASE_CISCO_FRAMEWORKS[@]}")"
if [[ "${IOS_ONLY}" == "true" ]]; then
    VARIANT="iOS-only"
else
    VARIANT="all-platforms"
fi

{
    echo "# Splunk iOS SDK XCFramework size report"
    echo
    echo "Variant: ${VARIANT}"
    echo
    echo "Sizes are uncompressed on-disk sizes of the complete XCFramework bundles, including all shipped platform and architecture slices."
    echo
    echo "| Distribution | Size |"
    echo "| --- | ---: |"
    echo "| Overall SDK distribution (${#FRAMEWORKS[@]} frameworks) | $(format_mib "${SDK_TOTAL_KB}") |"
    echo "| Session Replay frameworks (${#CISCO_FRAMEWORKS[@]} frameworks) | $(format_mib "${CISCO_TOTAL_KB}") |"
    echo "| Existing Session Replay modules (9 frameworks) | $(format_mib "${BASE_CISCO_TOTAL_KB}") |"
    echo "| Added Session Replay modules (5 frameworks) | $(format_mib "${NEW_CISCO_TOTAL_KB}") |"
    echo
    echo "## Framework sizes"
    echo
    echo "| XCFramework | Size |"
    echo "| --- | ---: |"
    for framework in "${FRAMEWORKS[@]}"; do
        echo "| ${framework}.xcframework | $(format_mib "$(size_kb "${XCFW_DIR}/${framework}.xcframework")") |"
    done
} > "${REPORT_PATH}"

echo "==> Wrote size report: ${REPORT_PATH}"
cat "${REPORT_PATH}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "${REPORT_PATH}" >> "${GITHUB_STEP_SUMMARY}"
fi
