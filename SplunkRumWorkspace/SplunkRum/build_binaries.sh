#!/bin/bash
set -ex

archive() {
  sdk=$1

  xcodebuild archive \
    -project SplunkRum.xcodeproj \
    -scheme SplunkOtel \
    -sdk $sdk \
    -archivePath archives/SplunkOtel-$sdk.xcarchive \
    -derivedDataPath derived \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    SWIFT_COMPILATION_MODE=wholemodule
}

mkdir -p frameworks

archive iphonesimulator "iOS Simulator"
archive iphoneos iOS

xcodebuild -create-xcframework \
  -archive archives/SplunkOtel-iphonesimulator.xcarchive \
  -framework SplunkOtel.framework \
  -archive archives/SplunkOtel-iphoneos.xcarchive \
  -framework SplunkOtel.framework \
  -output xcframeworks/SplunkOtel.xcframework