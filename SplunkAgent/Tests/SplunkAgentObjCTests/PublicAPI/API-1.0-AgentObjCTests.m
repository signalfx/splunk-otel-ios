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
#import "Builders/ConfigurationTestBuilderObjC.h"

@import SplunkAgentObjC;


@interface API10AgentObjCTests : XCTestCase

@property SPLKAgent *agent;

@end


@implementation API10AgentObjCTests

// MARK: - Private

@synthesize agent;


// MARK: - Tests lifecycle

- (void)setUp {
    [super setUp];
    
    agent = nil;
}

- (void)tearDown {
    agent = nil;

    [super tearDown];
}


// MARK: - API Tests

- (void)testInitialStatus {
    // Test initial state
    NSInteger supportedInitialStatus = SPLKStatus.notRunningNotInstalled.integerValue;
    NSInteger unsupportedInitialStatus = SPLKStatus.notRunningUnsupportedPlatform.integerValue;

    XCTAssertTrue(([SPLKAgent shared].state.status.integerValue == supportedInitialStatus) ||
                  ([SPLKAgent shared].state.status.integerValue == unsupportedInitialStatus));
}

- (void)testInstall {
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildDefault];

    // Agent install
    NSError *error;
    agent = [SPLKAgent installWith:configuration error:&error];


    // The agent should be initialized without errors
    XCTAssertNil(error);
    XCTAssertNotNil(agent);

    // The agent should run after install
    NSInteger supportedRunStatus = SPLKStatus.running.integerValue;
    NSInteger unsupportedRunStatus = SPLKStatus.notRunningUnsupportedPlatform.integerValue;
    
    XCTAssertTrue(([SPLKAgent shared].state.status.integerValue == supportedRunStatus) ||
                  ([SPLKAgent shared].state.status.integerValue == unsupportedRunStatus));

}

- (void)testProperties {
    agent = [AgentTestBuilderObjC buildDefault];

    // Touch main agent properties
    SPLKState *state = agent.state;
    SPLKSession *session = agent.session;
    SPLKUser *user = agent.user;

    // Touch global attributes
    NSMutableDictionary *globalAttributes = agent.globalAttributes;

    // Touch the root properties for the modules API
    SPLKCustomTrackingModule *customTracking = agent.customTracking;
    SPLKNavigationModule *navigation = agent.navigation;
    SPLKSessionReplayModule *sessionReplay = agent.sessionReplay;
    SPLKSlowFrameDetectorModule *slowFrameDetector = agent.slowFrameDetector;
    SPLKWebViewInstrumentationModule *webViewNativeBridge = agent.webViewNativeBridge;

    // Touch agent version
    NSString *agentVersion = [SPLKAgent agentVersion];


    XCTAssertNotNil(state);
    XCTAssertNotNil(session);
    XCTAssertNotNil(user);

    XCTAssertNotNil(globalAttributes);

    XCTAssertNotNil(customTracking);
    XCTAssertNotNil(navigation);
    XCTAssertNotNil(sessionReplay);
    XCTAssertNotNil(slowFrameDetector);
    XCTAssertNotNil(webViewNativeBridge);

    XCTAssertNotNil(agentVersion);
}

@end
