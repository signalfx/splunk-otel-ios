//
/*
Copyright 2025 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#import <XCTest/XCTest.h>

@import SplunkAgentObjC;

@interface API10SessionReplayStatusObjCTests : XCTestCase

@end


@implementation API10SessionReplayStatusObjCTests

// MARK: - API Tests

- (void)testStatusValues {
    // Recording
    NSNumber *recordingStatus = SPLKSessionReplayStatus.recording;
    XCTAssertEqual(recordingStatus.integerValue, 1);

    // Not recording (Not started)
    NSNumber *notStartedStatus = SPLKSessionReplayStatus.notRecordingNotStarted;
    XCTAssertEqual(notStartedStatus.integerValue, -100);

    // Not recording (Unsupported platform)
    NSNumber *unsupportedPlatformStatus = SPLKSessionReplayStatus.notRecordingUnsupportedPlatform;
    XCTAssertEqual(unsupportedPlatformStatus.integerValue, -101);

    // Not recording (SwiftUI Preview context)
    NSNumber *swiftUIPreviewStatus = SPLKSessionReplayStatus.notRecordingSwiftUIPreviewContext;
    XCTAssertEqual(swiftUIPreviewStatus.integerValue, -102);

    // Not recording (Stopped)
    NSNumber *stoppedStatus = SPLKSessionReplayStatus.notRecordingStopped;
    XCTAssertEqual(stoppedStatus.integerValue, -110);

    // Not recording (Internal error)
    NSNumber *internalErrorStatus = SPLKSessionReplayStatus.notRecordingInternalError;
    XCTAssertEqual(internalErrorStatus.integerValue, -200);

    // Not recording (Storage limit reached)
    NSNumber *storageLimitReachedStatus = SPLKSessionReplayStatus.notRecordingStorageLimitReached;
    XCTAssertEqual(storageLimitReachedStatus.integerValue, -201);
}

@end
