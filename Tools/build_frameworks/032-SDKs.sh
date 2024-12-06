#!/bin/sh

#
# SDKs
#
# SDKs for which the frameworks are build
# xcFrameworks encapsulate libraries for several target SDKs and architectures
# The possible values are
#   - "iphoneos"
#   - "macosx" (implicitly buld for Catalyst)
#   - "appletvos"
#   - "xros"
#   - "iphonesimulator"
#   - "appletvsimulator"
#   - "xrsimulator"

SDK_IOS="iphoneos"
SDK_IOS_SIMULATOR="iphonesimulator"

SDK_MACOSX="macosx"

SDK_TVOS="appletvos"
SDK_TVOS_SIMULATOR="appletvsimulator"

SDK_VISIONOS="xros"
SDK_VISIONOS_SIMULATOR="xrsimulator"


ALL_SDKS=($SDK_IOS $SDK_IOS_SIMULATOR $SDK_MACOSX $SDK_TVOS $SDK_TVOS_SIMULATOR $SDK_VISIONOS $SDK_VISIONOS_SIMULATOR)

INTEL_SDKS=($SDK_IOS_SIMULATOR $SDK_TVOS_SIMULATOR $SDK_MACOSX $SDK_VISIONOS_SIMULATOR)

CATALYST_SDKS=($SDK_MACOSX)

SIMULATOR_SDKS=($SDK_IOS_SIMULATOR $SDK_TVOS_SIMULATOR $SDK_VISIONOS_SIMULATOR)

FAT_LIB_SDKS=($SDK_IOS $SDK_TVOS $SDK_VISIONOS)

# SDKs to be build. Can be overriden by commandline switch
DEFAULT_SDKS=("${ALL_SDKS[@]}")
SDKS=("${DEFAULT_SDKS[@]}")


function assert_valid_sdk {
    local is_valid=1

    if [ -z "$1" ]; then
        is_valid=0
    fi

    if [[ ! " ${ALL_SDKS[*]} " =~ " $1 " ]]; then
        is_valid=0
    fi

    if [[ $is_valid == 0 ]]; then
        log_err ''
        log_err " Invalid SDK '$1' in '${FUNCNAME[1]}'."
        log_err " Valid SDKs are: $(echo ${ALL_SDKS[*]})."
        log_err ''
        exit 1
    fi
}


function is_catalyst_sdk {

    if [[ " ${CATALYST_SDKS[*]} " =~ " $1 " ]]; then
        echo true
    else
        echo false
    fi;
}

function is_simulator_sdk {

    if [[ " ${SIMULATOR_SDKS[*]} " =~ " $1 " ]]; then
        echo true
    else
        echo false
    fi;
}


function sdk_simulator {
    local sdk=$1

    assert_valid_sdk $sdk

    if [[ $sdk == $SDK_IOS ]]; then

        echo $SDK_IOS_SIMULATOR

    elif [[ $sdk == $SDK_TVOS ]]; then

        echo $SDK_TVOS_SIMULATOR

    elif [[ $sdk == $SDK_VISIONOS ]]; then

        echo $SDK_VISIONOS_SIMULATOR
    fi

    echo ''
}
