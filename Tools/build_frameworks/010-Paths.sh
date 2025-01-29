#!/bin/sh

# Various important paths used by the script.

function mrum_project {
    echo "${PROJECT_DIR}/SplunkAgent/SplunkAgent.xcodeproj"
}

function mrum_workspace {
    echo "${PROJECT_DIR}/Splunk.xcworkspace"
}

# Unique output folder of the script run.
# The script shall not be run twice withing the same second.
# Also, the relese foldes can be moved elswhere by a commandline option.
#
# This var should not be used directly, only via release_dir() function.
#
RELEASE_DIR="${PROJECT_DIR}/Release"

function release_dir {
    echo "${RELEASE_DIR}"
}


function log_file {
    echo "$(release_dir)/log"
}


function build_dir {
    echo "$(release_dir)/build"
}


function output_dir {
    echo "$(release_dir)/output"
}


function prepare_folders {
    # Cleanup if it accidentally exists
    rm -rf "$(release_dir)"

    # Prepare the structure
    mkdir -p "$(release_dir)"
    mkdir "$(build_dir)"
    mkdir "$(output_dir)"

    touch "$(log_file)"
}

# Some build steps use temporary folders. This method returns the folder conveniently named
# for better debugging
function mrum_tempdir {
    local id=$1

    local id_path_fragment=""
    if [[ ! -z "${id}" ]]; then
        id_path_fragment=".${id}"
    fi

    echo "$(mktemp -d -t "com.splunk.rum.sdk-build${id_path_fragment}.$(date +'%Y-%m-%d-%H.%M.%S')")"
}
