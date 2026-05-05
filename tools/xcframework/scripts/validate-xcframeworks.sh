#!/bin/bash
# tools/xcframework/scripts/validate-xcframeworks.sh
#
# Validates the shipped monolithic binary distribution. This is a hard gate:
# if any check fails, the script exits non-zero and the release is blocked.
#
# Checks performed:
#   1. output/xcframeworks contains exactly the five shipped xcframeworks
#   2. Expected platform slices exist for each shipped xcframework
#   3. Framework binaries, architectures, swiftinterfaces, and dSYMs exist
#   4. Public surface files do not reference unshipped Splunk/Cisco modules
#   5. Cisco privacy manifest categories/reasons are covered by SplunkAgent
#   6. Dynamic load commands do not reference Cisco/internal Splunk modules
#   7. CrashReporter is not linked from visionOS SplunkAgent slices
#   8. SplunkAgentObjC does not duplicate internal static symbols
#   9. Code signature verification (release mode only, RELEASE=true)
#
# Usage:
#   ./scripts/validate-xcframeworks.sh
#   RELEASE=true ./scripts/validate-xcframeworks.sh

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"
DEPS_DIR="${TOOLS_ROOT}/dependencies"

RELEASE="${RELEASE:-false}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

EXPECTED_FRAMEWORKS=(
    "SplunkAgent"
    "SplunkAgentObjC"
    "OpenTelemetryApi"
    "OpenTelemetrySdk"
    "CrashReporter"
)

FORBIDDEN_REFERENCES=(
    "SplunkAppStart"
    "SplunkAppState"
    "SplunkCommon"
    "SplunkCrashReports"
    "SplunkCustomTracking"
    "SplunkInteractions"
    "SplunkNavigation"
    "SplunkNetwork"
    "SplunkNetworkMonitor"
    "SplunkOpenTelemetry"
    "SplunkOpenTelemetryBackgroundExporter"
    "SplunkSessionReplayProxy"
    "SplunkSlowFrameDetector"
    "SplunkWebView"
    "CiscoCommon"
    "CiscoDiskStorage"
    "CiscoEncryption"
    "CiscoInstanceManager"
    "CiscoInteractions"
    "CiscoLogger"
    "CiscoRuntimeCache"
    "CiscoSessionReplay"
    "CiscoSwizzling"
)

EXPECTED_ALL_SLICES=7
EXPECTED_NO_VISIONOS_SLICES=5

log() {
    echo "==> $*"
}

check_pass() {
    echo "  ✓ $1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

check_fail() {
    echo "  ✗ FAIL: $1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

contains_expected_framework() {
    local candidate="$1"

    for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
        if [[ "${candidate}" == "${expected}" ]]; then
            return 0
        fi
    done

    return 1
}

expected_slices_for() {
    local name="$1"

    case "${name}" in
        CrashReporter)
            echo "${EXPECTED_NO_VISIONOS_SLICES}"
            ;;
        *)
            echo "${EXPECTED_ALL_SLICES}"
            ;;
    esac
}

framework_binary_path() {
    local xcfw_path="$1"
    local name="$2"
    local slice_name="$3"

    echo "${xcfw_path}/${slice_name}/${name}.framework/${name}"
}

check_exact_output_set() {
    log "Checking exact shipped xcframework set"

    for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
        if [[ -d "${OUTPUT_DIR}/${expected}.xcframework" ]]; then
            check_pass "${expected}.xcframework present"
        else
            check_fail "${expected}.xcframework missing"
        fi
    done

    local actual_count=0
    for xcfw in "${OUTPUT_DIR}"/*.xcframework; do
        [[ -d "${xcfw}" ]] || continue
        actual_count=$((actual_count + 1))

        local name
        name="$(basename "${xcfw}" .xcframework)"
        if contains_expected_framework "${name}"; then
            check_pass "${name}.xcframework is an expected artifact"
        else
            check_fail "Unexpected artifact present: ${name}.xcframework"
        fi
    done

    if [[ "${actual_count}" -eq "${#EXPECTED_FRAMEWORKS[@]}" ]]; then
        check_pass "Artifact count: ${actual_count}"
    else
        check_fail "Artifact count: ${actual_count} (expected ${#EXPECTED_FRAMEWORKS[@]})"
    fi
}

validate_public_surface_leaks() {
    local xcfw_path="$1"
    local name="$2"

    case "${name}" in
        SplunkAgent|SplunkAgentObjC)
            ;;
        *)
            return
            ;;
    esac

    local surface_files=()
    while IFS= read -r -d '' file; do
        surface_files+=("${file}")
    done < <(
        find "${xcfw_path}" -path "*.dSYM/*" -prune -o -type f \
            \( -name "*.swiftinterface" \
            -o -name "*-Swift.h" \
            -o -name "module.modulemap" \
            -o -name "${name}.h" \) \
            -print0
    )

    if [[ "${#surface_files[@]}" -eq 0 ]]; then
        check_fail "${name}: no public surface files found for leak validation"
        return
    fi

    local leaks_found=0
    for file in "${surface_files[@]}"; do
        for reference in "${FORBIDDEN_REFERENCES[@]}"; do
            if grep -E "(^|[^A-Za-z0-9_])${reference}([^A-Za-z0-9_]|$)" "${file}" >/dev/null; then
                check_fail "${name}: forbidden reference ${reference} in ${file#${xcfw_path}/}"
                leaks_found=1
            fi
        done
    done

    if [[ "${leaks_found}" -eq 0 ]]; then
        check_pass "${name}: no hidden Splunk/Cisco references in public surface files"
    fi
}

validate_dynamic_loads() {
    local xcfw_path="$1"
    local name="$2"

    for slice_dir in "${xcfw_path}"/*/; do
        local slice_name
        slice_name="$(basename "${slice_dir}")"
        [[ "${slice_name}" == "_CodeSignature" ]] && continue

        local fw_binary
        fw_binary="$(framework_binary_path "${xcfw_path}" "${name}" "${slice_name}")"
        [[ -f "${fw_binary}" ]] || continue

        local load_commands
        load_commands="$(otool -L "${fw_binary}" 2>/dev/null || true)"

        local bad_loads=0
        for reference in "${FORBIDDEN_REFERENCES[@]}"; do
            if grep -E "(^|[^A-Za-z0-9_])${reference}([^A-Za-z0-9_]|$)" <<< "${load_commands}" >/dev/null; then
                check_fail "${name} ${slice_name}: forbidden dynamic load command references ${reference}"
                bad_loads=1
            fi
        done

        if [[ "${name}" == "SplunkAgent" && "${slice_name}" == xros* ]] && grep -E '(^|[^A-Za-z0-9_])CrashReporter([^A-Za-z0-9_]|$)' <<< "${load_commands}" >/dev/null; then
            check_fail "SplunkAgent ${slice_name}: CrashReporter load command is not allowed on visionOS"
            bad_loads=1
        fi

        if [[ "${name}" == "SplunkAgentObjC" ]] && grep -E '(^|[^A-Za-z0-9_])CrashReporter([^A-Za-z0-9_]|$)' <<< "${load_commands}" >/dev/null; then
            check_fail "SplunkAgentObjC ${slice_name}: CrashReporter load command is not allowed"
            bad_loads=1
        fi

        if [[ "${bad_loads}" -eq 0 ]]; then
            check_pass "${name} ${slice_name}: dynamic load commands are clean"
        fi
    done
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
    for slice_dir_count in "${xcfw_path}"/*/; do
        local slice_name
        slice_name="$(basename "${slice_dir_count}")"
        [[ "${slice_name}" == "_CodeSignature" ]] && continue
        [[ -d "${slice_dir_count}" ]] || continue
        actual_slices=$((actual_slices + 1))
    done

    if [[ "${actual_slices}" -eq "${expected_slices}" ]]; then
        check_pass "Platform slices: ${actual_slices} (expected ${expected_slices})"
    else
        check_fail "Platform slices: ${actual_slices} (expected ${expected_slices})"
    fi

    for slice_dir in "${xcfw_path}"/*/; do
        local slice_name
        slice_name="$(basename "${slice_dir}")"
        [[ "${slice_name}" == "_CodeSignature" ]] && continue

        local fw_binary
        fw_binary="$(framework_binary_path "${xcfw_path}" "${name}" "${slice_name}")"
        if [[ -f "${fw_binary}" ]]; then
            check_pass "Slice ${slice_name}: binary present"

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
    swiftinterface_count="$(find "${xcfw_path}" -path "*.dSYM/*" -prune -o -name "*.swiftinterface" -type f -print 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${swiftinterface_count}" -gt 0 ]]; then
        check_pass ".swiftinterface files: ${swiftinterface_count} found"
    else
        local swiftmodule_count
        swiftmodule_count="$(find "${xcfw_path}" -name "*.swiftmodule" -type d 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "${swiftmodule_count}" -eq 0 ]]; then
            echo "  ⚠ No .swiftinterface files (ObjC-only framework, expected)"
        else
            check_fail "No .swiftinterface files found"
        fi
    fi

    local dsym_count
    dsym_count="$(find "${xcfw_path}" -name "*.dSYM" -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${dsym_count}" -gt 0 ]]; then
        check_pass "dSYM bundles: ${dsym_count} found"
    else
        echo "  ⚠ No dSYMs found (may be alongside xcframework)"
    fi

    validate_public_surface_leaks "${xcfw_path}" "${name}"
    validate_dynamic_loads "${xcfw_path}" "${name}"

    if [[ "${RELEASE}" == "true" ]]; then
        if codesign --verify --deep --strict "${xcfw_path}" 2>/dev/null; then
            check_pass "Code signature valid"
        else
            check_fail "Code signature invalid or missing (required for release)"
        fi
    fi
}

validate_privacy_manifest_superset() {
    log "Validating SplunkAgent privacy manifest covers Cisco manifests"

    local manifest="${REPO_ROOT}/SplunkAgent/Resources/PrivacyInfo.xcprivacy"
    if [[ ! -f "${manifest}" ]]; then
        check_fail "SplunkAgent privacy manifest missing at ${manifest}"
        return
    fi

    if [[ ! -d "${DEPS_DIR}" ]]; then
        check_fail "Dependencies directory missing at ${DEPS_DIR}"
        return
    fi

    local output
    if output="$(python3 - "${manifest}" "${DEPS_DIR}" <<'PY'
import plistlib
import sys
from pathlib import Path

root_manifest = Path(sys.argv[1])
deps_dir = Path(sys.argv[2])

def load(path):
    with path.open("rb") as handle:
        return plistlib.load(handle)

def accessed_pairs(manifest):
    pairs = set()
    for item in manifest.get("NSPrivacyAccessedAPITypes", []):
        category = item.get("NSPrivacyAccessedAPIType")
        for reason in item.get("NSPrivacyAccessedAPITypeReasons", []):
            if category and reason:
                pairs.add((category, reason))
    return pairs

def collected_pairs(manifest):
    pairs = set()
    for item in manifest.get("NSPrivacyCollectedDataTypes", []):
        data_type = item.get("NSPrivacyCollectedDataType")
        for purpose in item.get("NSPrivacyCollectedDataTypePurposes", []):
            if data_type and purpose:
                pairs.add((data_type, purpose))
    return pairs

root = load(root_manifest)
root_accessed = accessed_pairs(root)
root_collected = collected_pairs(root)
root_tracking = bool(root.get("NSPrivacyTracking", False))

missing = []
cisco_manifests = sorted(deps_dir.glob("Cisco*.xcframework/**/PrivacyInfo.xcprivacy"))
seen_payloads = set()

for manifest_path in cisco_manifests:
    manifest = load(manifest_path)
    payload_key = plistlib.dumps(manifest, sort_keys=True)
    if payload_key in seen_payloads:
        continue
    seen_payloads.add(payload_key)

    for pair in accessed_pairs(manifest) - root_accessed:
        missing.append(f"{manifest_path}: accessed API {pair[0]} reason {pair[1]}")

    for pair in collected_pairs(manifest) - root_collected:
        missing.append(f"{manifest_path}: collected data {pair[0]} purpose {pair[1]}")

    if bool(manifest.get("NSPrivacyTracking", False)) and not root_tracking:
        missing.append(f"{manifest_path}: NSPrivacyTracking=true")

if missing:
    print("\n".join(missing))
    sys.exit(1)

print(f"checked {len(cisco_manifests)} Cisco privacy manifests")
PY
)"; then
        check_pass "Privacy manifest covers Cisco declarations (${output})"
    else
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            check_fail "Privacy manifest drift: ${line}"
        done <<< "${output}"
    fi
}

validate_duplicate_static_symbols() {
    log "Checking SplunkAgentObjC for duplicated internal static symbols"

    local agent_xcfw="${OUTPUT_DIR}/SplunkAgent.xcframework"
    local objc_xcfw="${OUTPUT_DIR}/SplunkAgentObjC.xcframework"

    if [[ ! -d "${agent_xcfw}" || ! -d "${objc_xcfw}" ]]; then
        check_fail "Cannot run duplicate-symbol check without SplunkAgent and SplunkAgentObjC xcframeworks"
        return
    fi

    local pattern="Splunk(AppStart|AppState|Common|CrashReports|CustomTracking|Interactions|Navigation|Network|NetworkMonitor|OpenTelemetry|OpenTelemetryBackgroundExporter|SessionReplayProxy|SlowFrameDetector|WebView)|Cisco(Common|DiskStorage|Encryption|InstanceManager|Interactions|Logger|RuntimeCache|SessionReplay|Swizzling)"
    local duplicates_found=0

    for slice_dir in "${objc_xcfw}"/*/; do
        local slice_name
        slice_name="$(basename "${slice_dir}")"
        [[ "${slice_name}" == "_CodeSignature" ]] && continue

        local agent_binary
        local objc_binary
        agent_binary="$(framework_binary_path "${agent_xcfw}" "SplunkAgent" "${slice_name}")"
        objc_binary="$(framework_binary_path "${objc_xcfw}" "SplunkAgentObjC" "${slice_name}")"

        if [[ ! -f "${agent_binary}" || ! -f "${objc_binary}" ]]; then
            continue
        fi

        local agent_symbols
        local objc_symbols
        local duplicate_symbols
        agent_symbols="$(mktemp /tmp/splunk-agent-symbols.XXXXXX)"
        objc_symbols="$(mktemp /tmp/splunk-objc-symbols.XXXXXX)"
        duplicate_symbols="$(mktemp /tmp/splunk-duplicate-symbols.XXXXXX)"

        nm -gUj "${agent_binary}" 2>/dev/null | grep -E "${pattern}" | sort -u > "${agent_symbols}" || true
        nm -gUj "${objc_binary}" 2>/dev/null | grep -E "${pattern}" | sort -u > "${objc_symbols}" || true
        comm -12 "${agent_symbols}" "${objc_symbols}" > "${duplicate_symbols}" || true

        if [[ -s "${duplicate_symbols}" ]]; then
            check_fail "Duplicate internal/Cisco symbols in SplunkAgentObjC ${slice_name}: $(head -5 "${duplicate_symbols}" | tr '\n' ' ')"
            duplicates_found=1
        fi

        rm -f "${agent_symbols}" "${objc_symbols}" "${duplicate_symbols}"
    done

    if [[ "${duplicates_found}" -eq 0 ]]; then
        check_pass "No duplicated internal/Cisco symbols between SplunkAgent and SplunkAgentObjC"
    fi
}

log "Validating xcframeworks in ${OUTPUT_DIR}"
if [[ "${RELEASE}" == "true" ]]; then
    log "Release mode: signature verification enabled"
fi

check_exact_output_set

for expected in "${EXPECTED_FRAMEWORKS[@]}"; do
    xcfw="${OUTPUT_DIR}/${expected}.xcframework"
    [[ -d "${xcfw}" ]] || continue
    validate_xcframework "${xcfw}"
done

validate_privacy_manifest_superset
validate_duplicate_static_symbols

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
else
    log "All validation checks passed ✓"
fi
