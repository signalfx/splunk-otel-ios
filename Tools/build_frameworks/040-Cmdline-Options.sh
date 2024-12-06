#!/bin/sh

function process_cmdline_options {
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help;
                PRINT_HELP=true
                exit 0
                ;;
            -f|--frameworks)
                process_frameworks_option $2
                shift # past argument
                shift # past value
                ;;
            -m|--mach-o-types)
                process_mach_o_types_option $2
                shift # past argument
                shift # past value
                ;;
            -s|--sdks)
                process_sdks_option $2
                shift # past argument
                shift # past value
                ;;
            -x|--xcode)
                process_xcode_option $2
                shift # past argument
                shift # past value
                ;;
            -c|--csharp)
                process_csharp_option
                shift # past argument
                ;;
            -d|--documentation)
                process_documentation_option
                shift # past argument
                ;;
            -w|--web-documentation)
                process_web_documentation_option
                shift # past argument
                ;;
            -i|--increase-build-id)
                process_increase_build_id
                shift # past argument
                ;;
            -t|--fat-frameworks)
                process_fat_frameworks_option
                shift # past argument
                ;;
            -o|--output)
                process_output_option $2
                shift # past argument
                shift # past value
                ;;
            -*|--*)
                log_err "  Unknown option '$1', use --help"
                exit 1
                ;;
            *)
                positional_args+=("$1") # save positional arg
                shift # past argument
                ;;
        esac
    done

    log_script_settings
}
