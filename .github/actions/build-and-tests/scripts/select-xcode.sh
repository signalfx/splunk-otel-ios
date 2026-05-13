#!/usr/bin/env bash
#
# Selects the latest stable Xcode version available on the runner.
#
set -euo pipefail
unset DEVELOPER_DIR    # ignore any inherited value before we pick

echo "Available Xcode installations:"
shopt -s nullglob
xcodes=(/Applications/Xcode*.app)

if [ ${#xcodes[@]} -eq 0 ]; then
    echo "::error::No Xcode installations found in /Applications/"
    exit 1
fi

for app in "${xcodes[@]}"; do
    echo " - $(basename "$app")"
done
echo ""

# Find the latest stable versioned Xcode, or fallback to Xcode.app
# Python is used to securely and correctly sort version numbers (e.g. 16.10 > 16.2)
SELECTED_APP=$(python3 -c '
import sys, os, re, plistlib

apps = sys.argv[1:]

def get_bundle_version_string(path):
    info_plist = os.path.join(path, "Contents", "Info.plist")
    try:
        with open(info_plist, "rb") as f:
            info = plistlib.load(f)
        return str(info.get("CFBundleShortVersionString", "")).strip()
    except Exception:
        return ""

def parse_version_string(version):
    match = re.search(r"([0-9]+(?:\.[0-9]+)*)", version)
    return [int(x) for x in match.group(1).split(".")] if match else None

def get_version(path):
    if "beta" in path.lower():
        return [-1]

    version_str = get_bundle_version_string(path)

    if "beta" in version_str.lower():
        return [-1]

    parts = parse_version_string(version_str)
    if parts:
        return parts

    match = re.search(r"Xcode_([0-9]+(?:\.[0-9]+)*)\.app", os.path.basename(path))
    return [int(x) for x in match.group(1).split(".")] if match else [-1]

versioned_apps = [app for app in apps if get_version(app) != [-1]]

if versioned_apps:
    print(sorted(versioned_apps, key=get_version)[-1])
' "${xcodes[@]}")

if [ -z "$SELECTED_APP" ]; then
    echo "::error::Could not determine a valid stable Xcode application to select."
    exit 1
fi

DEV_DIR="$SELECTED_APP/Contents/Developer"
if [ ! -d "$DEV_DIR" ]; then
    echo "::error::Developer directory not found at $DEV_DIR"
    exit 1
fi

echo "Selecting: $(basename "$SELECTED_APP")"
export DEVELOPER_DIR="$DEV_DIR"
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "DEVELOPER_DIR=$DEV_DIR" >> "$GITHUB_ENV"
fi

echo ""
XCODE_VERSION_OUTPUT=$(xcodebuild -version)
echo "$XCODE_VERSION_OUTPUT"

# Print a prominent notice in the GitHub Actions log
XCODE_VERSION=$(echo "$XCODE_VERSION_OUTPUT" | head -n 1)
echo "::notice::Selected Xcode version: $XCODE_VERSION ($(basename "$SELECTED_APP"))"
