# Crash Symbolication And dSYM Upload

## Guidance

Crash runtime capture is SDK behavior; dSYM upload is an external
release/archive or CI task.

Keep these concerns separate:

- Finding the correct dSYMs for the exact build/archive.
- Uploading those dSYMs to Splunk RUM.
- Verifying that matching crash reports are symbolicated later.

### Find the correct dSYMs

Use dSYMs from the exact build/archive that was distributed. Splunk RUM matches
crash images to uploaded dSYMs by binary UUID; a local rebuild from the same
source can produce different UUIDs and will not symbolicate the released build.

For an Xcode archive, the normal path is:

```text
<AppName>.xcarchive/dSYMs/
```

When giving the user manual Xcode Organizer instructions, be specific: tell
them to right-click the archive row's creation date, version, or archive icon,
then choose Show in Finder. Then tell them to right-click the `.xcarchive`
bundle in Finder, choose Show Package Contents, and use the `dSYMs/` directory.
Warn that right-clicking the app name text in Organizer might not show the
Finder menu. For CI-built TestFlight or App Store releases, retrieve the
`.xcarchive` or extracted `dSYMs/` directory from the CI artifact store; the
local Xcode Organizer workflow does not apply to an archive produced on a CI
machine.

Confirm `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` for release/archive
builds. If the setting is `dwarf` only, there may be no `.dSYM` bundles to
upload. Also confirm `DEBUG_INFORMATION_VERSION = dwarf4`; Splunk RUM does not
currently support DWARF 5 dSYMs.

Upload app and framework dSYMs that are available:

- App executable dSYMs are required.
- Source-built framework dSYMs usually appear in the archive `dSYMs/`
  directory.
- Binary-only framework dSYMs may need to be obtained from the vendor or from
  the XCFramework package.
- Apple system framework frames are not currently symbolicated by Splunk RUM;
  do not present unsymbolicated system frames as a customer setup failure.

Before either upload path, tell the user that dSYMs can contain source paths and
other build metadata, and that Splunk RUM stores uploads permanently and cannot
currently delete them. Reconfirm the realm and exact release/archive dSYM
input, then obtain explicit approval immediately before uploading. Use a dry
run when the selected input is uncertain.

### Upload with `splunk-rum`

Prefer `splunk-rum` as the customer-facing upload tool when it is available.
Verify current syntax with `splunk-rum ios upload --help`; do not invent install
or CI setup instructions when the current public installation path is unclear.

Use environment variables or CI secrets, not literal tokens in tracked files or
shared logs:

`SPLUNK_ACCESS_TOKEN` must contain an organization access token with `API token`
authorization scope and the `power` role, not the RUM access token used by the
app at runtime.

```text
SPLUNK_REALM
SPLUNK_ACCESS_TOKEN
```

Safe command shape:

```bash
SPLUNK_REALM="${SPLUNK_REALM}" \
SPLUNK_ACCESS_TOKEN="${SPLUNK_ACCESS_TOKEN}" \
splunk-rum ios upload --path "path/to/App.xcarchive/dSYMs"
```

The `--path` value should name the archive `dSYMs/` directory, a single
`.dSYM` bundle, or a `.dSYM.zip` / `.dSYMs.zip` file. Avoid generic build output
directories that do not end in one of those forms.

Use `splunk-rum ios list` to inspect recent uploads when credentials are
available. Treat upload visibility as upload confirmation, not proof that a
future crash from a different binary UUID will be symbolicated.

### Upload with `upload-dsyms.sh`

Use `dsymUploader/upload-dsyms.sh` when the Host App wants the repo-local shell
script path or when avoiding a Node/npm CLI dependency is preferable. This
script uses a different token environment variable from `splunk-rum`:

```text
SPLUNK_REALM
SPLUNK_API_ACCESS_TOKEN
SPLUNK_DSYM_DIRECTORY
SPLUNK_DSYM_UPLOAD_ENABLED
```

This token-name difference is intentional in the current tools:

- `splunk-rum`: `SPLUNK_ACCESS_TOKEN`
- `upload-dsyms.sh`: `SPLUNK_API_ACCESS_TOKEN`

Both variables require the organization API access token described above;
neither accepts the app's RUM access token.

Do not put literal API tokens in tracked snippets. Treat direct `--token`
examples in docs as illustrative, not safe defaults.

### CI and build-phase guidance

For CI-built releases, upload after archive/export using the CI system's
retained archive or dSYM artifact. In a standalone post-archive CI step, use the
path inside the archive, for example:

```text
path/to/MyApp.xcarchive/dSYMs/
```

Run Script Build Phase options:

- Prefer a post-archive upload of the complete archive `dSYMs/` directory.
- For a pre-archive Run Script phase, enumerate every `.dSYM` bundle in
  `${DWARF_DSYM_FOLDER_PATH}` and call the CLI once per bundle. Do not hardcode
  `${DWARF_DSYM_FILE_NAME}` or pass the generic build-products folder.
- Copy and call `upload-dsyms.sh` if the project wants a self-contained script.

Gate upload to archive/install/release/tag paths. Debug/local builds should
skip unless the user explicitly requests otherwise.

For Xcode 15+ script phases, `dsymUploader/README.md` documents User Script
Sandboxing implications. Changing sandboxing, adding build phases, or editing
CI workflows requires explicit approval.

Avoid `--debug` in shared logs unless the user approves; debug output can expose
local paths and operational details even when it does not print the token.
