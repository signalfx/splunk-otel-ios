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

@interface API10StateObjCTests : XCTestCase

@end


@implementation API10StateObjCTests

// MARK: - API Tests

- (void)testState {
    NSString *testName = @"stateTest";
    
    // Touch `.state` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];
    SPLKState *state = agent.state;
    XCTAssertNotNil(state);

    // Properties - Agent status (READ)
    XCTAssertNotNil(state.status);

    // Properties - User Configuration (READ)
    XCTAssertNotNil(state.appName);
    XCTAssertNotNil(state.appVersion);
    XCTAssertNotNil(state.deploymentEnvironment);
    XCTAssertFalse(state.isDebugLoggingEnabled);
}

@end
