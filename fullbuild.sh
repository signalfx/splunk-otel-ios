#!/bin/bash
set -e
swiftlint --strict
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Debug build
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Debug test
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkRum -configuration Release build

# Now try to do a swift build to ensure that the package dependencies are properly in synch
rm -rf ./.build
swift build -v -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios11.0-simulator"
rm -rf ./.build
# repeat targeting a real device
swift build -v -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphoneos --show-sdk-path`" -Xswiftc "-target" -Xswiftc "arm64-apple-ios14.0"

echo "========= Congratulations! ========="
