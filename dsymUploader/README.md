# Splunk RUM iOS Upload Script

The `upload-dsyms.sh` script automatically uploads debug symbol files (dSYMs) generated during your iOS app builds to Splunk RUM for crash report symbolication. The script directly uploads dSYMs without requiring the Splunk RUM CLI.

### Example Usage
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

### Prerequisites

1. **System Requirements:**
   - bash shell
   - curl (for HTTP uploads)
   - zip (for creating archives)

2. **Obtain your Splunk RUM configuration:**
   - Splunk realm (e.g., "us0", "eu0", "ap0")
   - API access token [Docs Link](https://help.splunk.com/en/splunk-observability-cloud/administer/authentication-and-security/authentication-tokens/api-access-tokens)

### Integration with Xcode

#### Method 1: Xcode Build Phase (Recommended)

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to the "Build Phases" tab
4. Click the "+" button and choose "New Run Script Phase"
5. Rename the phase to "Upload dSYMs to Splunk RUM"
6. In the script text area, add:

```bash
# Path to the upload script
SCRIPT_PATH="${SRCROOT}/path/to/dsymUploader/upload-dsyms.sh"

# Check if script exists and is executable
if [[ -x "$SCRIPT_PATH" ]]; then
    # Run the script with your configuration
    "$SCRIPT_PATH" \
        --realm "YOUR_REALM" \
        --token "YOUR_API_ACCESS_TOKEN" \
        --directory "${DWARF_DSYM_FOLDER_PATH}" \
        --debug
else
    echo "Warning: Splunk dSYM upload script not found or not executable at: $SCRIPT_PATH"
fi
```

7. **Configure Input Files** (Optional but recommended for better build caching):
   - Add `$(DWARF_DSYM_FOLDER_PATH)/$(DWARF_DSYM_FILE_NAME)`

8. **Set your configuration** by either:

**Method A - Command Line Arguments (Recommended):**
Replace `YOUR_REALM` and `YOUR_API_ACCESS_TOKEN` in the script above with your actual values.

**Method B - Environment Variables:**
```bash
export SPLUNK_RUM_REALM="YOUR_REALM"  # Your Splunk realm
export SPLUNK_API_ACCESS_TOKEN="YOUR_API_ACCESS_TOKEN"
export SPLUNK_DSYM_UPLOAD_DEBUG="true"  # Optional: Enable verbose logging
```

#### Method 2: Direct Script Integration

If you prefer to include the script directly in your project:

1. Copy `upload-dsyms.sh` to your Xcode project directory
2. Add it to your Xcode project (but don't add it to any target)
3. Follow the same build phase setup as Method 1, but use:

```bash
"${SRCROOT}/upload-dsyms.sh" --realm "YOUR_REALM" --token "YOUR_TOKEN" --directory "${DSYM_FOLDER_PATH}"
```

### Integration with CI/CD

#### GitHub Actions Example

```yaml
- name: Upload dSYMs to Splunk RUM
  run: |
    ./dsymUploader/upload-dsyms.sh \
      --realm "${SPLUNK_REALM}" \
      --token "${{ secrets.SPLUNK_API_ACCESS_TOKEN }}" \
      --directory "${{ runner.temp }}/build/dSYMs" \
```

### Configuration

The script can be configured using command line arguments or environment variables:

#### Command Line Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `-r, --realm REALM` | Splunk realm (required) | `us0`, `eu0`, `ap0` |
| `-t, --token TOKEN` | API access token (required) | `ABC123...` |
| `-d, --directory DIR` | Directory containing dSYMs | `/path/to/dsyms` |
| `--timeout SECONDS` | Upload timeout in seconds | `300` |
| `--debug` | Enable verbose logging | - |
| `--dry-run` | Show what would be uploaded | - |
| `-h, --help` | Show help message | - |

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPLUNK_REALM` | Splunk  Realm | - |
| `SPLUNK_API_ACCESS_TOKEN` | API access token | - |
| `SPLUNK_DSYM_DIRECTORY` | Directory containing dSYMs |
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

#### Missing Dependencies
```
ERROR: Missing required dependencies: curl
```
- Install missing system dependencies (curl, zip, find)
- These are typically pre-installed on macOS and most CI systems

#### Configuration Errors
```
ERROR: Splunk RUM realm not specified
```
- Provide realm using `--realm` argument or `SPLUNK_REALM` environment variable
- Provide access token using `--token` argument or `SPLUNK_API_ACCESS_TOKEN` environment variable

#### No dSYMs Found
```
ERROR: No dSYMs found in directory
```
- Ensure your build settings generate dSYMs (`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`)
- Check that the build completed successfully before the script runs
- Verify the directory path contains `.dSYM` or bundles
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
- Verify your realm is correct (e.g., "us0", "eu0", "ap0")
- Check network connectivity and DNS resolution
- Verify firewall allows outbound HTTPS connections to api.{realm}.signalfx.com

### Security Considerations

- **Access Tokens:** Store API access tokens securely:
  - Use Xcode's User-Defined Build Settings for local development
  - Use CI/CD secret management for automated builds
  - Never commit tokens to source control

- **Network Access:** The script requires outbound HTTPS access to `api.{realm}.signalfx.com`
- **Temporary Files:** The script creates temporary ZIP files during upload and cleans them up automatically

### Performance Impact

- **Build Time:** dSYM uploads can run in parallel with other build phases
- **File Size:** Upload time depends on dSYM size (typically 1-10MB per binary)
- **Timeout:** Uploads are limited by timeout setting to prevent hanging builds
- **Network:** Uses HTTP/1.1 with connection reuse for multiple uploads


## Support

For issues or questions:
1. Check the troubleshooting section above
2. Enable debug logging (`--debug`) for more detailed output
3. Test with dry run (`--dry-run`) to validate configuration
4. Consult the Splunk RUM documentation
5. File an issue in the splunk-otel-ios repository
