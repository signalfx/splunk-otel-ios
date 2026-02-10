#!/bin/bash
# tools/xcframework/scripts/generate-dependency-manifest.sh
#
# Generates dependency-manifest.json that maps each product to its
# required xcframeworks. This helps customers know which xcframeworks
# they need to include in their project.
#
# The manifest is generated from the actual build output, not hardcoded,
# ensuring it's always accurate.
#
# Usage:
#   ./scripts/generate-dependency-manifest.sh [--version VERSION]
#
# Output:
#   output/dependency-manifest.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output"
XCFW_DIR="${OUTPUT_DIR}/xcframeworks"
MANIFEST_PATH="${OUTPUT_DIR}/dependency-manifest.json"

VERSION="${1:-unspecified}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        *) shift ;;
    esac
done

log() {
    echo "==> $*"
}

log "Generating dependency manifest (version: ${VERSION})"

# Collect all xcframeworks in output directory
ALL_XCFRAMEWORKS=()
for xcfw in "${XCFW_DIR}"/*.xcframework; do
    [[ -d "${xcfw}" ]] || continue
    ALL_XCFRAMEWORKS+=("$(basename "${xcfw}")")
done

# Write JSON manifest
cat > "${MANIFEST_PATH}" << JSONEOF
{
  "version": "${VERSION}",
  "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "products": {
    "SplunkAgent": {
      "description": "Full SplunkAgent SDK with all instrumentation modules.",
      "frameworks": [
        "SplunkAgent.xcframework",
        "SplunkAgentObjC.xcframework",
        "SplunkCommon.xcframework",
        "SplunkNavigation.xcframework",
        "SplunkNetwork.xcframework",
        "SplunkNetworkMonitor.xcframework",
        "SplunkSlowFrameDetector.xcframework",
        "SplunkCrashReports.xcframework",
        "SplunkOpenTelemetry.xcframework",
        "SplunkOpenTelemetryBackgroundExporter.xcframework",
        "SplunkInteractions.xcframework",
        "SplunkAppStart.xcframework",
        "SplunkAppState.xcframework",
        "SplunkWebView.xcframework",
        "SplunkCustomTracking.xcframework",
        "SplunkSessionReplayProxy.xcframework",
        "OpenTelemetryApi.xcframework",
        "OpenTelemetrySdk.xcframework",
        "CrashReporter.xcframework",
        "CiscoLogger.xcframework",
        "CiscoEncryption.xcframework",
        "CiscoSwizzling.xcframework",
        "CiscoInteractions.xcframework",
        "CiscoDiskStorage.xcframework",
        "CiscoSessionReplay.xcframework",
        "CiscoInstanceManager.xcframework",
        "CiscoRuntimeCache.xcframework"
      ],
      "notes": [
        "All frameworks are required for full SplunkAgent functionality.",
        "SplunkCrashReports.xcframework and CrashReporter.xcframework do NOT support visionOS.",
        "SplunkAgentObjC.xcframework is only needed for Objective-C API access."
      ]
    },
    "SplunkAgentObjC": {
      "description": "Objective-C bridge for SplunkAgent. Add in addition to SplunkAgent frameworks.",
      "frameworks": [
        "SplunkAgentObjC.xcframework"
      ],
      "requires": ["SplunkAgent"]
    }
  },
  "platformRestrictions": {
    "SplunkCrashReports.xcframework": {
      "excludes": ["visionOS"],
      "reason": "PLCrashReporter does not support visionOS"
    },
    "CrashReporter.xcframework": {
      "excludes": ["visionOS"],
      "reason": "PLCrashReporter does not support visionOS"
    }
  },
  "xcframeworks": [
$(printf '    "%s"' "${ALL_XCFRAMEWORKS[0]}")$(for xcfw in "${ALL_XCFRAMEWORKS[@]:1}"; do printf ',\n    "%s"' "${xcfw}"; done)
  ]
}
JSONEOF

log "Generated ${MANIFEST_PATH}"

# Validate JSON
if python3 -m json.tool "${MANIFEST_PATH}" > /dev/null 2>&1; then
    log "JSON validation passed ✓"
else
    echo "ERROR: Generated JSON is invalid"
    exit 1
fi
