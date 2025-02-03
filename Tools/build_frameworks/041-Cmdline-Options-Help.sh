#!/bin/sh

function print_help {
    log ''
    log 'Builds SplunkAgent 1.0 frameworks.'
    log ''

    log ''
    log '$build_frameworks.sh \'
    log '   -h --help \'
    log '   -f --frameworks \'
    log '   -s --sdks \'
    log '   -m --mach-o-types \'
    log '   -c --csharp \'
    log '   -d --documentation \'
    log '   -w --web-documentation \'
    log '   -i --increase-build-id \'
    log '   -t --fat-frameworks \'
    log '   -x --xcode \'
    log '   -o --output'
    log ''

    log ' --help: prints this help message'
    log ''

    log ' --frameworks: comma separated list of frameworks to be build.'
    log "       Default values: $(echo ${DEFAULT_FRAMEWORKS[*]})"
    log "       Allowed values: $(echo ${ALL_FRAMEWORKS[*]}) all"
    log ''

    log ' --sdks: comma separated list of target SDKs included in the frameworks.'
    log "       Default values: $(echo ${DEFAULT_SDKS[*]})"
    log "       Allowed values: $(echo ${ALL_SDKS[*]}) all"
    log ''
    log '       Note: if a selected SDK supports both arm64 and x86_64, both architectures are build into the framework.'
    log ''
    log ''

    log ' --mach-o-types: comma separated list of Mach object types of the build frameworks.'
    log "       Default values: $(echo ${DEFAULT_MACH_O_TYPES[*]})"
    log "       Allowed values: $(echo ${ALL_MACH_O_TYPES[*]}) all"
    log ''

    log ' --csharp: the script generates C# interfaces for all frameworks when sharpie is installed.'
    log ''

    log ' --documentation: generates documentation for all frameworks.'
    log ''

    log ' --web-documentation: generates web documentation for all frameworks.'
    log '       Note: Standard documentation is also implicitly generated with this option.'
    log ''

    log ' --increase-build-id: increases build in all targets.'
    log '       Note: Increasing build id per target would be difficult programatically.'
    log '             Build id has no semantic meaning, thus can be the same accross targets.'
    log ''

    log ' --fat-frameworks: classic frameworks with fat libraries are build instead of xcframeworks.'
    log '       Note: Separate fat frameworks that combine the respective simulator and device library will be build for individual device SDKs.'
    log ''

    log ' --xcode: sets custom Xcode version'
    log '       Note: The valid value is a path to a Xcode*.app bundle.'
    log '       Note: sudo rights are required to use this option.'
    log '       Note: when the script exits, it sets the Xcode environment back to the default.'
    log ''

    log ' --output: the frameworks and other artefacts are build to the provided folder.'
    log '       Note: Path to the folder must be absolute.'
    log '       Note: If the output folder does not exist, it is created by the script.'
    log '       Note: If the output folder exists before, it is removed first.'

    log ''
}
