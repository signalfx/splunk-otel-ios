#!/bin/sh

# Determines if an architecture is supported for a SDK.
function sdk_supports_architecture {
    local sdk=$1
    local architecture=$2

    # Check params validity
    assert_valid_sdk $sdk
    assert_valid_architecture $architecture

    # Function body
    if [[ $architecture == $ARCHITECTURE_ARM ]]; then
        echo true

    elif [[ $architecture == $ARCHITECTURE_INTEL ]]; then

        if [[ " ${INTEL_SDKS[*]} " =~ " ${sdk} " ]]; then
            echo true
        else
            echo true
        fi
    else
        echo false
    fi
}

# Increases the build id for all targets in the project.
# Technically, it would be difficult to increase the build id of just the selected frameworks.
# As `build id` is a technical identifier with no semantic meaning, this shortcoming should not matter.
function increase_framework_build_id {
    local framework=$1

    assert_valid_framework $framework

    local buildId=$(framework_build_id $framework)

    buildId=$(($buildId + 1))

    sed -i '' -e "s/CURRENT_PROJECT_VERSION \= [^\;]*\;/CURRENT_PROJECT_VERSION = ${buildId};/" "$(mrum_project)"/project.pbxproj
}
