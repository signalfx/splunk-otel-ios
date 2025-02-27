#!/bin/bash
set -ex

# on arm64 macOS, homebrew is custom build into /opt/homebrew
PATH=${PATH}:/opt/homebrew/bin/

if which swiftlint >/dev/null; then
   echo "Swiftlint installation found"
else
  echo "warning: SwiftLint not installed, installing via Homebrew"
  brew install swiftlint
fi

swiftlint --strict

# Make sure the version numbers on the podspec and SplunkRum.swift match
echo "Checking that version numbers match"
rumVer="$(grep SplunkRumVersionString SplunkRumWorkspace/SplunkRum/SplunkRum/SplunkRum.swift | grep -o '[0-9]*\.[0-9]*\.[0-9]*')"
podVer="$(grep s.version SplunkOtel.podspec | grep -o '[0-9]*\.[0-9]*\.[0-9]*')"
if [ $podVer != $rumVer ]; then
    echo "Error: The version numbers in SplunkOtel.podspec and SplunkRum.swift do not match"
    exit 1
fi

# Check the podspec is valid
pod lib lint SplunkOtel.podspec

xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Debug build
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Debug test
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Release build

# Now try to do a swift build to ensure that the package dependencies are properly in synch
rm -rf ./.build
swift build -v -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios11.0-simulator"
rm -rf ./.build
# repeat targeting a real device
swift build -v -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphoneos --show-sdk-path`" -Xswiftc "-target" -Xswiftc "arm64-apple-ios14.0"

echo "========= Congratulations! ========="
