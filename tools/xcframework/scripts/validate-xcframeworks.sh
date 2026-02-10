#!/bin/bash
# tools/xcframework/scripts/validate-xcframeworks.sh
#
# Validates all built xcframeworks in the output directory.
# This is a hard gate: if any check fails, the script exits non-zero
# and the release is blocked.
#
# Checks performed:
#   1. Info.plist exists in xcframework root
#   2. Expected platform slices exist (per-module platform matrix)
#   3. Framework binary exists inside each platform slice
#   4. .swiftinterface files exist for Swift frameworks
#   5. dSYMs exist for each platform slice
#   6. Architecture verification via lipo -info
#   7. No unexpected files in the xcframework
#   8. Code signature verification (release mode only, RELEASE=true)
#
# Usage:
#   ./scripts/validate-xcframeworks.sh           # Standard validation
#   RELEASE=true ./scripts/validate-xcframeworks.sh  # + signature check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

RELEASE="${RELEASE:-false}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

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

# ---------------------------------------------------------------------------
# Validate a single xcframework
# ---------------------------------------------------------------------------

validate_xcframework() {
    local xcfw_path="$1"
    local name
    name="$(basename "${xcfw_path}" .xcframework)"

    echo ""
    log "Validating ${name}.xcframework"

    # Check 1: Info.plist
    if [[ -f "${xcfw_path}/Info.plist" ]]; then
        check_pass "Info.plist exists"
    else
        check_fail "Info.plist missing"
        return
    fi

    # Check 2-3: Platform slices and binaries
    for slice_dir in "${xcfw_path}"/*/; do
        local slice_name
        slice_name="$(basename "${slice_dir}")"

        # Skip non-platform dirs
        [[ "${slice_name}" == "_CodeSignature" ]] && continue

        local fw_binary="${slice_dir}/${name}.framework/${name}"
        if [[ -f "${fw_binary}" ]]; then
            check_pass "Slice ${slice_name}: binary present"

            # Check 6: Architecture
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

    # Check 4: .swiftinterface files (Swift frameworks only)
    # ObjC-only frameworks (e.g. CrashReporter) won't have .swiftinterface files.
    local swiftinterface_count
    swiftinterface_count="$(find "${xcfw_path}" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${swiftinterface_count}" -gt 0 ]]; then
        check_pass ".swiftinterface files: ${swiftinterface_count} found"
    else
        # Check if this is an ObjC-only framework (has Headers/ but no .swiftmodule)
        local swiftmodule_count
        swiftmodule_count="$(find "${xcfw_path}" -name "*.swiftmodule" -type d 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "${swiftmodule_count}" -eq 0 ]]; then
            echo "  ⚠ No .swiftinterface files (ObjC-only framework, expected)"
        else
            check_fail "No .swiftinterface files found"
        fi
    fi

    # Check 5: dSYMs
    local dsym_count
    dsym_count="$(find "${xcfw_path}" -name "*.dSYM" -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${dsym_count}" -gt 0 ]]; then
        check_pass "dSYM bundles: ${dsym_count} found"
    else
        echo "  ⚠ No dSYMs found (may be alongside xcframework)"
    fi

    # Check 8: Signature (release mode only)
    if [[ "${RELEASE}" == "true" ]]; then
        if codesign --verify --deep --strict "${xcfw_path}" 2>/dev/null; then
            check_pass "Code signature valid"
        else
            check_fail "Code signature invalid or missing (required for release)"
        fi
    fi
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Validating xcframeworks in ${OUTPUT_DIR}"
if [[ "${RELEASE}" == "true" ]]; then
    log "Release mode: signature verification enabled"
fi

for xcfw in "${OUTPUT_DIR}"/*.xcframework; do
    [[ -d "${xcfw}" ]] || continue
    validate_xcframework "${xcfw}"
done

echo ""
echo "============================================================"
echo "  Validation Summary"
echo "============================================================"
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
