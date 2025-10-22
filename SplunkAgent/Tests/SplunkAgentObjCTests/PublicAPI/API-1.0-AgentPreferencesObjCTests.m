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

@interface API10AgentPreferencesObjCTests : XCTestCase

@end


@implementation API10AgentPreferencesObjCTests

// MARK: - API Tests

- (void)testPreferences {
    NSString *testName = @"agentPreferencesTest";
    
    // Touch `.preferences` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];
    SPLKAgentPreferences *agentPreferences = agent.preferences;
    XCTAssertNotNil(agentPreferences);


    // Properties (READ)
    SPLKEndpointConfiguration *initialEndpoint = agentPreferences.endpointConfiguration;
    XCTAssertNotNil(initialEndpoint);


    // Properties (WRITE)
    SPLKEndpointConfiguration *newEndpoint = [[SPLKEndpointConfiguration alloc] initWithRealm:@"us0" rumAccessToken:@"test-token"];
    agentPreferences.endpointConfiguration = newEndpoint;
    
    // Verify the endpoint was updated (by reading it back)
    SPLKEndpointConfiguration *updatedEndpoint = agentPreferences.endpointConfiguration;
    XCTAssertNotNil(updatedEndpoint);
    XCTAssertEqualObjects(updatedEndpoint.realm, @"us0");


    // Test with custom URLs
    NSURL *traceURL = [NSURL URLWithString:@"https://example.com/v1/traces"];
    NSURL *sessionReplayURL = [NSURL URLWithString:@"https://example.com/v1/logs"];
    SPLKEndpointConfiguration *customEndpoint = [[SPLKEndpointConfiguration alloc] initWithTrace:traceURL sessionReplay:sessionReplayURL];
    agentPreferences.endpointConfiguration = customEndpoint;
    
    SPLKEndpointConfiguration *finalEndpoint = agentPreferences.endpointConfiguration;
    XCTAssertNotNil(finalEndpoint);
    XCTAssertEqualObjects(finalEndpoint.traceEndpoint, traceURL);
}

- (void)testDisableEndpoint {
    NSString *testName = @"agentPreferencesDisableTest";
    
    // Build agent with an endpoint
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];
    SPLKAgentPreferences *agentPreferences = agent.preferences;

    // Verify initial endpoint exists
    XCTAssertNotNil(agentPreferences.endpointConfiguration);

    // Disable the endpoint by setting to nil
    agentPreferences.endpointConfiguration = nil;

    // Note: The getter still returns the original configuration from agentConfiguration
    // but the processors have been replaced with NoOp processors
    // This test verifies that setting nil doesn't crash and executes the disable logic
}

@end

