#!/bin/sh

function set_custom_xcode {
    local custom_xcode=$1

    if [ -z "${custom_xcode}" ]; then
        return
    fi

    if [ ! -d "${custom_xcode}" ]; then
        log_err ''
        log_err " Xcode option '${custom_xcode}' is not a valid directory."
        log_err ''
        exit 1
    fi

    log ''
    log "🔆 🛠  Setting custom Xcode to ${custom_xcode}."
    log ''
    sudo xcode-select -s "${custom_xcode}"
}

function process_xcode_option {
    CUSTOM_XCODE=$1

    if [ -z "${CUSTOM_XCODE}" ]; then
        log_err ''
        log_err " A value must be provided with -x|--xcode option."
        log_err ''
        exit 1
    fi

    set_custom_xcode "${CUSTOM_XCODE}"
}
