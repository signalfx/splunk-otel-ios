#! /bin/bash

# Full path to the script, canonized.
pushd $(dirname "$0") > /dev/null
SCRIPT_DIR="$(pwd)"
popd > /dev/null


# Include scripts with defaults and functions.
# Included scripts are sorted to make sure their mutual dependencies are respected.
for include in $(ls "${SCRIPT_DIR}"/build_frameworks | sort); do
    . "${SCRIPT_DIR}/build_frameworks/$include"
done

# Commandline
log_cmdline "$0 $(echo $@)"

process_cmdline_options $@

# Create folders
prepare_folders

# If fat libraries option is selected,
# only fat libraries, no xcframeworks, are build.
if [[ "$FAT_FRAMEWORKS_OPTION" = true ]]; then

    build_fat_frameworks
    generate_all_csharp_interfaces

    # That is all for the fat frameworks.
    # Global environment cleanup and exit.
    exit 0
fi

# Frameworks are not build when building documentation.
if [[ "$DOCUMENTATION_OPTION" = true ]]; then

    build_documentations
    
    # Global environment cleanup and exit.
    exit 0
fi


# Build xcframeworks, Swift packages, documentation and C# interfaces.
build_xarchives

create_xcframeworks_and_swift_packages

generate_all_csharp_interfaces

# Global environment cleanup and exit.
exit 0
