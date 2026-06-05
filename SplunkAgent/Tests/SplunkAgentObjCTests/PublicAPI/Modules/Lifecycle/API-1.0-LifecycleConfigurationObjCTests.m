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


@interface LifecycleAPI10ConfigurationObjCTests : XCTestCase

@end


@implementation LifecycleAPI10ConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKLifecycleConfiguration *defaultConfiguration = [[SPLKLifecycleConfiguration alloc] init];

    SPLKLifecycleConfiguration *minimalConfiguration = [[SPLKLifecycleConfiguration alloc] initWithEnabled:NO];

    SPLKLifecycleConfiguration *eventsConfiguration = [[SPLKLifecycleConfiguration alloc] initWithAllowedEvents:@[SPLKLifecycleAction.viewCreated]];

    SPLKLifecycleConfiguration *fullConfiguration = [[SPLKLifecycleConfiguration alloc] initWithEnabled:YES allowedEvents:@[SPLKLifecycleAction.viewCreated]];

    XCTAssertNotNil(defaultConfiguration);
    XCTAssertNotNil(minimalConfiguration);
    XCTAssertNotNil(eventsConfiguration);
    XCTAssertNotNil(fullConfiguration);
}

- (void)testDefaultValues {
    SPLKLifecycleConfiguration *configuration = [[SPLKLifecycleConfiguration alloc] init];

    NSArray<NSString *> *expectedEvents = @[SPLKLifecycleAction.viewCreated, SPLKLifecycleAction.resumed, SPLKLifecycleAction.stopped];

    XCTAssertTrue(configuration.isEnabled);
    XCTAssertEqualObjects(configuration.allowedEvents, expectedEvents);
}

- (void)testProperties {
    SPLKLifecycleConfiguration *configuration = [[SPLKLifecycleConfiguration alloc] init];

    BOOL initialIsEnabled = configuration.isEnabled;
    NSArray<NSString *> *initialAllowedEvents = configuration.allowedEvents;

    configuration.isEnabled = NO;
    configuration.allowedEvents = @[SPLKLifecycleAction.viewCreated];


    XCTAssertEqual(initialIsEnabled, YES);
    XCTAssertEqualObjects(initialAllowedEvents, (@[SPLKLifecycleAction.viewCreated, SPLKLifecycleAction.resumed, SPLKLifecycleAction.stopped]));

    XCTAssertEqual(configuration.isEnabled, NO);
    XCTAssertEqualObjects(configuration.allowedEvents, (@[SPLKLifecycleAction.viewCreated]));
}

- (void)testLifecycleActionConstants {
    XCTAssertEqualObjects(SPLKLifecycleAction.viewCreated, @"view_created");
    XCTAssertEqualObjects(SPLKLifecycleAction.resumed, @"resumed");
    XCTAssertEqualObjects(SPLKLifecycleAction.stopped, @"stopped");
}

@end
