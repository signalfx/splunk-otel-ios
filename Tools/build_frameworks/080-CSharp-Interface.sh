#!/bin/sh

function is_sharpie_installed {
    local is_sharpie=$(command -v sharpie 2>/dev/null)
    if [ -z $is_sharpie ]; then
        echo false
    else
        echo true
    fi
}

function csharp_interface {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3

    # check argument values
    assert_valid_framework $framework
    assert_valid_sdk $sdk
    assert_valid_mach_o_type $mach_o_type

    log "$(log_delimiter)"
    log "⚡️ C# Interface for ${framework}:"
    log "      sdk = ${sdk}"
    log ''


    # Getting the platform API for the framework
    local sharpie_platform=$(sharpie xcode -sdks | egrep "sdk: ${sdk}" | sort | tail -1 | sed -e "s/.*\(${sdk}[0123456789\.]\{4,6\}\).*/\1/")

    # Only when the platform is available, the build is possible
    if [ -z "$sharpie_platform" ]; then
        log "  ⚠️  No sharpie platform found for $sdk, can't generate C# interface."
        log ''
        return
    fi

    log "  platform:  $sharpie_platform"


    # Output file
    local output="$(output_dir)/c-sharp/${framework}-${sdk}.cs"

    log "  output:    $(basename ${output})"

    # Make sure the folder for output exists
    local output_dir=$(dirname "${output}")

    if [ ! -d "${output_dir}" ]; then
        mkdir $(dirname "${output}")
    fi


    # Headers to be converted to C#
    local headers_root="$(xarchive_framework_path $framework $sdk $mach_o_type)/Headers"


    # Sharpie command
    local cmd=""
    cmd+="sharpie bind "
    cmd+=" -output \"${output}\""
    cmd+=" -sdk \"${sharpie_platform}\""
    cmd+=" -namespace \"${framework}.Bindings\""
    cmd+=" -nosplit"
    cmd+=" -quiet"
    cmd+=" -scope '${headers_root}'"
    cmd+=" "
    cmd+=" '${headers_root}/'*.h"
    cmd+=" >>'$(log_file)' 2>&1"

    log_cmd "${cmd}"

    if ! eval "${cmd}"; then
        log ''
        log "  ⚠️  Sharpie bind ended with an error code. This ususaly does not mean it failed. Check the log for errors."
    fi


    # Check the interface is generated.
    log ''
    if [ -f "${output}" ]; then
        log "  ✅ Interface file $(basename ${output}) created."
    else
        log_err "   Interface file $(basename ${output}) not created. Check the log for errors."
    fi
    log ''
}

function generate_csharp_interfaces {
    if [[ ! "$CSHARP_INTERFACES_OPTION" = true ]]; then
        return
    fi

    local framework=$1

    # check argument values
    assert_valid_framework $framework

    if [ "$(is_sharpie_installed)" = true ]; then

        for sdk in ${SDKS[@]}; do

            csharp_interface $framework $sdk ${MACH_O_TYPES[0]}
        done;

    else
        log "  ⚠️  To build C# interface, 'Objective Sharpie' must be installed."
        log ''
    fi
}


function generate_all_csharp_interfaces {
    for FRAMEWORK in ${FRAMEWORKS[@]}; do
        generate_csharp_interfaces $FRAMEWORK
    done;
}
