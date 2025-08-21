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

@interface API10UserConfigurationObjCTests : XCTestCase

@end


@implementation API10UserConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKUserConfiguration *minimal = [[SPLKUserConfiguration alloc] init];
    XCTAssertNotNil(minimal);

    NSNumber *trackingMode = SPLKUserTrackingMode.anonymousTracking;
    SPLKUserConfiguration *full = [[SPLKUserConfiguration alloc] initWithTrackingMode:trackingMode];
    XCTAssertNotNil(full);
}

- (void)testBusinessLogic {
    SPLKUserConfiguration *configuration = [[SPLKUserConfiguration alloc] init];

    // Properties (READ)
    NSInteger initialTrackingModeValue = configuration.trackingMode.integerValue;
    NSInteger expectedTrackingModeValue = SPLKUserTrackingMode.noTracking.integerValue;
    XCTAssertEqual(initialTrackingModeValue, expectedTrackingModeValue);

    // Properties (WRITE)
    configuration.trackingMode = SPLKUserTrackingMode.anonymousTracking;
    NSInteger updatedTrackingModeValue = configuration.trackingMode.integerValue;
    XCTAssertEqual(updatedTrackingModeValue, SPLKUserTrackingMode.anonymousTracking.integerValue);
}

- (void)testWrongTrackingModeConstants {
    NSNumber *initialTrackingMode = SPLKUserTrackingMode.anonymousTracking;
    SPLKUserConfiguration *configuration = [[SPLKUserConfiguration alloc] initWithTrackingMode:initialTrackingMode];

    // Using an unsupported constant for the mode will set the default mode
    NSNumber *wrongConstant = @100;
    configuration.trackingMode = wrongConstant;

    NSInteger updatedTrackingModeValue = configuration.trackingMode.integerValue;
    NSInteger expectedTrackingModeValue = SPLKUserTrackingMode.defaultTracking.integerValue;
    XCTAssertEqual(updatedTrackingModeValue, expectedTrackingModeValue);
}

@end
