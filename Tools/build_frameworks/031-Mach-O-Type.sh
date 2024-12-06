#!/bin/sh

# Set default configuration values

#
# MACH Object Types
#
# Mach object type(s) for which the framework(s) are build
# Possible values are "mh_dylib" and "staticlib"

MACH_O_TYPE_DYNAMIC="mh_dylib"
MACH_O_TYPE_STATIC="staticlib"

ALL_MACH_O_TYPES=($MACH_O_TYPE_DYNAMIC $MACH_O_TYPE_STATIC)

# Mach Object Types to be build. Can be overriden by commandline switchs.
DEFAULT_MACH_O_TYPES=($MACH_O_TYPE_DYNAMIC)
MACH_O_TYPES=("${DEFAULT_MACH_O_TYPES[@]}")

function assert_valid_mach_o_type {
    local is_valid=1

    if [ -z "$1" ]; then
        is_valid=0
    fi

    if [[ ! " ${ALL_MACH_O_TYPES[*]} " =~ " $1 " ]]; then
        is_valid=0
    fi

    if [[ $is_valid == 0 ]]; then
        log_err ''
        log_err " Invalid Mach O Type '$1' in '${FUNCNAME[1]}'."
        log_err " Valid Mach O Types are: $(echo ${ALL_MACH_O_TYPES[*]})."
        log_err ''
        exit 1
    fi
}
