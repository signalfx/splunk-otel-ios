#!/bin/bash
# tools/xcframework/scripts/build-cisco-xcframeworks.sh
#
# Builds Cisco Session Replay xcframeworks from a local Session Replay
# repository checkout, using dynamic frameworks by default. Static archives
# can be selected for hybrid integrations with CISCO_MACH_O_TYPE=staticlib.
#
# Usage:
#   SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay ./scripts/build-cisco-xcframeworks.sh
#   ./scripts/build-cisco-xcframeworks.sh --session-replay-path /path/to/session-replay
#   ./scripts/build-cisco-xcframeworks.sh --session-replay-path /path/to/session-replay --ios-only
#   ./scripts/build-cisco-xcframeworks.sh --build-dir /tmp/cisco-build
#
# Environment variables:
#   IOS_ONLY - When true, build only iOS device and simulator slices
#   CISCO_MACH_O_TYPE - Session Replay output type: staticlib or mh_dylib

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT_DIR="${TOOLS_ROOT}/output/xcframeworks"
DEPS_DIR="${TOOLS_ROOT}/dependencies"
BUILD_ROOT="${CISCO_BUILD_DIR:-${TOOLS_ROOT}/build/cisco-session-replay}"
CISCO_DIST_DIR="${BUILD_ROOT}/cisco-session-replay-frameworks"
CISCO_MACH_O_TYPE="${CISCO_MACH_O_TYPE:-mh_dylib}"

SESSION_REPLAY_PATH="${SESSION_REPLAY_LOCAL_PATH:-}"
SOURCE_COMMIT=""
SOURCE_BRANCH=""
SOURCE_DIRTY=""
SOURCE_REMOTE=""
IOS_ONLY="${IOS_ONLY:-false}"

CISCO_FRAMEWORKS=(
    "CiscoCommon"
    "CiscoLogger"
    "CiscoEncryption"
    "CiscoSwizzling"
    "CiscoInteractions"
    "CiscoDiskStorage"
    "CiscoVideoEncoder"
    "CiscoScreenshot"
    "CiscoWireframe"
    "CiscoDataExporter"
    "CiscoSnapshotManager"
    "CiscoSessionReplay"
    "CiscoInstanceManager"
    "CiscoRuntimeCache"
    "CiscoVideoEncoder"
    "CiscoScreenshot"
    "CiscoWireframe"
    "CiscoDataExporter"
    "CiscoSnapshotManager"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-replay-path)
            SESSION_REPLAY_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --deps-dir)
            DEPS_DIR="$2"
            shift 2
            ;;
        --build-dir)
            BUILD_ROOT="$2/cisco-session-replay"
            shift 2
            ;;
        --ios-only)
            IOS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Recompute derived paths after argument parsing so --build-dir isolates both
# this script's staging directory and the output consumed by the upstream build.
CISCO_DIST_DIR="${BUILD_ROOT}/cisco-session-replay-frameworks"

log() {
    echo "==> $*"
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_session_replay_path() {
    if [[ -z "${SESSION_REPLAY_PATH}" ]]; then
        fail "SESSION_REPLAY_LOCAL_PATH is required. Set it to the local Session Replay repository path or pass --session-replay-path."
    fi

    if [[ ! -d "${SESSION_REPLAY_PATH}" ]]; then
        fail "Session Replay repository not found: ${SESSION_REPLAY_PATH}"
    fi

    SESSION_REPLAY_PATH="$(cd "${SESSION_REPLAY_PATH}" && pwd)"

    local build_script="${SESSION_REPLAY_PATH}/Tools/build_frameworks.sh"
    if [[ ! -f "${build_script}" ]]; then
        fail "Session Replay build script not found: ${build_script}"
    fi

    if [[ ! -x "${build_script}" ]]; then
        fail "Session Replay build script is not executable: ${build_script}"
    fi
}

frameworks_argument() {
    local IFS=,
    echo "${CISCO_FRAMEWORKS[*]}"
}

verify_dynamic_framework() {
    local framework="$1"
    local xcfw_path="$2"
    local binary_count=0

    while IFS= read -r binary_path; do
        [[ -n "${binary_path}" ]] || continue
        binary_count=$((binary_count + 1))

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

        if [[ "${header_count}" -eq 0 || "${header_count}" -ne "${dylib_count}" ]]; then
            filetypes="$(
                printf '%s\n' "${otool_output}" |
                    awk '$1 ~ /^(0x|MH_)/ { print $5 }' |
                    sort -u |
                    tr '\n' ' ' |
                    sed 's/[[:space:]]*$//'
            )"
            fail "${framework}.xcframework contains a non-dynamic binary: ${binary_path} (${filetypes:-unknown})"
        fi
    done < <(find "${xcfw_path}" -path "*/${framework}.framework/${framework}" -type f)

    if [[ "${binary_count}" -eq 0 ]]; then
        fail "No framework binaries found in ${xcfw_path}"
    fi
}

verify_static_framework() {
    local framework="$1"
    local xcfw_path="$2"
    local binary_count=0

    while IFS= read -r binary_path; do
        [[ -n "${binary_path}" ]] || continue
        binary_count=$((binary_count + 1))

        if ! file "${binary_path}" | grep -Eqi 'archive'; then
            fail "${framework}.xcframework contains a non-static binary: ${binary_path}"
        fi
    done < <(find "${xcfw_path}" -path "*/${framework}.framework/${framework}" -type f)

    if [[ "${binary_count}" -eq 0 ]]; then
        fail "No framework binaries found in ${xcfw_path}"
    fi
}

stage_framework() {
    local framework="$1"
    local zip_file
    zip_file="$(
        find "${CISCO_DIST_DIR}" -path "*/${CISCO_MACH_O_TYPE}/*.zip" -type f 2>/dev/null | while IFS= read -r candidate; do
            if zipinfo -1 "${candidate}" "${framework}.xcframework/*" >/dev/null 2>&1; then
                echo "${candidate}"
                break
            fi
        done
    )"

    if [[ -z "${zip_file}" || ! -f "${zip_file}" ]]; then
        fail "Built ${CISCO_MACH_O_TYPE} zip for ${framework} not found in ${CISCO_DIST_DIR}"
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/build-cisco-xcframeworks.${framework}.XXXXXX")"

    unzip -q "${zip_file}" -d "${tmp_dir}"

    local extracted_xcfw
    extracted_xcfw="$(find "${tmp_dir}" -name "${framework}.xcframework" -type d | head -1)"

    if [[ -z "${extracted_xcfw}" || ! -d "${extracted_xcfw}" ]]; then
        rm -rf "${tmp_dir}"
        fail "${framework}.xcframework not found in ${zip_file}"
    fi

    local output_xcfw="${OUTPUT_DIR}/${framework}.xcframework"
    local deps_xcfw="${DEPS_DIR}/${framework}.xcframework"

    rm -rf "${output_xcfw}" "${deps_xcfw}"
    ditto "${extracted_xcfw}" "${output_xcfw}"
    case "${CISCO_MACH_O_TYPE}" in
        mh_dylib)
            verify_dynamic_framework "${framework}" "${output_xcfw}"
            ;;
        staticlib)
            verify_static_framework "${framework}" "${output_xcfw}"
            ;;
        *)
            fail "Unsupported CISCO_MACH_O_TYPE: ${CISCO_MACH_O_TYPE} (expected staticlib or mh_dylib)"
            ;;
    esac

    ln -s "${output_xcfw}" "${deps_xcfw}"

    rm -rf "${tmp_dir}"
    echo "  ${framework}.xcframework"
}

git_value() {
    local fallback="$1"
    shift

    git -C "${SESSION_REPLAY_PATH}" "$@" 2>/dev/null || echo "${fallback}"
}

capture_source_state() {
    SOURCE_COMMIT="$(git_value unknown rev-parse HEAD)"
    SOURCE_BRANCH="$(git_value unknown rev-parse --abbrev-ref HEAD)"
    SOURCE_REMOTE="$(git_value unknown config --get remote.origin.url)"

    if [[ "$(git -C "${SESSION_REPLAY_PATH}" status --porcelain 2>/dev/null || true)" == "" ]]; then
        SOURCE_DIRTY="false"
    else
        SOURCE_DIRTY="true"
    fi
}

write_traceability_manifest() {
    local manifest_path="${OUTPUT_DIR}/cisco-release-manifest.txt"
    {
        echo "source=local-session-replay"
        echo "source_remote=${SOURCE_REMOTE}"
        echo "source_commit=${SOURCE_COMMIT}"
        echo "source_branch=${SOURCE_BRANCH}"
        echo "source_dirty=${SOURCE_DIRTY}"
        echo "mach_o_type=${CISCO_MACH_O_TYPE}"
        if [[ "${IOS_ONLY}" == "true" ]]; then
            echo "variant=ios-only"
            echo "sdks=iphoneos,iphonesimulator"
        else
            echo "variant=all-platforms"
            echo "sdks=all"
        fi
        echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        for framework in "${CISCO_FRAMEWORKS[@]}"; do
            echo "${framework}|local|${CISCO_MACH_O_TYPE}"
        done
    } > "${manifest_path}"

    log "Wrote Cisco traceability manifest: ${manifest_path}"
}

main() {
    require_session_replay_path

    case "${CISCO_MACH_O_TYPE}" in
        staticlib|mh_dylib) ;;
        *) fail "Unsupported CISCO_MACH_O_TYPE: ${CISCO_MACH_O_TYPE} (expected staticlib or mh_dylib)" ;;
    esac

    log "Building ${CISCO_MACH_O_TYPE} Cisco xcframeworks from ${SESSION_REPLAY_PATH}"
    log "Output: ${OUTPUT_DIR}"
    log "Dependencies: ${DEPS_DIR}"
    log "iOS-only: ${IOS_ONLY}"

    capture_source_state

    rm -rf "${BUILD_ROOT}"
    mkdir -p "${BUILD_ROOT}" "${OUTPUT_DIR}" "${DEPS_DIR}"

    local build_args=(
        --frameworks "$(frameworks_argument)"
        --mach-o-types "${CISCO_MACH_O_TYPE}"
        --distribution-output "${CISCO_DIST_DIR}"
    )
    if [[ "${IOS_ONLY}" == "true" ]]; then
        build_args+=(--sdks iphoneos,iphonesimulator)
    fi

    "${SESSION_REPLAY_PATH}/Tools/build_frameworks.sh" "${build_args[@]}"

    log "Staging ${CISCO_MACH_O_TYPE} Cisco xcframeworks"
    for framework in "${CISCO_FRAMEWORKS[@]}"; do
        stage_framework "${framework}"
    done

    write_traceability_manifest

    log "Done."
}

main "$@"
