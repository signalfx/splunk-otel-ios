#!/bin/sh

# Prepare for the script exits.
trap "command exit 1;" TERM
trap "command exit 0" QUIT
export TOP_PID=$$


# Using this method as an alias for buildin `exit` ensures the Xcode is reset back to default.

function exit_script {
    local exit_code=$1

    if [ ! -z "${CUSTOM_XCODE}" ]; then
        log ''
        log '🔆 🛠  Resetting Xcode to default.'

        sudo xcode-select -r

        log "$(xcode-select -p)"
        log ''
    fi

    if [ ! -z "${exit_code}" ] && [ ! "${exit_code}" == "0" ]; then
        # Exit with error code 1 (err)

        log_err ''
        log_err "$(log_delimiter)"
        log_err ''
        log_err "   The script exits with error code '${exit_code}'."
        log_err "   The output is in '$(release_dir)'."
        log_err ''

        kill -s TERM $TOP_PID

    elif [ -z "${PRINT_HELP}" ]; then
        # Exit with error code 0 (ok)

        log ''
        log "$(log_delimiter)"
        log ''
        log '❇️'
        log "❇️  The script ended successfully."
        log "❇️  The output is in '$(release_dir)'."
        log '❇️'
        log ''

        kill -s QUIT $TOP_PID
    else
        # Do not print the ok message when exiting after printing help message.
        kill -s QUIT $TOP_PID
    fi
}

# Replace buildin `exit` with the method for this script.
alias exit=exit_script
