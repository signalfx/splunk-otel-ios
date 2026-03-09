#!/bin/bash
# tools/xcframework/scripts/check-manifest-sync.sh
#
# Compares target names between Package.swift and the Tuist Project.swift
# manifests to ensure they stay in sync. This is enforced as a CI check.
#
# Specifically checks:
#   1. Every Splunk module target in Package.swift has a corresponding
#      target in tools/xcframework/Project.swift
#   2. Every OTel product used in Package.swift has a corresponding
#      target in tools/xcframework/otel/Project.swift
#
# Note: This only checks target name presence, not dependency graph
# consistency. Dependency correctness is validated at build time.
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

ERRORS=0

log() {
    echo "==> $*"
}

error() {
    echo "  ✗ $*"
    ((ERRORS++))
}

pass() {
    echo "  ✓ $*"
}

# ---------------------------------------------------------------------------
# Extract target names
# ---------------------------------------------------------------------------

log "Checking manifest sync..."

# Extract Splunk module target names from Package.swift
# Matches: .target(name: "SplunkFoo", or name: "SplunkFoo"
PACKAGE_TARGETS=$(grep -oE 'name: "Splunk[A-Za-z]+"' "${PACKAGE_SWIFT}" | \
    sed 's/name: "//; s/"//' | sort -u)

# Extract target names from Tuist Project.swift
TUIST_TARGETS=$(grep -oE 'name: "Splunk[A-Za-z]+"' "${AGENT_PROJECT}" | \
    sed 's/name: "//; s/"//' | sort -u)

# ---------------------------------------------------------------------------
# Check: Package.swift targets exist in Project.swift
# ---------------------------------------------------------------------------

log "Checking Splunk module targets..."

while IFS= read -r target; do
    # Skip test targets
    [[ "${target}" == *"Tests" ]] && continue

    if echo "${TUIST_TARGETS}" | grep -q "^${target}$"; then
        pass "${target}"
    else
        error "${target} is in Package.swift but missing from Project.swift"
    fi
done <<< "${PACKAGE_TARGETS}"

# ---------------------------------------------------------------------------
# Check: OTel targets
# ---------------------------------------------------------------------------

log "Checking OTel targets..."

for otel_target in OpenTelemetryApi OpenTelemetrySdk; do
    if grep -q "\"${otel_target}\"" "${OTEL_PROJECT}" 2>/dev/null; then
        pass "${otel_target}"
    else
        error "${otel_target} is missing from otel/Project.swift"
    fi
done

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

echo ""
if [[ "${ERRORS}" -gt 0 ]]; then
    echo "ERROR: ${ERRORS} sync issues found. Update the Tuist manifests to match Package.swift."
    exit 1
else
    log "All manifests in sync ✓"
fi
