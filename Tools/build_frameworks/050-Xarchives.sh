#!/bin/sh

# Building SDK archive, i.e., the binary and support files for particular class of devices (SDK)

function assert_all_params_valid {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check individual params validity
    assert_valid_framework $framework
    assert_valid_sdk $sdk
    assert_valid_mach_o_type $mach_o_type
    assert_valid_architecture $architecture
}

# Composes the respective commandline and then build the archive.
function build_xarchive {
    local framework=$1
    local sdk=$2
    local mach_o_type=$3
    local architecture=$4

    # Check params validity
    assert_all_params_valid $framework $sdk $mach_o_type $architecture

    local support_catalyst="NO"
    # Build flags for building Catalyst SDK
    if [[ "$(is_catalyst_sdk $SDK)" = true ]]; then
        support_catalyst="YES"
    fi

    # Set Session Replay remote dependency git branch. It's used in MRUMSessionRecording Package.swift.
    #export SESSION_REPLAY_BRANCH="main" # change to main once develop is merged into main
    export SESSION_REPLAY_BRANCH="develop"

    # Build flags for building specific architecture only
    # If `architecture` attribute is not provided, all valid architectures
    # for given SDK (iOS, tvOS...) are build which means that some archives
    # binaries are fat (multi-architecture).
    local arch_switches=""
    if [[ ! -z "${architecture}" ]]; then
        arch_switches=" ONLY_ACTIVE_ARCH=NO ARCHS=${architecture}"
    fi

    local archive_path="$(xarchive_path $framework $sdk $mach_o_type $architecture)"

    log "$(log_delimiter)"
    
	log "Available xcodes:"
	mdfind 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"'


    log "$(log_delimiter)"
    log "🗄  Archiving ${framework}:"
    log "   sdk           = ${sdk}"
    log "   type          = ${mach_o_type}"
    log "   arch switches =${arch_switches}"
    log "   catalyst      = ${support_catalyst}"
    log "   session replay git branch = ${SESSION_REPLAY_BRANCH}"
    
    log "$(log_delimiter)"
    
    # Composing the commandline
    local cmd=""
    cmd+="xcodebuild clean archive"
    cmd+=" -workspace $(mrum_workspace)"
    cmd+=" -scheme ${framework}"
    cmd+=" -archivePath ${archive_path}"
    cmd+=" -configuration Release-${mach_o_type}"
    cmd+=" -sdk ${sdk}"
	cmd+=" -verbose"
#    cmd+=" -silent"
    cmd+=" SKIP_INSTALL=NO"
    cmd+=" DEPLOYMENT_POSTPROCESSING=YES"
    cmd+=" BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
    cmd+=" SUPPORTS_MACCATALYST=${support_catalyst}"
    cmd+=" ${arch_switches}"
#    cmd+=" >>'$(log_file)' 2>&1"

    log_cmd "${cmd}"

    if ! eval "${cmd}"; then
        log_err ''
        log_err "  Xcodebuild archive failed. Check the log for errors."
        exit 1
    fi

    local arch_log=''
    if [[ ! -z "${architecture}" ]]; then
        arch_log=" ${architecture}"
    fi

    # Check the framework is really build, i.e., the archive exists.
    if [ -d "${archive_path}" ]; then
        log ''
        log "   ✅ ${framework} ${sdk} ${mach_o_type}${arch_log} created."
        log ''
    else
        log_err ''
        log_err "    ${framework} ${sdk} ${mach_o_type}${arch_log} not created. Stopping."
        exit 1;
    fi
}

function build_xarchives {
    for FRAMEWORK in ${FRAMEWORKS[@]}; do

        for SDK in ${SDKS[@]}; do

            for MACH_O_TYPE in ${MACH_O_TYPES[@]}; do

                build_xarchive $FRAMEWORK $SDK $MACH_O_TYPE
            done;
        done;
    done;
}
