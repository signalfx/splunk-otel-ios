#!/bin/sh

# Path to the build archive.
function xarchive_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Function body

    # Optional architecture path
    architecture_path=""

    if [[ ! -z "$architecture" ]]; then
        architecture_path="-$architecture"
    fi

    echo "$(build_dir)/${framework}-${sdk}-${mach_o_type}${architecture_path}.xcarchive"
}

# Archived framework (i.e., for a particular sdk, mach object type and architecture) path.
function xarchive_framework_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Function body
    echo "$(xarchive_path $framework $sdk $mach_o_type $architecture)/Products/Library/Frameworks/${framework}.framework"
}

# Archived binary path.
function xarchive_framework_binary_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Function body
    echo "$(xarchive_framework_path $framework $sdk $mach_o_type $architecture)/${framework}"
}

# Archived bitcode symbolicatin map path.
function xarchive_bitcode_debug_symbols_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Read the build UUID
    local binary_path="$(xarchive_framework_binary_path $framework $sdk $mach_o_type $architecture)"
    local bitcode_debug_symbols_uuid=$(dwarfdump -u ${binary_path} | grep arm64 | sed -nE 's/UUID: (.*) \(.*/\1/p')

    # Compose the bitcode debug symbols path
    local path="$(xarchive_path $framework $sdk $mach_o_type $architecture)"
    echo "${path}/BCSymbolMaps/${bitcode_debug_symbols_uuid}.bcsymbolmap"
}

# Archived dSYM symbolicatin map path.
function xarchive_dsym_debug_symbols_path {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    # Function body
    local path="$(xarchive_path $framework $sdk $mach_o_type $architecture)"
    echo "${path}/dSYMs/${framework}.framework.dSYM"
}

