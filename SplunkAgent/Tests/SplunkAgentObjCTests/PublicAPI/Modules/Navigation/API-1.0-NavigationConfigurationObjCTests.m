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


@interface NavigationAPI10ConfigurationObjCTests : XCTestCase

@end


@implementation NavigationAPI10ConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKNavigationConfiguration *defaultConfiguration = [[SPLKNavigationConfiguration alloc] init];

    SPLKNavigationConfiguration *minimalConfiguration = [[SPLKNavigationConfiguration alloc] initWithEnabled:NO];

    SPLKNavigationConfiguration *fullConfiguration = [[SPLKNavigationConfiguration alloc] initWithEnabled:NO automatedTracking:NO];

    SPLKDefaultNavigationEventProcessor *processor = [[SPLKDefaultNavigationEventProcessor alloc] init];
    SPLKNavigationConfiguration *fullWithProcessor = [[SPLKNavigationConfiguration alloc] initWithEnabled:YES automatedTracking:YES navigationEventProcessor:processor];

    XCTAssertNotNil(defaultConfiguration);
    XCTAssertNotNil(minimalConfiguration);
    XCTAssertNotNil(fullConfiguration);
    XCTAssertNotNil(fullWithProcessor);
}

- (void)testDefaultValues {
    SPLKNavigationConfiguration *configuration = [[SPLKNavigationConfiguration alloc] init];

    XCTAssertTrue(configuration.isEnabled);
    XCTAssertFalse(configuration.enableAutomatedTracking);
    XCTAssertNil(configuration.navigationEventProcessor);
}

- (void)testProperties {
    SPLKNavigationConfiguration *configuration = [[SPLKNavigationConfiguration alloc] init];

    // Properties (READ)
    BOOL initialIsEnabled = configuration.isEnabled;
    BOOL initialEnableAutomatedTracking = configuration.enableAutomatedTracking;

    // Properties (WRITE)
    configuration.isEnabled = NO;
    configuration.enableAutomatedTracking = YES;


    XCTAssertEqual(initialIsEnabled, YES);
    XCTAssertEqual(initialEnableAutomatedTracking, NO);

    XCTAssertEqual(configuration.isEnabled, NO);
    XCTAssertEqual(configuration.enableAutomatedTracking, YES);
}

- (void)testNavigationEventProcessorProperty {
    SPLKNavigationConfiguration *configuration = [[SPLKNavigationConfiguration alloc] init];

    // Default is nil
    XCTAssertNil(configuration.navigationEventProcessor);

    // Assign a processor
    SPLKDefaultNavigationEventProcessor *processor = [[SPLKDefaultNavigationEventProcessor alloc] init];
    configuration.navigationEventProcessor = processor;
    XCTAssertNotNil(configuration.navigationEventProcessor);

    // Clear the processor
    configuration.navigationEventProcessor = nil;
    XCTAssertNil(configuration.navigationEventProcessor);
}

@end
