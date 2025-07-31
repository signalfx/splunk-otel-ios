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

@interface API10UserPreferencesObjCTests : XCTestCase

@end


@implementation API10UserPreferencesObjCTests

// MARK: - API Tests

- (void)testPreferences {
    // Touch `.user.preferences` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    SPLKUserPreferences *userPreferences = agent.user.preferences;
    XCTAssertNotNil(userPreferences);


    // Properties (READ)
    NSInteger initialTrackingModeValue = userPreferences.trackingMode.integerValue;
    NSInteger expectedTrackingModeValue = SPLKUserTrackingMode.noTracking.integerValue;
    XCTAssertEqual(initialTrackingModeValue, expectedTrackingModeValue);


    // Properties (WRITE)
    NSNumber *defaultTrackingMode = SPLKUserTrackingMode.defaultTracking;
    userPreferences.trackingMode = defaultTrackingMode;
    XCTAssertEqual(userPreferences.trackingMode.integerValue, defaultTrackingMode.integerValue);

    NSNumber *anonymousTrackingMode = SPLKUserTrackingMode.anonymousTracking;
    userPreferences.trackingMode = anonymousTrackingMode;
    XCTAssertEqual(userPreferences.trackingMode.integerValue, anonymousTrackingMode.integerValue);

    NSNumber *noTrackingMode = SPLKUserTrackingMode.noTracking;
    userPreferences.trackingMode = noTrackingMode;
    XCTAssertEqual(userPreferences.trackingMode.integerValue, noTrackingMode.integerValue);
}

@end
