#!/bin/bash
set -e
# FIXME obviously not a full build yet
swiftlint --strict
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Debug build
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Debug test
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Release build

echo "========= Congratulations! ========="
