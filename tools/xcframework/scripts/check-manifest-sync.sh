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
CRASH_REPORTER_PACKAGE="${REPO_ROOT}/SplunkCrashReporter/Package.swift"
AGENT_PROJECT="${TOOLS_ROOT}/Project.swift"
OTEL_PROJECT="${TOOLS_ROOT}/otel/Project.swift"
SMOKE_PROJECT="${TOOLS_ROOT}/smoke-test/Project.swift"
DEPENDENCY_MANIFEST_SCRIPT="${TOOLS_ROOT}/scripts/generate-dependency-manifest.sh"
AGENT_BUILD_SCRIPT="${TOOLS_ROOT}/scripts/build-xcframeworks.sh"
OTEL_BUILD_SCRIPT="${TOOLS_ROOT}/scripts/build-otel-xcframeworks.sh"

ERRORS=0

EXPECTED_EXTERNAL_XCFRAMEWORKS=(
    "OpenTelemetryApi"
    "OpenTelemetrySdk"
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
    "SplunkCrashReporter"
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

require_grep_in_settings() {
    local settings_name="$1"
    local pattern="$2"
    local file="$3"
    local label="$4"

    if awk -v settings_name="${settings_name}" -v pattern="${pattern}" '
        $0 ~ "^let " settings_name "[[:space:]]*:" {
            in_settings = 1
            next
        }
        in_settings && $0 ~ "^let " {
            in_settings = 0
        }
        in_settings && index($0, pattern) {
            found = 1
        }
        END {
            exit(found ? 0 : 1)
        }
    ' "${file}"; then
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

    require_grep '\.iOS\(\.v15\)' "${PACKAGE_SWIFT}" "Package.swift iOS 15"
    require_grep '\.tvOS\(\.v15\)' "${PACKAGE_SWIFT}" "Package.swift tvOS 15"
    require_grep '\.visionOS\(\.v1\)' "${PACKAGE_SWIFT}" "Package.swift visionOS 1"
    require_grep '\.macCatalyst\(\.v15\)' "${PACKAGE_SWIFT}" "Package.swift macCatalyst 15"
    require_grep '\.iOS\(\.v15\)' "${CRASH_REPORTER_PACKAGE}" "SplunkCrashReporter Package.swift iOS 15"

    for project in "${AGENT_PROJECT}" "${OTEL_PROJECT}"; do
        local label
        label="${project#${TOOLS_ROOT}/}"

        require_grep_in_settings "sharedSettings" '"IPHONEOS_DEPLOYMENT_TARGET": "15.0"' "${project}" "${label} sharedSettings iOS 15.0"
        require_grep_in_settings "sharedSettings" '"TVOS_DEPLOYMENT_TARGET": "15.0"' "${project}" "${label} sharedSettings tvOS 15.0"
        require_grep_in_settings "sharedSettings" '"MACOSX_DEPLOYMENT_TARGET": "12.0"' "${project}" "${label} sharedSettings macCatalyst 15 / macOS 12.0"
    done

    require_grep_in_settings "sharedSettings" '"XROS_DEPLOYMENT_TARGET": "1.0"' "${AGENT_PROJECT}" "Project.swift sharedSettings visionOS 1.0"
    require_grep_in_settings "crashReporterSettings" '"IPHONEOS_DEPLOYMENT_TARGET": "15.0"' "${AGENT_PROJECT}" "Project.swift crashReporterSettings iOS 15.0"
    require_grep_in_settings "sharedSettings" '"XROS_DEPLOYMENT_TARGET": "1.0"' "${OTEL_PROJECT}" "otel/Project.swift sharedSettings visionOS 1.0"

    for script in "${AGENT_BUILD_SCRIPT}" "${OTEL_BUILD_SCRIPT}"; do
        local label
        label="${script#${TOOLS_ROOT}/}"

        require_grep 'label.*==.*maccatalyst|maccatalyst.*label' "${script}" "${label} has Catalyst-specific archive handling"
        require_grep 'IPHONEOS_DEPLOYMENT_TARGET=15\.0' "${script}" "${label} sets Catalyst IPHONEOS_DEPLOYMENT_TARGET to 15.0"
    done
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
