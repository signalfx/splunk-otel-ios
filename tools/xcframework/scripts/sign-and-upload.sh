#!/bin/bash
# tools/xcframework/scripts/sign-and-upload.sh
#
# Local release workflow: builds all xcframeworks, signs them with a local
# certificate, validates, packages, and optionally uploads to an existing
# GitHub release.
#
# Default mode is fully local and requires SESSION_REPLAY_LOCAL_PATH (or
# --session-replay-path) so Cisco frameworks are built as dynamic frameworks
# from the Session Replay repository. The --run-id mode is a legacy path for
# downloading a prebuilt unsigned artifact and must not refresh Cisco from
# Package.swift static binary target URLs.
#
# Usage:
#   SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay ./scripts/sign-and-upload.sh VERSION [OPTIONS]
#
# Options:
#   --run-id ID               Legacy mode: download unsigned artifact from a GitHub Actions run
#   --identity NAME           Signing identity (default: auto-detected)
#   --session-replay-path DIR Local Session Replay repo path for default local mode
#   --ios-only                Build, sign, validate, and package only iOS device/simulator slices
#   --upload-to TAG           Upload to a release tag other than VERSION
#   --skip-upload             Sign and package only, do not require gh unless --run-id is used

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TOOLS_ROOT}/../.." && pwd)"
OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"

VERSION="${1:-}"
RUN_ID=""
SIGNING_IDENTITY=""
SESSION_REPLAY_PATH="${SESSION_REPLAY_LOCAL_PATH:-}"
IOS_ONLY="${IOS_ONLY:-false}"
UPLOAD_TO_TAG=""
SKIP_UPLOAD=false

if [[ -z "${VERSION}" ]]; then
    echo "ERROR: Version required."
    echo "  Usage: $0 VERSION [--run-id ID] [--identity NAME] [--session-replay-path DIR] [--ios-only] [--upload-to TAG] [--skip-upload]"
    exit 1
fi

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --identity)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --session-replay-path)
            SESSION_REPLAY_PATH="$2"
            shift 2
            ;;
        --ios-only)
            IOS_ONLY=true
            shift
            ;;
        --upload-to)
            UPLOAD_TO_TAG="$2"
            shift 2
            ;;
        --skip-upload)
            SKIP_UPLOAD=true
            shift
            ;;
        *)
            echo "Unknown arg: $1"
            exit 1
            ;;
    esac
done

log() {
    echo ""
    echo "==> $*"
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_gh() {
    if ! command -v gh &> /dev/null; then
        fail "gh CLI not installed. Install with: brew install gh"
    fi

    if ! gh auth status &> /dev/null; then
        fail "gh CLI not authenticated. Run: gh auth login"
    fi

    echo "  gh CLI authenticated"
}

resolve_repo_full_name() {
    cd "${REPO_ROOT}"
    gh repo view --json nameWithOwner -q .nameWithOwner
}

resolve_signing_identity() {
    if [[ -n "${SIGNING_IDENTITY}" ]]; then
        echo "  Using identity: ${SIGNING_IDENTITY}"
        return
    fi

    local raw
    raw="$(security find-identity -v -p codesigning)"
    SIGNING_IDENTITY="$(echo "${raw}" | grep '"' | head -1 | sed 's/.*"\(.*\)".*/\1/')"

    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        echo "Available identities:"
        security find-identity -v -p codesigning
        fail "No codesigning identity found in keychain. Provide one explicitly with --identity."
    fi

    echo "  Using identity: ${SIGNING_IDENTITY}"
}

require_session_replay_path() {
    if [[ -z "${SESSION_REPLAY_PATH}" ]]; then
        fail "SESSION_REPLAY_LOCAL_PATH is required in local mode. Set it or pass --session-replay-path."
    fi

    if [[ ! -d "${SESSION_REPLAY_PATH}" ]]; then
        fail "Session Replay repository not found: ${SESSION_REPLAY_PATH}"
    fi

    SESSION_REPLAY_PATH="$(cd "${SESSION_REPLAY_PATH}" && pwd)"

    if [[ ! -x "${SESSION_REPLAY_PATH}/Tools/build_frameworks.sh" ]]; then
        fail "Session Replay build script is missing or not executable: ${SESSION_REPLAY_PATH}/Tools/build_frameworks.sh"
    fi
}

download_legacy_artifact() {
    log "Downloading unsigned xcframeworks from CI run ${RUN_ID}"

    rm -rf "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"

    gh run download "${RUN_ID}" \
        -n "splunk-agent-xcframeworks-unsigned" \
        -D "${OUTPUT_DIR}" \
        -R "$(resolve_repo_full_name)"

    local xcfw_count
    xcfw_count="$(find "${OUTPUT_DIR}" -maxdepth 1 -name "*.xcframework" -type d | wc -l | tr -d ' ')"
    if [[ "${xcfw_count}" -eq 0 ]]; then
        echo "Contents of ${OUTPUT_DIR}:"
        ls -la "${OUTPUT_DIR}"
        fail "No xcframeworks found after artifact download."
    fi

    echo "  Downloaded ${xcfw_count} xcframeworks"
}

build_local_artifacts() {
    require_session_replay_path

    log "Building xcframeworks locally"
    cd "${TOOLS_ROOT}"
    SESSION_REPLAY_LOCAL_PATH="${SESSION_REPLAY_PATH}" IOS_ONLY="${IOS_ONLY}" make clean build
}

main() {
    local legacy_mode=false
    if [[ -n "${RUN_ID}" ]]; then
        legacy_mode=true
    fi

    log "Preflight checks"
    if [[ "${SKIP_UPLOAD}" != "true" || "${legacy_mode}" == "true" ]]; then
        require_gh
    else
        echo "  gh CLI not required for --skip-upload local mode"
    fi

    log "Resolving signing identity"
    resolve_signing_identity

    if [[ "${legacy_mode}" == "true" ]]; then
        download_legacy_artifact
    else
        build_local_artifacts
    fi

    log "Signing non-Cisco xcframeworks"
    "${SCRIPT_DIR}/sign-xcframeworks.sh" "${SIGNING_IDENTITY}"

    log "Validating signed xcframeworks"
    RELEASE=true IOS_ONLY="${IOS_ONLY}" "${SCRIPT_DIR}/validate-xcframeworks.sh"

    local release_args=("${VERSION}")
    if [[ "${IOS_ONLY}" == "true" ]]; then
        release_args+=(--ios-only)
    fi

    if [[ "${SKIP_UPLOAD}" == "true" ]]; then
        log "Packaging (upload skipped)"
        "${SCRIPT_DIR}/release.sh" "${release_args[@]}"
    else
        local target_release="${UPLOAD_TO_TAG:-${VERSION}}"
        log "Packaging and uploading to release ${target_release}"
        "${SCRIPT_DIR}/release.sh" "${release_args[@]}" --upload-to "${target_release}"
    fi

    echo ""
    echo "============================================================"
    echo "  Local Signing Complete"
    echo "============================================================"
    echo "  Version:   ${VERSION}"
    if [[ "${IOS_ONLY}" == "true" ]]; then
        echo "  Variant:   iOS-only"
    else
        echo "  Variant:   all platforms"
    fi
    echo "  Identity:  ${SIGNING_IDENTITY}"
    if [[ "${legacy_mode}" == "true" ]]; then
        echo "  Source:    CI run ${RUN_ID}"
    else
        echo "  Source:    local Session Replay checkout"
    fi
    if [[ "${SKIP_UPLOAD}" == "true" ]]; then
        echo "  Upload:    skipped"
    else
        echo "  Upload:    attached to release ${UPLOAD_TO_TAG:-${VERSION}}"
    fi
    echo ""
}

main "$@"
