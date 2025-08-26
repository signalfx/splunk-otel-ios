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


@interface InteractionsAPI10ConfigurationObjCTests : XCTestCase

@end


@implementation InteractionsAPI10ConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKInteractionsConfiguration *defaultConfiguration = [[SPLKInteractionsConfiguration alloc] init];

    SPLKInteractionsConfiguration *minimalConfiguration = [[SPLKInteractionsConfiguration alloc] initWithEnabled:NO];

    XCTAssertNotNil(defaultConfiguration);
    XCTAssertNotNil(minimalConfiguration);
}

- (void)testProperties {
    SPLKInteractionsConfiguration *configuration = [[SPLKInteractionsConfiguration alloc] init];

    // Properties (READ)
    BOOL initialIsEnabled = configuration.isEnabled;

    // Properties (WRITE)
    configuration.isEnabled = NO;


    XCTAssertEqual(initialIsEnabled, YES);
    XCTAssertEqual(configuration.isEnabled, NO);
}

@end
