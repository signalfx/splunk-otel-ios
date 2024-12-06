#!/bin/sh

# This script packages the created Frameworks for distribution

function distribution_folder {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    local folder="$(output_dir)/${framework}-${mach_o_type}/"

    if [ ! -d "${folder}" ]; then
        mkdir -p "${folder}" >>"$(log_file)" 2>&1
    fi

    echo "${folder}"
}

function zipped_framework_path {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    echo "$(distribution_folder $framework $mach_o_type)/$(zipped_xcframework_filename $framework)"
}

function pack_for_distribution {
    local framework=$1
    local mach_o_type=$2

    log "         packing..."

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    # Temporary file for the packed files.
    local temp_dir=$(mrum_tempdir "pack-${framework}-${mach_o_type}")


    # LICENSE to be zipped with the Framework
    cp "${PROJECT_DIR}/license/LICENSE.txt" "${temp_dir}/LICENSE"

    # Copy the frameworks
    cp -R "$(xcframework_build_path $framework $mach_o_type)" "${temp_dir}" >>"$(log_file)" 2>&1

    # Zip the framework and license together
    pushd "${temp_dir}" > /dev/null
    zip -vrqy "$(zipped_framework_path $framework $mach_o_type)" "${framework}.xcframework" LICENSE  >>"$(log_file)" 2>&1
    popd > /dev/null

    # Cleanup.
    rm -r "${temp_dir}"
}

function swift_package_manifest {
    local framework=$1
    local checksum=$2

    # Check params validity
    assert_valid_framework $framework

    echo "// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: \"$(framework_package_name $framework)\",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: \"${framework}\",
            targets: [\"${framework}\"]),
    ],
    dependencies: [
    ],
    targets: [
        .binaryTarget(
            name: \"${framework}\",
            url: \"$(zipped_xcframework_url $framework)\",
            checksum: \"${checksum}\"
        ),
    ]
)
"
}

function package_manifest_file {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    echo "$(distribution_folder $framework $mach_o_type)/Package.swift"
}

function make_swift_package {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    log "         creating Swift package..."

    local package_folder="$(distribution_folder $framework $mach_o_type)"
    local manifest_file="$(package_manifest_file $framework $mach_o_type)"

    # Print Swift package manifest
    # Two rounds necessary to properyl compute the checksum.
    echo "$(swift_package_manifest $framework)" > "${manifest_file}"

    local checksum=$(swift package --package-path "${package_folder}" compute-checksum "$(zipped_framework_path $framework $mach_o_type)")

    echo "$(swift_package_manifest $framework $checksum)" > "${manifest_file}"
}

function create_swift_package {
    local framework=$1

    # Check params validity
    assert_valid_framework $framework

    for mach_o_type in ${MACH_O_TYPES[@]}; do

        log "$(log_delimiter)"
        log "📦 Swift Package for ${framework}.xcframework:"
        log "      mach O type = ${mach_o_type}"

        pack_for_distribution $framework $mach_o_type
        make_swift_package $framework $mach_o_type

        if [ -f "$(package_manifest_file $framework $mach_o_type)" ] && [ -f "$(zipped_framework_path $framework $mach_o_type)" ]; then
            log ''
            log "   🗳️ Binary download URL: '$(zipped_xcframework_url $framework)'."
            log ''
            log "   ✅ Swift package for $framework ${mach_o_type} created."
            log ''
        else
            log_err ''
            log_err "    Creating Swift package for ${framework} ${mach_o_type} failed."
            exit 1;
        fi

        log ''
    done;
}

# Combine archives into xcframeworks.
# Create swift packages for them, too.
function create_xcframeworks_and_swift_packages {
    for FRAMEWORK in ${FRAMEWORKS[@]}; do
        create_xcframework $FRAMEWORK
        create_swift_package $FRAMEWORK
    done
}
