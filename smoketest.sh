#!/bin/bash
set -e
set -x

# This gobbledygook gets a list of simulator iPhones and picks the id of the first one
# (different samples of the output of this have [] or () as delimiters of the last (id) field)
TEST_DEVICE=`xcrun xctrace list devices 2>&1  | grep iPhone | head -1  | sed 's/.*[([]//' | sed 's/.$//'`

xcodebuild -workspace SmokeTest/SmokeTest.xcworkspace \-scheme SmokeTest clean archive -configuration release \-sdk iphoneos -archivePath SmokeTest.xcarchive CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO
xcodebuild -exportArchive -archivePath  SmokeTest.xcarchive \-exportOptionsPlist  SmokeTest/exportOptions.plist \-exportPath  SmokeTest.ipa

zip ${GITHUB_WORKSPACE}/SmokeTest.zip $(find /Users/runner/Library/Developer/Xcode/DerivedData/SplunkRumWorkspace-dzmkiduinguystddyqrorblmaahj/Build/Products/Debug-iphonesimulator/SmokeTest.app -type f)
pwd
