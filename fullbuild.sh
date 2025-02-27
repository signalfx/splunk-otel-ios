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

swiftlint

# Make sure the version numbers on the podspec and SplunkRum.swift match
echo "Checking that version numbers match"
rumVer="$(grep SplunkRumVersionString SplunkRumWorkspace/SplunkRum/SplunkRum/SplunkRum.swift | grep -o '[0-9]*\.[0-9]*\.[0-9]*')"
podVer="$(grep s.version SplunkOtel.podspec | grep -o '[0-9]*\.[0-9]*\.[0-9]*')"
if [ $podVer != $rumVer ]; then
    echo "Error: The version numbers in SplunkOtel.podspec and SplunkRum.swift do not match"
    exit 1
fi

# Check the podspec is valid
pod lib lint SplunkOtel.podspec --allow-warnings

xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Debug build
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Debug test
xcodebuild -workspace SplunkRumWorkspace/SplunkRumWorkspace.xcworkspace -scheme SplunkOtel -configuration Release build

# Now try to do a swift build to ensure that the package dependencies are properly in synch
rm -rf ./.build
SIMULATOR_SDK="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
SIMULATOR_TARGET="arm64-apple-ios17-simulator"
swift build -v --sdk "$SIMULATOR_SDK" --triple "$SIMULATOR_TARGET" --scratch-path "./.build/$SIMULATOR_TARGET"

# repeat targeting a real device
rm -rf ./.build
DEVICE_SDK="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
DEVICE_TARGET="arm64-apple-ios18.2"
swift build -v --sdk "$DEVICE_SDK" --triple "$DEVICE_TARGET" --scratch-path "./.build/$DEVICE_TARGET"

echo "========= Congratulations! ========="
