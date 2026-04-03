#!/usr/bin/env bash
#
# Selects the latest stable Xcode version available on the runner.
#
set -euo pipefail

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

# Find the latest versioned Xcode, or fallback to Xcode.app
# Python is used to securely and correctly sort version numbers (e.g. 16.10 > 16.2)
SELECTED_APP=$(python3 -c '
import sys, os, re

apps = sys.argv[1:]
def get_version(path):
    match = re.search(r"Xcode_([0-9]+(?:\.[0-9]+)*)\.app", os.path.basename(path))
    return [int(x) for x in match.group(1).split(".")] if match else [-1]

versioned_apps = [app for app in apps if get_version(app) != [-1]]

if versioned_apps:
    print(sorted(versioned_apps, key=get_version)[-1])
elif "/Applications/Xcode.app" in apps:
    print("/Applications/Xcode.app")
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
if ! sudo -n xcode-select -s "$DEV_DIR"; then
    echo "::error::Failed to switch active developer directory via xcode-select."
    exit 1
fi

echo ""
xcodebuild -version

# Print a prominent notice in the GitHub Actions log
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "::notice::Selected Xcode version: $XCODE_VERSION ($(basename "$SELECTED_APP"))"
