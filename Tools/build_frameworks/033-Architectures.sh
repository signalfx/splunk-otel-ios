#!/bin/sh

#
# Architectures
#
# The implicit achitecture is arm64. Simulators also support x86_64.

ARCHITECTURE_ARM="arm64"
ARCHITECTURE_INTEL="x86_64"

ALL_ARCHITECTURES=($ARCHITECTURE_ARM $ARCHITECTURE_INTEL)

# Commandlines to be build. Can be overidden by a commandline switch (but should not unless necesary).
ARCHITECTURES=("${ALL_ARCHITECTURES[@]}")

function assert_valid_architecture {
    # Architecture can be 'empty', implying the project target setting is used
    if [[ ! -z "$1" ]]; then

        if [[ ! " ${ALL_ARCHITECTURES[*]} " =~ " $1 " ]]; then
            log_err ''
            log_err "    Invalid architecture '$1' in '${FUNCNAME[1]}'."
            log_err "    Valid architectures are: $(echo ${ALL_ARCHITECTURES[*]})."
            log_err ''
            exit 1
        fi
    fi
}
