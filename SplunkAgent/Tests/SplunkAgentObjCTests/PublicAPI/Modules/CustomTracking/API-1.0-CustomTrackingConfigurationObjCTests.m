//
/*
Copyright 2026 Splunk Inc.

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


@interface CustomTrackingAPI10ConfigurationObjCTests : XCTestCase

@end


@implementation CustomTrackingAPI10ConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKCustomTrackingConfiguration *defaultConfiguration = [[SPLKCustomTrackingConfiguration alloc] init];

    SPLKCustomTrackingConfiguration *customConfiguration = [[SPLKCustomTrackingConfiguration alloc] initWithEnabled:NO includeBinaryImagesOnErrors:NO];

    XCTAssertNotNil(defaultConfiguration);
    XCTAssertNotNil(customConfiguration);
}

- (void)testProperties {
    SPLKCustomTrackingConfiguration *configuration = [[SPLKCustomTrackingConfiguration alloc] init];

    // Properties (READ)
    BOOL initialIsEnabled = configuration.isEnabled;
    BOOL initialIncludeBinaryImagesOnErrors = configuration.includeBinaryImagesOnErrors;

    // Properties (WRITE)
    configuration.isEnabled = NO;
    configuration.includeBinaryImagesOnErrors = NO;


    XCTAssertEqual(initialIsEnabled, YES);
    XCTAssertEqual(initialIncludeBinaryImagesOnErrors, YES);
    XCTAssertEqual(configuration.isEnabled, NO);
    XCTAssertEqual(configuration.includeBinaryImagesOnErrors, NO);
}

@end
