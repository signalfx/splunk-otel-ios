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

@interface API10UserTrackingModeObjCTests : XCTestCase

@end


@implementation API10UserTrackingModeObjCTests

// MARK: - API Tests

- (void)testModes {
    // Default mode (same as No tracking)
    NSNumber *defaultTrackingMode = SPLKUserTrackingMode.defaultTracking;
    XCTAssertEqual(defaultTrackingMode.integerValue, 0);

    // No tracking
    NSNumber *noTrackingMode = SPLKUserTrackingMode.noTracking;
    XCTAssertEqual(noTrackingMode.integerValue, 0);

    // Anonymous tracking
    NSNumber *anonymousTrackingMode = SPLKUserTrackingMode.anonymousTracking;
    XCTAssertEqual(anonymousTrackingMode.integerValue, 1);
}

@end
