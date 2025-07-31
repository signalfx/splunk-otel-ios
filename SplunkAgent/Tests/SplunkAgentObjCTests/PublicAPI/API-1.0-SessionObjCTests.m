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

@interface API10SessionObjCTests : XCTestCase

@end


@implementation API10SessionObjCTests

// MARK: - API Tests

- (void)testSession {
    // Touch `.session` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    SPLKSession *session = agent.session;
    XCTAssertNotNil(session);

    // Properties (READ)
    SPLKSessionState *state = session.state;
    XCTAssertNotNil(state);

    // State properties (READ)
    NSString *currentSessionID = session.state.sessionID;
    XCTAssertNotNil(currentSessionID);

    double currentSamplingRate = session.state.samplingRate;
    XCTAssertEqual(currentSamplingRate, 1.0);
}

@end
