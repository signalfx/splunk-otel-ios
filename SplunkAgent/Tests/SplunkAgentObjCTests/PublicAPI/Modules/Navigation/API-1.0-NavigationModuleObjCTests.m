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
#import "../../Builders/AgentTestBuilderObjC.h"

@import SplunkAgentObjC;
@import SplunkNavigation;


@interface NavigationAPI10ModuleObjCTests : XCTestCase

@end


@implementation NavigationAPI10ModuleObjCTests

- (void)testPreferences {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];

    SPLKNavigationModulePreferences *preferences = [[SPLKNavigationModulePreferences alloc] initWithEnableAutomatedTracking:NO];
    agent.navigation.preferences = preferences;
    XCTAssertFalse(agent.navigation.preferences.enableAutomatedTracking);
}

- (void)testState {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    SPLKNavigationModuleState *state = agent.navigation.state;
    XCTAssertNotNil(state);
    XCTAssertFalse(state.isAutomatedTrackingEnabled);
    XCTAssertNil(state.currentScreenName);
}

- (void)testTracking {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    XCTAssertNoThrow([agent.navigation trackScreen:@"Test"]);
    XCTAssertNoThrow([agent.navigation trackScreen:@"Test" attributes:@{
        @"source": @"manual",
        @"screen_id": @1
    }]);
}

- (void)testNavigationEventProcessor {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    SPLKDefaultNavigationEventProcessor *processor = [[SPLKDefaultNavigationEventProcessor alloc] init];
    agent.navigation.navigationEventProcessor = processor;

    XCTAssertNotNil(agent.navigation.navigationEventProcessor);
}

@end
