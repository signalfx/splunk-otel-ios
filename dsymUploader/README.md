# Splunk RUM iOS Upload Script

The `upload-dsyms.sh` script automatically uploads debug symbol files (dSYMs) generated during your iOS app builds to Splunk RUM for crash report symbolication. The script directly uploads dSYMs without requiring the Splunk RUM CLI.

## Example Usage
You can configure the script using either environment variables or command-line arguments. Command-line arguments will always take precedence over environment variables.

```bash
# Basic usage using command line arguments
./upload-dsyms.sh --realm realm --token YOUR_API_TOKEN --directory ./build/dSYMs

# With debug logging
./upload-dsyms.sh --realm realm --token YOUR_API_TOKEN --directory ./build/dSYMs --debug

# Dry run to test configuration
./upload-dsyms.sh --realm realm --token YOUR_API_TOKEN --directory ./build/dSYMs --dry-run

# Using environment variables
export SPLUNK_REALM=realm
export SPLUNK_API_ACCESS_TOKEN=YOUR_API_TOKEN
./upload-dsyms.sh --directory ./build/dSYMs
```

## Prerequisites

1. **System Requirements:**
   - bash shell
   - curl (for HTTP uploads)
   - zip (for creating archives)

2. **Obtain your Splunk RUM configuration:**
   - Splunk realm (e.g., "us0", "eu0", "au0")
   - API access token [Docs Link](https://help.splunk.com/en/splunk-observability-cloud/administer/authentication-and-security/authentication-tokens/api-access-tokens)

## Integration Methods

### Method 1: Xcode Build Phase

1. **Copy the script to your project:**
   - Copy `upload-dsyms.sh` to your Xcode project directory
   - Add it to your Xcode project (but don't add it to any target)
   - Ensure the script file has execute permissions (`chmod +x`)

2. **Set up the build phase:**
   - In Xcode, select your project in the navigator
   - Select your app target
   - **For Xcode 15 or later**, Go to "Build Settings" tab, Set "User Script Sandboxing" to `No` 
   - Go to the "Build Phases" tab
   - Click the "+" button and choose "New Run Script Phase"
   - Rename the phase to "Upload dSYMs to Splunk RUM"
   - **Important:** Position this phase after "Copy Bundle Resources" or any other phases that generate the build artifacts to ensure dSYMs are available

3. **Configure the script phase:**
   In the Shell script text area of the "Upload dSYMs to Splunk RUM" build phase, add:

```bash

# IMPORTANT: Update this path to the actual location where you copied upload-dsyms.sh in your project.
# For example: SCRIPT_PATH="${SRCROOT}/Scripts/upload-dsyms.sh"
SCRIPT_PATH="${SRCROOT}/path/to/upload-dsyms.sh"

# Check if script exists and is executable
if [[ -x "$SCRIPT_PATH" ]]; then
    echo "Running Splunk dSYM upload script..."
    
    # Run the script with your configuration
    # Capture the exit code of the upload script
    "$SCRIPT_PATH" \
        --realm "YOUR_REALM" \
        --token "YOUR_API_ACCESS_TOKEN" \
        --directory "${DWARF_DSYM_FOLDER_PATH}" \
        --debug  # Optional: Enable verbose logging
    
    UPLOAD_SCRIPT_EXIT_CODE=$? # Get the exit code of the last executed command

    if [[ $UPLOAD_SCRIPT_EXIT_CODE -ne 0 ]]; then
        echo "Error: Splunk dSYM upload failed with exit code $UPLOAD_SCRIPT_EXIT_CODE."
        exit 1 # Fail the Xcode build
    else
        echo "Splunk dSYM upload completed successfully."
    fi
else
    echo "Error: Splunk dSYM upload script not found or not executable at: $SCRIPT_PATH"
    exit 1 # Fail the Xcode build if the script itself is missing or not executable
fi
```
   
4. **Set your configuration (by either)**:
      
   - **Method A - Command Line Arguments:**
        Replace `DWARF_DSYM_FOLDER_PATH`, `YOUR_REALM` and `YOUR_API_ACCESS_TOKEN` in the script above with your actual values. Refer to the NOTE below for guidance on DWARF_DSYM_FOLDER_PATH

   - **Method B - Environment Variables:**
   ```bash
   export DWARF_DSYM_FOLDER_PATH="path/to/dSYMs" 
   export SPLUNK_REALM="YOUR_REALM"  # Your Splunk realm
   export SPLUNK_API_ACCESS_TOKEN="YOUR_API_ACCESS_TOKEN"  # Your Splunk API access token
   export SPLUNK_DSYM_UPLOAD_DEBUG="true"  # Optional: Enable verbose logging
   ```
   - **NOTE:** \
      DWARF_DSYM_FOLDER_PATH is the path of the directory containing the dSYM bundle(s).
         - If building locally, this is typically ${BUILT_PRODUCTS_DIR} for non-install local builds
         - For distribution builds, use the path to your .xcarchive. Default: (~/Library/Developer/Xcode/Archives/AppName.xcarchive)

5. **RECOMMENDED** Run script: 
   - Check: For install builds only
   - Uncheck: Based on dependency analysis

### Method 2: GitHub Actions (CI/CD)

  - Set SPLUNK_API_ACCESS_TOKEN as a secret in Github, 
  - Set SPLUNK_REALM as a variable or replace with your realm
  - Replace /path/to/dSYMs with directory that contains dSYMs
  - Replace /path/to/upload-dsyms.sh with the location of the script relative to your GitHub Actions workflow's working directory 

```yaml
- name: Upload dSYMs to Splunk RUM
  run: |
    /path/to/upload-dsyms.sh \
      --realm "${SPLUNK_REALM}" \
      --token "${{ secrets.SPLUNK_API_ACCESS_TOKEN }}" \
      --directory "${{ runner.temp }}/path/to/dSYMs" \
```

### Configuration

The script can be configured using command line arguments or environment variables:

#### Command Line Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `-r, --realm REALM` | Splunk realm (required) | `us0`, `eu0`, `au0` |
| `-t, --token TOKEN` | API access token (required) | `ABC123...` |
| `-d, --directory DIR` | Directory containing dSYMs or path to .dSYM bundle | `/path/to/dsyms` |
| `--timeout SECONDS` | Upload timeout in seconds | `300` |
| `--debug` | Enable verbose logging | - |
| `--dry-run` | Show what would be uploaded | - |
| `-h, --help` | Show help message | - |

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPLUNK_REALM` | Splunk Realm | - |
| `SPLUNK_API_ACCESS_TOKEN` | API access token | - |
| `SPLUNK_DSYM_DIRECTORY` | Directory containing dSYMs or path to .dSYM bundle | - |
| `SPLUNK_DSYM_UPLOAD_TIMEOUT` | Upload timeout in seconds | `300` |
| `SPLUNK_DSYM_UPLOAD_ENABLED` | Enable/disable upload | `true` |
| `SPLUNK_DSYM_UPLOAD_DEBUG` | Enable verbose logging | `false` |

### Behavior

- **dSYM Processing:** The script finds all `.dSYM` in the specified directory, creates ZIP archives, and uploads them directly to the Splunk API.
- **Error Handling:** Upload failures are logged with detailed error messages and exit codes.
- **Timeout:** Uploads have a configurable timeout to prevent hanging builds (default: 300 seconds).
- **Dry Run:** Use `--dry-run` to test configuration without actually uploading files.

### Troubleshooting

#### Script Not Found
```
Warning: Splunk dSYM upload script not found or not executable
```
- Verify the script path in your build phase
- Ensure the script file has execute permissions (`chmod +x`)

####  Operation Not Permitted
```
Sandbox: bash(23865) deny(1) file-read-data /../upload-dsyms.sh
```
- Set 'User Script Sandboxing' to No in the Build Settings of Xcode

#### Missing Dependencies
```
ERROR: Missing required dependencies: curl
```
- Install missing system dependencies (curl, zip, find)
- These are typically pre-installed on macOS and most CI systems

#### Configuration Errors
```
ERROR: Splunk RUM realm not specified OR ERROR: Splunk API access token not specified
```
- Provide realm using `--realm` argument or `SPLUNK_REALM` environment variable
- Provide access token using `--token` argument or `SPLUNK_API_ACCESS_TOKEN` environment variable

#### No dSYMs Found
```
ERROR: No dSYMs found in directory
```
- Ensure your build settings generate dSYMs (`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`)
- Check that the build completed successfully before the script runs
- Verify the directory is .dSYM extension or contains `.dSYM` bundles
- Use `--debug` flag to see detailed search information

#### Upload Failures
```
ERROR: Authentication failed - check your access token
```
- Check your API access token is valid and has the required permissions
- Verify your realm configuration is correct
- Check network connectivity and firewall settings
- Enable debug logging (`--debug`) for more details

#### Connectivity Issues
```
ERROR: Could not resolve host
```
- Verify your realm is correct (e.g., "us0", "eu0", "au0")
- Check network connectivity and DNS resolution
- Verify firewall allows outbound HTTPS connections to api.{realm}.signalfx.com

#### Build Output Warning 
```
Run script build phase 'Upload dSYMs to Splunk RUM' will be run during every build because it does not specify any outputs. To address this issue, either add output dependencies to the script phase, or configure it to run in every build by unchecking "Based on dependency analysis" in the script phase.
```
- Uncheck "Based on dependency analysis" in the script phase

### Security Considerations

- **Access Tokens:** Store API access tokens securely:
  - Use Xcode's User-Defined Build Settings for local development
  - Use CI/CD secret management for automated builds
  - Never commit tokens to source control

- **Network Access:** The script requires outbound HTTPS access to `api.{realm}.signalfx.com`
- **Temporary Files:** The script creates temporary ZIP files during upload and cleans them up automatically

### Performance Impact

- **File Size:** Upload time depends on dSYM size (typically 1-10MB per binary)
- **Timeout:** Uploads are limited by timeout setting to prevent hanging builds
- **Network:** Uses HTTP/1.1 with connection reuse for multiple uploads


## Support

For issues or questions:
1. Check the troubleshooting section above
2. Enable debug logging (`--debug`) for more detailed output
3. Test with dry run (`--dry-run`) to validate configuration
4. Consult the Splunk RUM documentation
5. File an issue in the [splunk-otel-ios](https://github.com/signalfx/splunk-otel-ios) repository
