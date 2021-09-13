#!/bin/bash
set -e
set -x

# This gobbledygook gets a list of simulator iPhones and picks the id of the first one
# (different samples of the output of this have [] or () as delimiters of the last (id) field)
TEST_DEVICE=`xcrun xctrace list devices 2>&1  | grep iPhone | head -1  | sed 's/.*[([]//' | sed 's/.$//'`

xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SmokeTest -configuration Debug test -destination platform="iOS Simulator,id=$TEST_DEVICE"
