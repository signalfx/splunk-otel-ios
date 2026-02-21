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
    NSString *testName = @"sessionTest";
    
    // Touch `.session` property
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];
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


// MARK: - Session Change Notification API

- (void)testSessionIdDidChangeNotificationName {
    NSNotificationName name = SPLKSession.sessionIdDidChangeNotification;
    XCTAssertNotNil(name);
    XCTAssertTrue(name.length > 0);
}

- (void)testSessionIdUserInfoKey {
    NSString *key = SPLKSession.sessionIdUserInfoKey;
    XCTAssertNotNil(key);
    XCTAssertEqualObjects(key, @"sessionId");
}

- (void)testPreviousSessionIdUserInfoKey {
    NSString *key = SPLKSession.previousSessionIdUserInfoKey;
    XCTAssertNotNil(key);
    XCTAssertEqualObjects(key, @"previousSessionId");
}

- (void)testSessionIdDidChangeNotificationIsObservable {
    XCTestExpectation *expectation = [self expectationForNotification:SPLKSession.sessionIdDidChangeNotification
                                                              object:nil
                                                             handler:nil];

    NSDictionary *userInfo = @{
        SPLKSession.sessionIdUserInfoKey: @"test-new-id",
        SPLKSession.previousSessionIdUserInfoKey: @"test-old-id"
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:SPLKSession.sessionIdDidChangeNotification
                                                        object:nil
                                                      userInfo:userInfo];

    [self waitForExpectations:@[expectation] timeout:3];
}

- (void)testSessionIdDidChangeNotificationUserInfoKeys {
    __block NSString *capturedNewId = nil;
    __block NSString *capturedPreviousId = nil;

    XCTestExpectation *expectation = [self expectationForNotification:SPLKSession.sessionIdDidChangeNotification
                                                              object:nil
                                                             handler:^BOOL(NSNotification *notification) {
        capturedNewId = notification.userInfo[SPLKSession.sessionIdUserInfoKey];
        capturedPreviousId = notification.userInfo[SPLKSession.previousSessionIdUserInfoKey];
        return YES;
    }];

    NSDictionary *userInfo = @{
        SPLKSession.sessionIdUserInfoKey: @"abc123",
        SPLKSession.previousSessionIdUserInfoKey: @"xyz789"
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:SPLKSession.sessionIdDidChangeNotification
                                                        object:nil
                                                      userInfo:userInfo];

    [self waitForExpectations:@[expectation] timeout:3];

    XCTAssertEqualObjects(capturedNewId, @"abc123");
    XCTAssertEqualObjects(capturedPreviousId, @"xyz789");
}

@end
