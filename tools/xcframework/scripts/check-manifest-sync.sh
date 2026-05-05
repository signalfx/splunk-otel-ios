#!/bin/bash
# tools/xcframework/scripts/check-manifest-sync.sh
#
# Checks the Package.swift and Tuist manifests for the monolithic
# xcframework distribution invariants. Target-name parity is not the right
# signal anymore because internal Splunk modules intentionally stop being
# shipped as separate xcframeworks.
#
# Usage:
#   ./scripts/check-manifest-sync.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"

PACKAGE_SWIFT="${REPO_ROOT}/Package.swift"
AGENT_PROJECT="${TOOLS_ROOT}/Project.swift"
OTEL_PROJECT="${TOOLS_ROOT}/otel/Project.swift"
BUILD_SCRIPT="${TOOLS_ROOT}/scripts/build-xcframeworks.sh"
VALIDATE_SCRIPT="${TOOLS_ROOT}/scripts/validate-xcframeworks.sh"
MANIFEST_SCRIPT="${TOOLS_ROOT}/scripts/generate-dependency-manifest.sh"

ERRORS=0

log() {
    echo "==> $*"
}

error() {
    echo "  ✗ $*"
    ERRORS=$((ERRORS + 1))
}

pass() {
    echo "  ✓ $*"
}

require_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -qE "${pattern}" "${file}"; then
        pass "${description}"
    else
        error "${description}"
    fi
}

require_absent() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -qE "${pattern}" "${file}"; then
        error "${description}"
    else
        pass "${description}"
    fi
}

log "Checking monolithic xcframework manifest invariants..."

log "Checking shipped artifact list..."
for shipped in SplunkAgent SplunkAgentObjC OpenTelemetryApi OpenTelemetrySdk CrashReporter; do
    require_contains "${VALIDATE_SCRIPT}" "\"${shipped}\"" "${shipped} is validated as shipped"
    require_contains "${MANIFEST_SCRIPT}" "\"${shipped}\\.xcframework\"" "${shipped} is listed in dependency manifest"
done

for hidden in SplunkCommon SplunkNavigation SplunkNetwork SplunkNetworkMonitor SplunkSlowFrameDetector SplunkCrashReports SplunkOpenTelemetry SplunkOpenTelemetryBackgroundExporter SplunkInteractions SplunkAppStart SplunkAppState SplunkWebView SplunkCustomTracking SplunkSessionReplayProxy CiscoCommon CiscoLogger CiscoEncryption CiscoSwizzling CiscoInteractions CiscoDiskStorage CiscoSessionReplay CiscoInstanceManager CiscoRuntimeCache; do
    require_absent "${BUILD_SCRIPT}" "^[[:space:]]*${hidden}[[:space:]]*$" "${hidden} is not created as a shipped xcframework"
    require_absent "${MANIFEST_SCRIPT}" "\"${hidden}\\.xcframework\"" "${hidden} is not listed as a shipped dependency"
done

log "Checking Tuist target products and dependencies..."
if python3 - "${AGENT_PROJECT}" <<'PY'
import re
import sys
from pathlib import Path

project = Path(sys.argv[1]).read_text()

expected_dynamic = {"SplunkAgent", "SplunkAgentObjC"}
expected_static = {
    "SplunkAppStart",
    "SplunkAppState",
    "SplunkCommon",
    "SplunkCrashReports",
    "SplunkCustomTracking",
    "SplunkInteractions",
    "SplunkNavigation",
    "SplunkNetwork",
    "SplunkNetworkMonitor",
    "SplunkOpenTelemetry",
    "SplunkOpenTelemetryBackgroundExporter",
    "SplunkSessionReplayProxy",
    "SplunkSlowFrameDetector",
    "SplunkWebView",
}

targets = {}
for match in re.finditer(r'\.target\(\s*name:\s*"([^"]+)"(?P<body>.*?)(?=\n\s*// =================================================================|\n\s*\]\n\))', project, re.S):
    name = match.group(1)
    body = match.group("body")
    product_match = re.search(r"product:\s*\.(\w+)", body)
    targets[name] = product_match.group(1) if product_match else None

errors = []
for name in expected_dynamic:
    if targets.get(name) != "framework":
        errors.append(f"{name} must be a dynamic framework target")

for name in expected_static:
    if targets.get(name) != "staticFramework":
        errors.append(f"{name} must be an internal static framework target")

dynamic_splunk = sorted(name for name, product in targets.items() if name.startswith("Splunk") and product == "framework")
if set(dynamic_splunk) != expected_dynamic:
    errors.append(f"dynamic Splunk targets are {dynamic_splunk}, expected {sorted(expected_dynamic)}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
then
    pass "Project.swift uses dynamic products only for SplunkAgent and SplunkAgentObjC"
else
    error "Project.swift target product invariant failed"
fi

require_contains "${AGENT_PROJECT}" 'dep\("CrashReporter", condition: noCrashReporterCondition\)' "SplunkAgent links CrashReporter only outside visionOS"
require_contains "${AGENT_PROJECT}" 'mod\("SplunkAgent"\)' "SplunkAgentObjC depends on SplunkAgent"
require_contains "${AGENT_PROJECT}" 'dep\("OpenTelemetryApi"\)' "SplunkAgentObjC links OpenTelemetryApi for ObjC attribute conversion"
if python3 - "${AGENT_PROJECT}" <<'PY'
import re
import sys
from pathlib import Path

project = Path(sys.argv[1]).read_text()
match = re.search(r'name:\s*"SplunkAgentObjC"(?P<body>.*?)(?=\n\s*\]\n\))', project, re.S)
if not match:
    print("SplunkAgentObjC target not found")
    sys.exit(1)

body = match.group("body")
forbidden = [
    "SplunkCommon",
    "SplunkInteractions",
    "SplunkNavigation",
    "SplunkNetworkMonitor",
    "SplunkSlowFrameDetector",
    "SplunkCrashReports",
]

leaks = [name for name in forbidden if f'mod("{name}"' in body]
if leaks:
    print(", ".join(leaks))
    sys.exit(1)
PY
then
    pass "SplunkAgentObjC does not link internal Splunk modules"
else
    error "SplunkAgentObjC links internal Splunk modules"
fi

log "Checking OTel helper manifest..."
for otel_target in OpenTelemetryApi OpenTelemetrySdk; do
    require_contains "${OTEL_PROJECT}" "\"${otel_target}\"" "${otel_target} exists in otel/Project.swift"
done

echo ""
if [[ "${ERRORS}" -gt 0 ]]; then
    echo "ERROR: ${ERRORS} manifest invariant issue(s) found."
    exit 1
else
    log "Manifest invariants passed ✓"
fi
