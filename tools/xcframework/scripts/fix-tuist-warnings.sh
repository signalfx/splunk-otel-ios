#!/bin/bash
# tools/xcframework/scripts/fix-tuist-warnings.sh
#
# Post-processes Tuist-generated Xcode projects to remove deprecated
# build settings that Tuist auto-injects.
#
# Currently fixes:
#   - DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = YES
#     Tuist generates this for targets with macCatalyst destinations,
#     but Xcode no longer supports the setting and emits a warning.
#
# Usage:
#   ./scripts/fix-tuist-warnings.sh <path-to-xcodeproj>
#   ./scripts/fix-tuist-warnings.sh project/Foo.xcodeproj
#
# Typically called right after `tuist generate`.

set -euo pipefail

XCODEPROJ="${1:-}"

if [[ -z "${XCODEPROJ}" ]]; then
    echo "Usage: $0 <path-to-xcodeproj>"
    exit 1
fi

PBXPROJ="${XCODEPROJ}/project.pbxproj"

if [[ ! -f "${PBXPROJ}" ]]; then
    echo "WARNING: ${PBXPROJ} not found, skipping post-generation fixes"
    exit 0
fi

# Remove DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER lines.
# This setting is deprecated and its presence alone triggers an Xcode warning.
if grep -q "DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER" "${PBXPROJ}"; then
    sed -i '' '/DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER/d' "${PBXPROJ}"
    echo "  ✓ Removed DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER from $(basename "${XCODEPROJ}")"
fi
