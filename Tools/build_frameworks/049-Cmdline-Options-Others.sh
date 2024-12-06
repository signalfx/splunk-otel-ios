#!/bin/sh

function process_frameworks_option {
    IFS=',' read -r -a FRAMEWORKS <<< "$1"

    if [[ " ${FRAMEWORKS[*]} " =~ " all " ]]; then
        FRAMEWORKS=("${ALL_FRAMEWORKS[@]}")
        return
    fi

    for framework in ${FRAMEWORKS[@]}; do
        assert_valid_framework $framework
    done
}

function process_mach_o_types_option {
    IFS=',' read -r -a MACH_O_TYPES <<< "$1"

    if [[ " ${MACH_O_TYPES[*]} " =~ " all " ]]; then
        MACH_O_TYPES=("${ALL_MACH_O_TYPES[@]}")
        return
    fi

    for mach_o_type in ${MACH_O_TYPES[@]}; do
        assert_valid_mach_o_type $mach_o_type
    done
}

function process_sdks_option {
    IFS=',' read -r -a SDKS <<< "$1"

    if [[ " ${SDKS[*]} " =~ " all " ]]; then
        SDKS=("${ALL_SDKS[@]}")
        return
    fi

    for sdk in ${SDKS[@]}; do
        assert_valid_sdk $sdk
    done
}

function process_increase_build_id {
    increase_build_id;
}

# C# Option
CSHARP_INTERFACES_OPTION=false

function process_csharp_option {
    CSHARP_INTERFACES_OPTION=true
}

# Documentation option
DOCUMENTATION_OPTION=false

function process_documentation_option {
    DOCUMENTATION_OPTION=true
}

# Web documentation option
WEB_DOCUMENTATION_OPTION=false

function process_web_documentation_option {
    DOCUMENTATION_OPTION=true
    WEB_DOCUMENTATION_OPTION=true
}

# Build fat libraries
FAT_FRAMEWORKS_OPTION=false

function process_fat_frameworks_option {
    FAT_FRAMEWORKS_OPTION=true
}
