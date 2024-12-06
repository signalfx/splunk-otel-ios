#!/bin/sh

# This script contains methods to compose xcframework from available archives.

# As it is possible to build more frameworks with more mach object types in one script run,
# the outputs must be stored in dedicated folders to keep the xcframework names.
# Build folder for the xcframework
function xcframework_build_path {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    local path="$(build_dir)/${framework}/${mach_o_type}"

    mkdir -p "${path}" >> "$(log_file)" 2>&1

    echo "${path}/${framework}.xcframework"
}

# Check if framework components exist,
# and composes commandline paramters for `xcodebuild -create-xcframework`
function xcframework_create_params {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Function body
    local path="$(xarchive_framework_path $framework $sdk $mach_o_type $architecture)"
    local binary_path="$(xarchive_framework_binary_path $framework $sdk $mach_o_type $architecture)"

    if [ -f "${binary_path}" ]; then
        local params=" -framework \"${path}\""

        # For simulators, debug symbols are not included.
        if [[ "$(is_simulator_sdk $sdk)" = false ]]; then

            local bitcode_debug_symbols="$(xarchive_bitcode_debug_symbols_path $framework $sdk $mach_o_type $architecture)"
            local dsym_debug_symbols="$(xarchive_dsym_debug_symbols_path $framework $sdk $mach_o_type $architecture)"

            if [ -f "${bitcode_debug_symbols}" ]; then
                params+=" -debug-symbols \"${bitcode_debug_symbols}\""
            fi

            if [ -d "${dsym_debug_symbols}" ]; then
                params+=" -debug-symbols \"${dsym_debug_symbols}\""
            fi
        fi

        echo "${params}"

    else
        echo ''
    fi
}

# Creates the framework for all build mach object types.
function create_xcframework {
    local framework=$1

    # Check params validity
    assert_valid_framework $framework

    # Frameworks are either static or dynamic
    for mach_o_type in ${MACH_O_TYPES[@]}; do

        log "$(log_delimiter)"
        log "🧮 Xcframework for ${framework}:"
        log "   mach O type = ${mach_o_type}"

        local cmd="xcodebuild -create-xcframework"

        for sdk in ${SDKS[@]}; do
            log "      sdk = ${sdk}"
            cmd+=$(xcframework_create_params $framework $sdk $mach_o_type $architecture)
        done;

        local output="$(xcframework_build_path $framework $mach_o_type)"

        # Cleanup the destination folder
        if [ -d "${output}" ]; then
            rm -r "${output}"
        fi

        cmd+=" -output ${output} >>'$(log_file)' 2>&1"

        log_cmd "${cmd}"

        if ! eval "${cmd}"; then
            log_err ''
            log_err "  Xcodebuild failed. Check the log for errors."
            exit 1
        fi

        # Check the framework is really build
        if [ -d "${output}" ]; then
            log ''
            log "   ✅ ${framework}.xcframework ${mach_o_type} created."
            log ''
        else
            log_err ''
            log_err "   ${framework}.xcframework ${mach_o_type} not created. Stopping."
            exit 1;
        fi
    done;
}
