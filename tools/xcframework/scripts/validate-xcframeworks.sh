#!/bin/bash
# tools/xcframework/scripts/validate-xcframeworks.sh
#
# Validates the complete xcframework distribution in the output directory.
# This is a hard gate: if any check fails, the script exits non-zero.
#
# Usage:
#   ./scripts/validate-xcframeworks.sh
#   RELEASE=true ./scripts/validate-xcframeworks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

RELEASE="${RELEASE:-false}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

EXPECTED_ALL_SLICES=7
EXPECTED_NO_VISIONOS_SLICES=5

EXPECTED_FRAMEWORKS=(
    "OpenTelemetryApi"
    "OpenTelemetrySdk"
    "CrashReporter"
    "CiscoCommon"
    "CiscoLogger"
    "CiscoEncryption"
    "CiscoSwizzling"
    "CiscoInteractions"
    "CiscoDiskStorage"
    "CiscoSessionReplay"
    "CiscoInstanceManager"
    "CiscoRuntimeCache"
    "SplunkCommon"
    "SplunkNavigation"
    "SplunkNetwork"
    "SplunkNetworkMonitor"
    "SplunkSlowFrameDetector"
    "SplunkCrashReports"
    "SplunkOpenTelemetryBackgroundExporter"
    "SplunkOpenTelemetry"
    "SplunkInteractions"
    "SplunkAppStart"
    "SplunkAppState"
    "SplunkWebView"
    "SplunkCustomTracking"
    "SplunkSessionReplayProxy"
    "SplunkAgent"
    "SplunkAgentObjC"
)

NO_VISIONOS_MODULES="SplunkCrashReports CrashReporter"

log() {
    echo "==> $*"
}

check_pass() {
    echo "  OK: $1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

check_fail() {
    echo "  FAIL: $1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

is_expected_framework() {
    local name="$1"

    for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
        if [[ "${expected}" == "${name}" ]]; then
            return 0
        fi
    done

    return 1
}

expected_slices_for() {
    local name="$1"

    case " ${NO_VISIONOS_MODULES} " in
        *" ${name} "*)
            echo "${EXPECTED_NO_VISIONOS_SLICES}"
            ;;
        *)
            echo "${EXPECTED_ALL_SLICES}"
            ;;
    esac
}

validate_expected_framework_set() {
    log "Checking expected framework set"

    local actual_count=0
    for xcfw in "${OUTPUT_DIR}"/*.xcframework; do
        [[ -d "${xcfw}" ]] || continue
        actual_count=$((actual_count + 1))
    done

    if [[ "${actual_count}" -eq "${#EXPECTED_FRAMEWORKS[@]}" ]]; then
        check_pass "Framework count: ${actual_count}"
    else
        check_fail "Framework count: ${actual_count} (expected ${#EXPECTED_FRAMEWORKS[@]})"
    fi

    for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
        if [[ -d "${OUTPUT_DIR}/${expected}.xcframework" ]]; then
            check_pass "${expected}.xcframework present"
        else
            check_fail "${expected}.xcframework missing"
        fi
    done

    for xcfw in "${OUTPUT_DIR}"/*.xcframework; do
        [[ -d "${xcfw}" ]] || continue
        local name
        name="$(basename "${xcfw}" .xcframework)"

        if is_expected_framework "${name}"; then
            continue
        fi

        check_fail "Unexpected framework: ${name}.xcframework"
    done
}

validate_dynamic_binary() {
    local binary_path="$1"
    local slice_name="$2"
    local otool_output
    local header_count
    local dylib_count
    local filetypes

    otool_output="$(otool -hv -arch all "${binary_path}" 2>/dev/null || true)"
    header_count="$(
        printf '%s\n' "${otool_output}" |
            awk '$1 ~ /^(0x|MH_)/ { count++ } END { print count + 0 }'
    )"
    dylib_count="$(
        printf '%s\n' "${otool_output}" |
            awk '$1 ~ /^(0x|MH_)/ && $5 == "DYLIB" { count++ } END { print count + 0 }'
    )"

    if [[ "${header_count}" -gt 0 && "${header_count}" -eq "${dylib_count}" ]]; then
        check_pass "Slice ${slice_name}: Mach-O filetype DYLIB for all architectures"
    else
        filetypes="$(
            printf '%s\n' "${otool_output}" |
                awk '$1 ~ /^(0x|MH_)/ { print $5 }' |
                sort -u |
                tr '\n' ' ' |
                sed 's/[[:space:]]*$//'
        )"
        check_fail "Slice ${slice_name}: binary is not MH_DYLIB for every architecture (${filetypes:-unknown})"
    fi
}

read_xcframework_library_value() {
    local info_plist="$1"
    local index="$2"
    local key="$3"

    /usr/libexec/PlistBuddy -c "Print :AvailableLibraries:${index}:${key}" "${info_plist}" 2>/dev/null
}

validate_xcframework() {
    local xcfw_path="$1"
    local name
    name="$(basename "${xcfw_path}" .xcframework)"

    echo ""
    log "Validating ${name}.xcframework"

    if [[ -f "${xcfw_path}/Info.plist" ]]; then
        check_pass "Info.plist exists"
    else
        check_fail "Info.plist missing"
        return
    fi

    local expected_slices
    expected_slices="$(expected_slices_for "${name}")"

    local actual_slices=0
    local info_plist="${xcfw_path}/Info.plist"
    local slice_entries=()
    local index=0

    while true; do
        local library_identifier
        local binary_path
        local library_path

        if ! library_identifier="$(read_xcframework_library_value "${info_plist}" "${index}" "LibraryIdentifier")"; then
            break
        fi

        binary_path="$(read_xcframework_library_value "${info_plist}" "${index}" "BinaryPath" || true)"

        if ! library_path="$(read_xcframework_library_value "${info_plist}" "${index}" "LibraryPath")"; then
            check_fail "Slice ${library_identifier}: LibraryPath missing in Info.plist"
            index=$((index + 1))
            continue
        fi

        if [[ -z "${binary_path}" ]]; then
            binary_path="${library_path}/${name}"
        fi

        slice_entries+=("${library_identifier}|${binary_path}")
        actual_slices=$((actual_slices + 1))
        index=$((index + 1))
    done

    if [[ "${actual_slices}" -eq "${expected_slices}" ]]; then
        check_pass "Platform slices: ${actual_slices}"
    else
        check_fail "Platform slices: ${actual_slices} (expected ${expected_slices})"
    fi

    for slice_entry in "${slice_entries[@]}"; do
        local slice_name="${slice_entry%%|*}"
        local binary_path="${slice_entry#*|}"

        local fw_binary="${xcfw_path}/${slice_name}/${binary_path}"
        if [[ -f "${fw_binary}" ]]; then
            check_pass "Slice ${slice_name}: binary present"
            validate_dynamic_binary "${fw_binary}" "${slice_name}"

            local arch_info
            arch_info="$(lipo -info "${fw_binary}" 2>/dev/null || echo "unknown")"
            if [[ "${arch_info}" != "unknown" ]]; then
                check_pass "Slice ${slice_name}: $(echo "${arch_info}" | sed 's/.*: //')"
            else
                check_fail "Slice ${slice_name}: cannot read architecture"
            fi
        else
            check_fail "Slice ${slice_name}: binary missing at ${fw_binary}"
        fi
    done

    local swiftinterface_count
    swiftinterface_count="$(find "${xcfw_path}" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${swiftinterface_count}" -gt 0 ]]; then
        check_pass ".swiftinterface files: ${swiftinterface_count} found"
    else
        local swiftmodule_count
        swiftmodule_count="$(find "${xcfw_path}" -name "*.swiftmodule" -type d 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "${swiftmodule_count}" -eq 0 ]]; then
            echo "  WARN: No .swiftinterface files (ObjC-only framework, expected)"
        else
            check_fail "No .swiftinterface files found"
        fi
    fi

    local dsym_count
    dsym_count="$(find "${xcfw_path}" -name "*.dSYM" -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${dsym_count}" -gt 0 ]]; then
        check_pass "dSYM bundles: ${dsym_count} found"
    else
        echo "  WARN: No dSYMs found"
    fi

    if [[ "${RELEASE}" == "true" ]]; then
        if codesign --verify --deep --strict "${xcfw_path}" 2>/dev/null; then
            check_pass "Code signature valid"
        else
            check_fail "Code signature invalid or missing (required for release)"
        fi
    fi
}

main() {
    log "Validating xcframeworks in ${OUTPUT_DIR}"
    if [[ "${RELEASE}" == "true" ]]; then
        log "Release mode: signature verification enabled"
    fi

    if [[ ! -d "${OUTPUT_DIR}" ]]; then
        echo "ERROR: Output directory not found: ${OUTPUT_DIR}"
        exit 1
    fi

    validate_expected_framework_set

    for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
        local xcfw="${OUTPUT_DIR}/${expected}.xcframework"
        [[ -d "${xcfw}" ]] || continue
        validate_xcframework "${xcfw}"
    done

    echo ""
    echo "============================================================"
    echo "  Validation Summary"
    echo "============================================================"
    echo "  XCFrameworks: ${#EXPECTED_FRAMEWORKS[@]}"
    echo "  Total checks: ${TOTAL_CHECKS}"
    echo "  Passed:       ${PASSED_CHECKS}"
    echo "  Failed:       ${FAILED_CHECKS}"
    echo ""

    if [[ "${FAILED_CHECKS}" -gt 0 ]]; then
        echo "ERROR: ${FAILED_CHECKS} validation checks failed."
        exit 1
    fi

    log "All validation checks passed"
}

main "$@"
