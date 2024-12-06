#!/bin/sh

function build_fat_frameworks {
    for SDK in ${SDKS[@]}; do

        if [[ " ${FAT_LIB_SDKS[*]} " =~ " $SDK " ]]; then
            build_fat_library $SDK
        fi
    done
}

function build_fat_library {
    local sdk=$1
    local sdk_simulator=$(sdk_simulator $sdk)

    assert_valid_sdk $sdk
    assert_valid_sdk $sdk_simulator

    # Build archives for device SDK
    # and Intel version of the archive for Simulator SDK
    for FRAMEWORK in ${FRAMEWORKS[@]}; do

        for MACH_O_TYPE in ${MACH_O_TYPES[@]}; do

            # Building device SDK framework
            build_xarchive $FRAMEWORK $sdk $MACH_O_TYPE

            # Building fat simulator framework to get composite headers
            build_xarchive $FRAMEWORK $sdk_simulator $MACH_O_TYPE

            # Building intel-only simulator framework to get clean intel binary
            build_xarchive $FRAMEWORK $sdk_simulator $MACH_O_TYPE $ARCHITECTURE_INTEL

            build_fat_framework $FRAMEWORK $sdk $MACH_O_TYPE
        done
    done
}


function build_fat_framework_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=3

    assert_valid_framework $framework
    assert_valid_sdk $sdk
    assert_valid_mach_o_type $mach_o_type

    local path="$(build_dir)/$framework-$sdk-$mach_o_type"
    mkdir -p "${path}"

    echo "${path}"
}

function build_fat_framework_binary {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3

    local sdk_simulator=$(sdk_simulator $sdk)

    assert_valid_framework $framework
    assert_valid_sdk $sdk
    assert_valid_sdk $sdk_simulator
    assert_valid_mach_o_type $mach_o_type

    local temp_dir=$(mrum_tempdir "fatlib-${framework}-${sdk}-lipo")
    local output="${temp_dir}/${framework}"

    local cmd="lipo"

    # Device SDK framework
    cmd+=" $(xarchive_framework_binary_path $framework $sdk $mach_o_type)"

    # Intel simulator SDK framework
    cmd+=" $(xarchive_framework_binary_path $framework $sdk_simulator $mach_o_type $ARCHITECTURE_INTEL)"

    cmd+=" -create"
    cmd+=" -output ${output}"

    cmd+=" >>'$(log_file)' 2>&1"

    log_cmd "${cmd}"

    if ! eval "${cmd}"; then
        log_err ''
        log_err "  lipo command to build fat library for '$framework' '${sdk} faild. Check the log for errors."
        exit 1
    fi

    echo "${output}"
}

function build_fat_framework {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    
    local sdk_simulator=$(sdk_simulator $sdk)

    log "$(log_delimiter)"
    log "🟦 Fat ${framework}.framework:"
    log "   sdk           = ${sdk}"
    log "   type          = ${mach_o_type}"

    assert_valid_framework $framework
    assert_valid_sdk $sdk
    assert_valid_sdk $sdk_simulator
    assert_valid_mach_o_type $mach_o_type

    # Put together intel slice from the simulator, and arm slice from the device.
    # Rewrite the binary in the created framework with it.
    log "      lipo ${sdk} and ${sdk_simulator} binaries into it..."

    local temp_fat_binary="$(build_fat_framework_binary $framework $sdk $mach_o_type)"


    # Temporay folder where the construction of the fat framework will be done
    local temp_dir=$(mrum_tempdir "fatlib-${framework}-${sdk}")


    # Use device SDK framework as a template
    log "      using ${sdk} framework as a template..."

    cp -R "$(xarchive_framework_path $framework $sdk $mach_o_type)" "${temp_dir}"

    # Copy fat binary there
    cp "${temp_fat_binary}" "${temp_dir}/${framework}.framework/"


    # Copy combined intel and arm header from universal simulator
    log "      copy headers template..."

    cp "$(xarchive_framework_path $framework $sdk_simulator $mach_o_type)/Headers/"*.h \
        "${temp_dir}/${framework}.framework/Headers"


    # Copy Intel module from simulator.
    log "      copy intel module..."

    cp -R \
        "$(xarchive_framework_path $framework $sdk_simulator $mach_o_type $ARCHITECTURE_INTEL)/Modules/${framework}.swiftmodule/" \
        "${temp_dir}/${framework}.framework/Modules/${framework}.swiftmodule"


    # Copy the fat framework to the output directory.
    log "      publish framework in output directory..."

    local output_dir="$(output_dir)/${framework}-${sdk}-${mach_o_type}-fat"
    mkdir -p "${output_dir}"

    cp -R "${temp_dir}/${framework}.framework" "${output_dir}"


    # Remove temporary dirs
    rm -rf "${temp_dir}"
    rm -rf "${temp_fat_binary}"
}
