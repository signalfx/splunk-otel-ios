#!/bin/sh

# Frameworks
#
# Frameworks to be build
# These are by naming convention also names of the respective project build targets

FRAMEWORK_ANALYTICS="SplunkAgent"

ALL_FRAMEWORKS=($FRAMEWORK_ANALYTICS)

DOCUMENTED_FRAMEWORKS=($FRAMEWORK_ANALYTICS)


# Frameworks to be build. Could be overriden by commandline switch.
DEFAULT_FRAMEWORKS=($FRAMEWORK_ANALYTICS)
FRAMEWORKS=("${DEFAULT_FRAMEWORKS[@]}")

function assert_valid_framework {
    local is_valid=1

    if [ -z "$1" ]; then
        is_valid=0
    fi

    if [[ ! " ${ALL_FRAMEWORKS[*]} " =~ " $1 " ]]; then
        is_valid=0
    fi

    if [[ $is_valid == 0 ]]; then
        log_err ''
        log_err "    Invalid framework '$1' in '${FUNCNAME[1]}'."
        log_err "    Valid frameworks are: $(echo ${ALL_FRAMEWORKS[*]})."
        exit 1
    fi
}

# Getting framework version and build id from the project file

function framework_version {
    local framework=$1

    assert_valid_framework $framework

    echo $(xcodebuild -project "$(mrum_project)" -target ${framework} -showBuildSettings | grep MARKETING_VERSION | sed 's/[ ]*MARKETING_VERSION = //')
}

function framework_build_id {
    local framework=$1

    assert_valid_framework $framework

    echo $(xcodebuild -project "$(mrum_project)" -target ${framework} -showBuildSettings | grep CURRENT_PROJECT_VERSION | sed 's/[ ]*CURRENT_PROJECT_VERSION = //')
}


# Build id is the same for all targets (setting it separatelly would be difficult).
# Thus the build id is read from target, and aplied to all targets.
function increase_build_id {
    local build_id=$(framework_build_id $FRAMEWORK_ANALYTICS)

    build_id=$(($build_id + 1))

    sed -i '' -e "s/CURRENT_PROJECT_VERSION \= [^\;]*\;/CURRENT_PROJECT_VERSION = ${build_id};/" "$(mrum_project)"/project.pbxproj
}

# Getting Framework package file names and download urls

function framework_package_name {
    local framework=$1

    assert_valid_framework ${framework}

    if [[ $framework == $FRAMEWORK_ANALYTICS ]]; then
        echo "SplunkAgent"
    fi
}

function artifact_build_number {

    # BUILD_NUMBER is set by Teamcity. If not present, version from the project file is used.

    if [[ -z "${BUILD_NUMBER}" ]]; then
        local framework=$1
        local version=$(framework_version $framework)
        echo "${version}.000"
    else
        echo "${BUILD_NUMBER}"
    fi
}

function zipped_xcframework_filename {
    local framework=$1

    assert_valid_framework ${framework}

    if [[ $framework == $FRAMEWORK_ANALYTICS ]]; then
        echo "SplunkAgent-iOS-$(artifact_build_number $framework).zip"
    fi
}

function zipped_xcframework_url {
    local framework=$1

    assert_valid_framework ${framework}

    local artifact_version=$(artifact_build_number $framework)
    local file_name=$(zipped_xcframework_filename $framework)

    echo "https://appdynamics.jfrog.io/ui/native/zip-hosted/mrum/SplunkAgent-iOS/${artifact_version}/${file_name}"
}
