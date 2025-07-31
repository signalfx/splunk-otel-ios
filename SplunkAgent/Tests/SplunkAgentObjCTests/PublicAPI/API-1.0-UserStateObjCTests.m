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
#import "Builders/AgentTestBuilderObjC.h"

@import SplunkAgentObjC;

@interface API10UserStateObjCTests : XCTestCase

@end


@implementation API10UserStateObjCTests

// MARK: - API Tests

- (void)testState {
    // Touch `.user.state` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    SPLKUserState *userState = agent.user.state;
    XCTAssertNotNil(userState);

    // Properties (READ)
    NSNumber *initialTrackingMode = userState.trackingMode;
    NSInteger initialTrackingModeValue = initialTrackingMode.integerValue;
    NSInteger expectedTrackingModeValue = SPLKUserTrackingMode.noTracking.integerValue;
    XCTAssertEqual(initialTrackingModeValue, expectedTrackingModeValue);

    agent.user.preferences.trackingMode = SPLKUserTrackingMode.anonymousTracking;
    NSInteger currentTrackingModeValue = agent.user.preferences.trackingMode.integerValue;
    XCTAssertEqual(currentTrackingModeValue, SPLKUserTrackingMode.anonymousTracking.integerValue);
}

@end
