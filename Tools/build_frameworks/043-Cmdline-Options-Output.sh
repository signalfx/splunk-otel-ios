#!/bin/sh

# This function moves the current output folder into the new destination.
function process_output_option {
    local output=$1

    # Current release dir
    current_release_dir="$(release_dir)"

    # The destination is cleaned first
    rm -rf "${output}" >>"$(log_file)" 2>&1

    # Make the output dir.
    mkdir -p "${output}" >>"$(log_file)" 2>&1

    # Full output path, canonized.
    pushd "${output}" > /dev/null
    output="$(pwd)"
    popd > /dev/null

    # Check the output dir was created.
    if [ ! -d "${output}" ]; then
        log_err ''
        log_err "  Custom output folder '${output}' can't be created."
        log_err ''
        exit 1
    fi

    # Moving all already existing files to the new folder,
    # e.g., log file might already exist.
    cp -pR "${current_release_dir}/" "${output}"


    # Forward the release_dir to the new location.
    RELEASE_DIR="${output}"

    # Removing the implicite release folder.
    rm -r "${current_release_dir}"
}
