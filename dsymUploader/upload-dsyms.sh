#!/bin/bash

# Copyright 2025 Splunk Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Splunk RUM iOS dSYM Upload Script
# This script uploads dSYMs generated during iOS app builds to Splunk RUM
# for crash report symbolication. It's designed to be integrated into Xcode
# build phases or CI/CD pipelines.
#
# Usage:
#   ./upload-dsyms.sh [OPTIONS]
#
# Options:
#   -d, --directory DIR    Directory containing dSYMs or path to .dSYM bundle (required)
#   -r, --realm REALM      Splunk RUM realm (required)
#   -t, --token TOKEN      Splunk API access token (required)
#   --timeout SECONDS      Upload timeout in seconds (default: 300)
#   --debug                Enable debug logging
#   --dry-run              Show what would be uploaded without actually uploading
#   -h, --help             Show this help message
#
# Environment Variables:
#   SPLUNK_REALM            - Splunk RUM realm
#   SPLUNK_API_ACCESS_TOKEN     - Splunk API access token
#   SPLUNK_DSYM_DIRECTORY       - Directory containing dSYMs or path to .dSYM bundle
#   SPLUNK_DSYM_UPLOAD_TIMEOUT  - Upload timeout in seconds (default: 300)
#   SPLUNK_DSYM_UPLOAD_ENABLED  - Set to "false" to disable upload (default: true)
#   SPLUNK_DSYM_UPLOAD_DEBUG    - Set to "true" for verbose output (default: false)

set -euo pipefail

# ============================================================================
# Constants and Defaults
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_TIMEOUT=300
readonly USER_AGENT="splunk-ios-dsym-uploader/1.0"
readonly API_ENDPOINT_TEMPLATE="https://api.%s.signalfx.com/v2/rum-mfm/dsym"

# Global variables
DSYM_DIRECTORY=""
REALM=""
API_ACCESS_TOKEN=""
UPLOAD_TIMEOUT="$DEFAULT_TIMEOUT"
DEBUG_MODE=false
DRY_RUN_MODE=false
successful_uploads=0
failed_uploads=0
found_dsym=0

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo "[$SCRIPT_NAME] INFO: $*"
}

log_warn() {
    echo "[$SCRIPT_NAME] WARN: $*" >&2
}

log_error() {
    echo "[$SCRIPT_NAME] ERROR: $*" >&2
}

log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]] || [[ "${SPLUNK_DSYM_UPLOAD_DEBUG:-false}" == "true" ]]; then
        echo "[$SCRIPT_NAME] DEBUG: $*"
    fi
}

log_success() {
    echo "[$SCRIPT_NAME] SUCCESS: $*"
}

# ============================================================================
# Help and Usage Functions
# ============================================================================

show_help() {
    cat << EOF
$SCRIPT_NAME - Upload iOS dSYMs to Splunk RUM

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -d, --directory DIR    Directory containing dSYMs or path to .dSYM bundle (required)
    -r, --realm REALM      Splunk RUM realm (required)
    -t, --token TOKEN      Splunk API access token (required)
    --timeout SECONDS      Upload timeout in seconds (default: $DEFAULT_TIMEOUT)
    --debug                Enable debug logging
    --dry-run              Show what would be uploaded without actually uploading
    -h, --help             Show this help message

ENVIRONMENT VARIABLES:
    SPLUNK_REALM            Splunk RUM realm
    SPLUNK_API_ACCESS_TOKEN     Splunk API access token
    SPLUNK_DSYM_DIRECTORY       Directory containing dSYMs or path to .dSYM bundle
    SPLUNK_DSYM_UPLOAD_TIMEOUT  Upload timeout in seconds (default: $DEFAULT_TIMEOUT)
    SPLUNK_DSYM_UPLOAD_ENABLED  Set to "false" to disable upload (default: true)
    SPLUNK_DSYM_UPLOAD_DEBUG    Set to "true" for verbose output (default: false)

EXAMPLES:
    # Use command line arguments
    $SCRIPT_NAME -d /path/to/dsyms -r realm -t your_access_token

    # Use environment variables
    export SPLUNK_REALM=realm 
    export SPLUNK_API_ACCESS_TOKEN=your_access_token
    $SCRIPT_NAME -d /path/to/dsyms


EOF
}

show_usage_example() {
    cat << EOF
    # Example usage:
    # Use command line arguments
    $SCRIPT_NAME -d /path/to/dsyms -r realm -t your_access_token

    # Use environment variables
    export SPLUNK_REALM=realm
    export SPLUNK_API_ACCESS_TOKEN=your_access_token
    $SCRIPT_NAME -d /path/to/dsyms

EOF
}

# ============================================================================
# Command Line Parsing
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                DSYM_DIRECTORY="$2"
                shift 2
                ;;
            -r|--realm)
                REALM="$2"
                shift 2
                ;;
            -t|--token)
                API_ACCESS_TOKEN="$2"
                shift 2
                ;;
            --timeout)
                UPLOAD_TIMEOUT="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v zip >/dev/null 2>&1; then
        missing_deps+=("zip")
    fi
    
    if ! command -v find >/dev/null 2>&1; then
        missing_deps+=("find")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            log_error "  - $dep"
        done
        return 1
    fi
    
    return 0
}

validate_configuration() {
    local errors=()
    
    # Check for required parameters
    if [[ -z "$REALM" ]]; then
        errors+=("Splunk RUM realm not specified (use -r/--realm parameter or SPLUNK_REALM environment variable)")
    fi
    
    if [[ -z "$API_ACCESS_TOKEN" ]]; then
        errors+=("Splunk API access token not specified (use -t/--token parameter or SPLUNK_API_ACCESS_TOKEN environment variable)")
    fi
    
    # Validate timeout is a number
    if ! [[ "$UPLOAD_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$UPLOAD_TIMEOUT" -lt 1 ]]; then
        errors+=("Invalid timeout value: $UPLOAD_TIMEOUT (must be a positive integer)")
    fi
    
    # Validate realm format (basic check)
    if [[ -n "$REALM" ]] && ! [[ "$REALM" =~ ^[a-zA-Z0-9-]+$ ]]; then
        errors+=("Invalid realm format: $REALM (should contain only alphanumeric characters and hyphens)")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Configuration validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        echo ""
        show_usage_example
        return 1
    fi
    
    return 0
}

validate_dsym_input() {
    if [[ -z "$DSYM_DIRECTORY" ]]; then
        log_error "dSYM directory input not specified"
        echo ""
        show_usage_example
        return 1
    fi
    
    # Check if it's a directory
    if [[ -d "$DSYM_DIRECTORY" ]]; then
        if [[ ! -r "$DSYM_DIRECTORY" ]]; then
            log_error "dSYM directory is not readable: $DSYM_DIRECTORY"
            return 1
        fi
        
        # Check if the directory itself is a .dSYM bundle
        if [[ "$DSYM_DIRECTORY" =~ \.dSYM$ ]]; then
            log_debug "Validated single dSYM bundle: $DSYM_DIRECTORY"
        else
            log_debug "Validated dSYM directory: $DSYM_DIRECTORY"
        fi
        return 0
    fi
    
    # Neither file nor directory
    log_error "dSYM input does not exist or is not accessible: $DSYM_DIRECTORY"
    return 1
}

# ============================================================================
# Environment Variable Loading
# ============================================================================

load_environment_variables() {
    # Load configuration from environment variables if not set via command line
    if [[ -z "$REALM" ]] && [[ -n "${SPLUNK_REALM:-}" ]]; then
        REALM="$SPLUNK_REALM"
        log_debug "Loaded realm from environment: $SPLUNK_REALM"
    fi
    
    if [[ -z "$API_ACCESS_TOKEN" ]] && [[ -n "${SPLUNK_API_ACCESS_TOKEN:-}" ]]; then
        API_ACCESS_TOKEN="$SPLUNK_API_ACCESS_TOKEN"
        log_debug "Loaded access token from environment"
    fi
    
    if [[ -z "$DSYM_DIRECTORY" ]] && [[ -n "${SPLUNK_DSYM_DIRECTORY:-}" ]]; then
        DSYM_DIRECTORY="$SPLUNK_DSYM_DIRECTORY"
        log_debug "Loaded dSYM directory from environment: $DSYM_DIRECTORY"
    fi
    
    if [[ -n "${SPLUNK_DSYM_UPLOAD_TIMEOUT:-}" ]]; then
        UPLOAD_TIMEOUT="${SPLUNK_DSYM_UPLOAD_TIMEOUT}"
        log_debug "Loaded timeout from environment: $UPLOAD_TIMEOUT"
    fi
}

# ============================================================================
# dSYM Detection Functions
# ============================================================================

validate_dsym_bundle() {
    local dsym_path="$1"
    
    # Check if it's a directory ending in .dSYM
    if [[ ! -d "$dsym_path" ]] || [[ ! "$dsym_path" =~ \.dSYM$ ]]; then
        return 1
    fi
    
    # Check for Contents directory (basic dSYM structure validation)
    if [[ ! -d "$dsym_path/Contents" ]]; then
        log_debug "dSYM bundle missing Contents directory: $dsym_path"
        return 1
    fi
    
    # Check for Info.plist
    if [[ ! -f "$dsym_path/Contents/Info.plist" ]]; then
        log_debug "dSYM bundle missing Info.plist: $dsym_path"
        return 1
    fi
    
    return 0
}

# ============================================================================

# ZIP Creation Functions
# ============================================================================

create_temp_directory() {
    local temp_dir
    temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'dsym-upload')
    if [[ ! -d "$temp_dir" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi
    echo "$temp_dir"
    return 0
}

zip_dsym_file() {
    local dsym_path="$1"
    local temp_dir="$2"
    local dsym_name
    
    dsym_name="$(basename "$dsym_path")"
    local zip_path="$temp_dir/${dsym_name}.zip"
    
    # Create ZIP archive from dSYM directory
    if [[ -d "$dsym_path" ]]; then
        # It's a dSYM bundle directory - zip the entire directory
        local parent_dir
        parent_dir="$(dirname "$dsym_path")"
        if (cd "$parent_dir" && zip -r -q "$zip_path" "$dsym_name"); then
            echo "$zip_path"
            return 0
        else
            log_error "Failed to zip '$dsym_path'. Skipping."
            return 1
        fi
    else
        log_error "Expected directory but got: $dsym_path"
        return 1
    fi
}

# ============================================================================
# Upload Functions
# ============================================================================

build_upload_endpoint() {
    printf "$API_ENDPOINT_TEMPLATE" "$REALM"
}

upload_dsym_file() {
    local zip_path="$1"
    local endpoint
    endpoint="$(build_upload_endpoint)"
    file_name="$(basename "$zip_path")"
    
    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "DRY RUN: Identified dSYM: $file_name"
        return 0
    fi
    
    # Build curl command for multipart/form-data upload
    local curl_args=(
        --show-error
        --fail
        --request PUT
        --header "User-Agent: $USER_AGENT"
        --header "X-SF-Token: $API_ACCESS_TOKEN"
        --form "file=@$zip_path"
        --max-time "$UPLOAD_TIMEOUT"
    )
    
    # Add silent flag unless in debug mode
    if [[ "$DEBUG_MODE" != "true" ]]; then
        curl_args+=(--silent)
    else
        # In debug mode, don't use --verbose to avoid exposing X-SF-Token
        # Instead, provide detailed debug logging without sensitive data
        log_debug "Upload endpoint: $endpoint"
        log_debug "Timeout: ${UPLOAD_TIMEOUT}s"
        log_debug "User-Agent: $USER_AGENT"
        log_debug "X-SF-Token: [REDACTED]"
        log_debug "Upload file: $zip_path"
    fi
    
    # Perform the upload
    local response
    local curl_exit_code
    
    log_debug "Executing curl upload for: $zip_path"
    response=$(curl "${curl_args[@]}" "$endpoint" 2>&1)
    curl_exit_code=$?
    
    # Handle curl response
    if [[ $curl_exit_code -eq 0 ]]; then
        log_success "Upload completed: $(basename "$zip_path")"
        if [[ "$DEBUG_MODE" == "true" ]] && [[ -n "$response" ]]; then
            log_debug "Server response: $response"
        fi
        return 0
    else
        handle_upload_error "$zip_path" "$curl_exit_code" "$response"
        return $curl_exit_code
    fi
}

process_directory() {
    local current_dir="$1"
    local temp_dir="$2"
    
    log_debug "Traversing '$DSYM_DIRECTORY' for .dSYM directories..."

     for entry in "$current_dir"/*; do
        # Check if the entry is a directory
        if [[ -d "$entry" ]]; then
            # If it's a directory, check if its name ends with .dSYM
            if [[ "$entry" == *.dSYM ]]; then
                # It's a .dSYM directory, process it
                log_debug "Processing dSYM: $entry"
                # Validate that it's a proper dSYM bundle
                if validate_dsym_bundle "$entry"; then
                    found_dsym=1
                    if zip_path="$(zip_dsym_file "$entry" "$temp_dir")"; then
                        # Upload the ZIP file
                        if upload_dsym_file "$zip_path"; then
                            ((successful_uploads++))
                        else
                            ((failed_uploads++))
                            exit_code=1 # Set exit_code to non-zero on failure
                        fi
                        # Clean up ZIP file after upload attempt
                        log_debug "Cleaning up ZIP file: $zip_path"
                        rm -f "$zip_path"
                    else
                        log_error "Failed to zip dSYM: $entry"
                        ((failed_uploads++)) # Count zip failure as a failed upload
                        exit_code=1 # Set exit_code to non-zero on failure
                    fi
                else
                    log_warn "Skipping invalid dSYM bundle: $(basename "$entry")"
                fi
            else
                # It's a regular directory (not a .dSYM), recurse into it
                log_debug "Found non-dSYM directory: $(basename "$entry"). Recursing..."
                process_directory "$entry" "$temp_dir"
            fi
        elif [[ -e "$entry" ]]; then
            # Entry exists but is a file (or something else not a directory).
            # This matches your original `elif [[ -e "$entry" ]]` block.
            log_debug "Entry '$(basename "$entry")' in '$current_dir' is a file or not a .dSYM directory. Skipping."
        fi
    done
}

handle_upload_error() {
    local dsym_name="$1"
    local exit_code="$2"
    local response="$3"
    
    case $exit_code in
        6)
            log_error "Could not resolve host for: $dsym_name"
            log_error "Check your network connection and realm configuration"
            ;;
        7)
            log_error "Failed to connect to server for: $dsym_name"
            log_error "Check your network connection and firewall settings"
            ;;
        22)
            log_error "HTTP error response for: $dsym_name"
            if [[ -n "$response" ]]; then
                # Try to extract meaningful error information
                if echo "$response" | grep -q "401\|Unauthorized"; then
                    log_error "Authentication failed - check your access token"
                elif echo "$response" | grep -q "403\|Forbidden"; then
                    log_error "Access forbidden - verify your token permissions"
                elif echo "$response" | grep -q "404\|Not Found"; then
                    log_error "API endpoint not found - check your realm configuration"
                elif echo "$response" | grep -q "413\|Request Entity Too Large"; then
                    log_error "File too large - consider reducing dSYM size"
                elif echo "$response" | grep -q "429\|Too Many Requests"; then
                    log_error "Rate limited - try again later"
                elif echo "$response" | grep -q "500\|Internal Server Error"; then
                    log_error "Server error - try again later"
                else
                    log_error "Server response: $response"
                fi
            fi
            ;;
        28)
            log_error "Upload timed out after ${UPLOAD_TIMEOUT}s for: $dsym_name"
            log_error "Consider increasing timeout with --timeout option"
            ;;
        *)
            log_error "Upload failed with exit code $exit_code for: $dsym_name"
            if [[ -n "$response" ]]; then
                log_error "Error details: $response"
            fi
            ;;
    esac
}

# ============================================================================
# Cleanup/Users/aditis3/codeRepos/splunk-otel-ios/dsymUploader Functions
# ============================================================================

cleanup_temp_directory() {
    local temp_dir="${1:-}"
    if [[ -n "$temp_dir" ]] && [[ -d "$temp_dir" ]]; then
        log_debug "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local temp_dir=""
    local exit_code=0
    
    # Trap to ensure cleanup on exit
    trap 'cleanup_temp_directory "${temp_dir:-}"' EXIT
    
    log_debug "Starting dSYM upload process"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load environment variables
    load_environment_variables
    
    # Check if upload is disabled
    if [[ "${SPLUNK_DSYM_UPLOAD_ENABLED:-true}" == "false" ]]; then
        log_info "dSYM upload is disabled (SPLUNK_DSYM_UPLOAD_ENABLED=false)"
        return 0
    fi
    
    # Validate dependencies and configuration
    if ! validate_dependencies; then
        return 1
    fi
    
    if ! validate_configuration; then
        return 1
    fi
    
    # Validate the dSYM directory
    if ! validate_dsym_input; then
        return 1
    fi
    
    if [[ "$DSYM_DIRECTORY" =~ \.dSYM$ ]]; then
        log_info "Using dSYM bundle: $DSYM_DIRECTORY"
    else
        log_info "Using directory: $DSYM_DIRECTORY"
    fi
    log_info "Using realm: $REALM"
    
    # Create temporary directory for ZIP files
    if ! temp_dir="$(create_temp_directory)"; then
        return 1
    fi
    log_debug "Created temporary directory: $temp_dir"

    # Check if the provided directory is itself a .dSYM bundle
    if [[ "$DSYM_DIRECTORY" =~ \.dSYM$ ]]; then
        log_debug "Processing single dSYM bundle: $DSYM_DIRECTORY"
        # Validate that it's a proper dSYM bundle
        if validate_dsym_bundle "$DSYM_DIRECTORY"; then
            found_dsym=1
            if zip_path="$(zip_dsym_file "$DSYM_DIRECTORY" "$temp_dir")"; then
                # Upload the ZIP file
                if upload_dsym_file "$zip_path"; then
                    ((successful_uploads++))
                else
                    ((failed_uploads++))
                    exit_code=1 # Set exit_code to non-zero on failure
                fi
                # Clean up ZIP file after upload attempt
                log_debug "Cleaning up ZIP file: $zip_path"
                rm -f "$zip_path"
            else
                log_error "Failed to zip dSYM: $DSYM_DIRECTORY"
                ((failed_uploads++)) # Count zip failure as a failed upload
                exit_code=1 # Set exit_code to non-zero on failure
            fi
        else
            log_error "Invalid dSYM bundle: $DSYM_DIRECTORY"
            exit_code=1
        fi
    else
        # It's a regular directory, process it recursively
        process_directory "$DSYM_DIRECTORY" "$temp_dir"
    fi

    if [[ $found_dsym -eq 0 ]]; then
        log_error "No dSYMs found in '$DSYM_DIRECTORY'."
        return 1
    elif [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "DRY RUN complete: Found $successful_uploads dSYM(s) that would be uploaded"
    
    else
        log_info "Processing complete:  Successful uploads: $successful_uploads, Failed uploads: $failed_uploads"
    fi
    return $exit_code
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
