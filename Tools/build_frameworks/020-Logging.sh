#!/bin/sh

# Logging related methods.

# Prints the message on console and write it in the log file.
function log {
    echo "${1}"

    if [ -f "$(log_file)" ]; then
        echo "${1}" >> "$(log_file)"
    fi
}

function log_err {
    echo "❌ ${1}" >&2

    if [ -f "$(log_file)" ]; then
        echo "❌ ${1}" >> "$(log_file)"
    fi
}

function log_delimiter {
    log '⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯'
}

function log_cmd {
    echo '' >>"$(log_file)"
    echo "${1}" >>"$(log_file)"
    echo '' >>"$(log_file)"
}

function log_cmdline {
    log ''
    log "${1}"
    log ''
}

function log_script_settings {
    local frameworks_log=''

    for framework in ${FRAMEWORKS[@]}; do
        frameworks_log+="$framework-$(framework_version $framework).$(framework_build_id  $framework) "
    done

    # Log the run options (defaults of valid commandline options).
    log ''
    log '⎜ Building frameworks for:'
    log '⎜'
    log "⎜ FRAMEWORKS    : ${frameworks_log}"
    log "⎜ SDKS          : $(echo ${SDKS[*]})"
    log "⎜ MACH O TYPES  : $(echo ${MACH_O_TYPES[*]})"
    log '⎜'
    log "⎜ XCODE         : $(xcode-select -p)"
    log '⎜'
    log "⎜ FAT LIBRARIES : ${FAT_FRAMEWORKS_OPTION}"

    if [[ "$FAT_FRAMEWORKS_OPTION" = true ]]; then
        log '⎜ FAT LIBRARIES : ⚠️  Building only fat libraries, no xcframeworks.'
    fi

    log '⎜ '
    log "⎜ DOCUMENTATION : ${DOCUMENTATION_OPTION}"
    log "⎜ WEB DOCUMENT. : ${WEB_DOCUMENTATION_OPTION}"
    log '⎜'
    log "⎜ C# INTERFACE  : ${CSHARP_INTERFACES_OPTION}"
    log '⎜ '
    log "⎜ OUTPUT        : $(release_dir)"
    log ''
}
