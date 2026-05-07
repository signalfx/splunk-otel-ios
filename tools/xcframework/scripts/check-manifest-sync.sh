#!/bin/bash
# tools/xcframework/scripts/check-manifest-sync.sh
#
# Checks the Package.swift / Tuist xcframework manifests for release-relevant
# drift: Splunk target presence, deployment targets, and expected xcframework
# dependency lists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"

PACKAGE_SWIFT="${REPO_ROOT}/Package.swift"
AGENT_PROJECT="${TOOLS_ROOT}/Project.swift"
OTEL_PROJECT="${TOOLS_ROOT}/otel/Project.swift"
PLCRASH_PROJECT="${TOOLS_ROOT}/plcrash/Project.swift"
SMOKE_PROJECT="${TOOLS_ROOT}/smoke-test/Project.swift"
DEPENDENCY_MANIFEST_SCRIPT="${TOOLS_ROOT}/scripts/generate-dependency-manifest.sh"

ERRORS=0

EXPECTED_EXTERNAL_XCFRAMEWORKS=(
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
)

EXPECTED_DISTRIBUTION_FRAMEWORKS=(
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

log() {
    echo "==> $*"
}

error() {
    echo "  FAIL: $*"
    ERRORS=$((ERRORS + 1))
}

pass() {
    echo "  OK: $*"
}

require_grep() {
    local pattern="$1"
    local file="$2"
    local label="$3"

    if grep -qE "${pattern}" "${file}"; then
        pass "${label}"
    else
        error "${label}"
    fi
}

check_splunk_targets() {
    log "Checking Splunk module targets"

    local package_targets
    local tuist_targets

    package_targets="$(grep -oE 'name: "Splunk[A-Za-z]+"' "${PACKAGE_SWIFT}" | sed 's/name: "//; s/"//' | sort -u)"
    tuist_targets="$(grep -oE 'name: "Splunk[A-Za-z]+"' "${AGENT_PROJECT}" | sed 's/name: "//; s/"//' | sort -u)"

    while IFS= read -r target; do
        [[ -z "${target}" ]] && continue
        [[ "${target}" == *"Tests" ]] && continue

        if echo "${tuist_targets}" | grep -q "^${target}$"; then
            pass "${target}"
        else
            error "${target} is in Package.swift but missing from Project.swift"
        fi
    done <<< "${package_targets}"
}

check_deployment_targets() {
    log "Checking deployment target sync"

    require_grep '\.iOS\(\.v13\)' "${PACKAGE_SWIFT}" "Package.swift iOS 13"
    require_grep '\.tvOS\(\.v15\)' "${PACKAGE_SWIFT}" "Package.swift tvOS 15"
    require_grep '\.visionOS\(\.v1\)' "${PACKAGE_SWIFT}" "Package.swift visionOS 1"
    require_grep '\.macCatalyst\(\.v15\)' "${PACKAGE_SWIFT}" "Package.swift macCatalyst 15"

    for project in "${AGENT_PROJECT}" "${OTEL_PROJECT}" "${PLCRASH_PROJECT}"; do
        local label
        label="${project#${TOOLS_ROOT}/}"

        require_grep '"IPHONEOS_DEPLOYMENT_TARGET":[[:space:]]*"13\.0"' "${project}" "${label} iOS 13.0"
        require_grep '"TVOS_DEPLOYMENT_TARGET":[[:space:]]*"15\.0"' "${project}" "${label} tvOS 15.0"
        require_grep '"MACOSX_DEPLOYMENT_TARGET":[[:space:]]*"12\.0"' "${project}" "${label} macCatalyst 15 / macOS 12.0"
    done

    require_grep '"XROS_DEPLOYMENT_TARGET":[[:space:]]*"1\.0"' "${AGENT_PROJECT}" "Project.swift visionOS 1.0"
    require_grep '"XROS_DEPLOYMENT_TARGET":[[:space:]]*"1\.0"' "${OTEL_PROJECT}" "otel/Project.swift visionOS 1.0"
}

check_external_dependencies() {
    log "Checking external xcframework dependencies"

    for framework in "${EXPECTED_EXTERNAL_XCFRAMEWORKS[@]}"; do
        require_grep "dep\\(\"${framework}\"" "${AGENT_PROJECT}" "Project.swift references ${framework}"
    done
}

check_distribution_lists() {
    log "Checking distribution framework lists"

    for framework in "${EXPECTED_DISTRIBUTION_FRAMEWORKS[@]}"; do
        require_grep "\"${framework}\"" "${SMOKE_PROJECT}" "smoke test includes ${framework}"
        require_grep "\"${framework}\\.xcframework\"" "${DEPENDENCY_MANIFEST_SCRIPT}" "dependency manifest includes ${framework}"
    done
}

check_otel_targets() {
    log "Checking OTel targets"

    for otel_target in OpenTelemetryApi OpenTelemetrySdk; do
        require_grep "\"${otel_target}\"" "${OTEL_PROJECT}" "otel/Project.swift contains ${otel_target}"
    done
}

main() {
    log "Checking manifest sync"

    check_splunk_targets
    check_otel_targets
    check_deployment_targets
    check_external_dependencies
    check_distribution_lists

    echo ""
    if [[ "${ERRORS}" -gt 0 ]]; then
        echo "ERROR: ${ERRORS} sync issues found. Update the xcframework manifests to match Package.swift and release output expectations."
        exit 1
    fi

    log "All manifests in sync"
}

main "$@"
