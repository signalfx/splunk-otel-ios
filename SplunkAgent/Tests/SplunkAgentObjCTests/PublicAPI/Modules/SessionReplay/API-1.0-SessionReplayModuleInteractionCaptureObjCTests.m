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
#import "../../Builders/AgentTestBuilderObjC.h"

@import SplunkAgentObjC;


@interface SessionReplayModuleInteractionCaptureObjCTests : XCTestCase

@property SPLKAgent *agent;

@end


@implementation SessionReplayModuleInteractionCaptureObjCTests

// MARK: - Private

@synthesize agent;


// MARK: - Tests lifecycle

- (void)setUp {
    [super setUp];

    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:@"sessionReplayInteractionCaptureTest"];
}

- (void)tearDown {
    agent = nil;

    [super tearDown];
}


// MARK: - Categories

- (void)testInitialValues {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    XCTAssertNotNil(capture);
    XCTAssertFalse([capture isKeyboardEnabled]);
    XCTAssertFalse([capture isTouchEnabled]);
    XCTAssertFalse([capture isGestureEnabled]);
    XCTAssertFalse([capture isFocusEnabled]);
    XCTAssertFalse([capture isRageTapEnabled]);
}

- (void)testSetters {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    capture.keyboardEnabled = YES;
    capture.touchEnabled = YES;
    capture.gestureEnabled = YES;
    capture.focusEnabled = YES;
    capture.rageTapEnabled = YES;

    XCTAssertFalse([capture isKeyboardEnabled]);
    XCTAssertFalse([capture isTouchEnabled]);
    XCTAssertFalse([capture isGestureEnabled]);
    XCTAssertFalse([capture isFocusEnabled]);
    XCTAssertFalse([capture isRageTapEnabled]);
}


// MARK: - Bulk updates

- (void)testBulkUpdates {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    [capture enableAll];

    XCTAssertFalse(capture.keyboardEnabled);
    XCTAssertFalse(capture.touchEnabled);
    XCTAssertFalse(capture.gestureEnabled);
    XCTAssertFalse(capture.focusEnabled);
    XCTAssertFalse(capture.rageTapEnabled);

    [capture disableAll];

    XCTAssertFalse(capture.keyboardEnabled);
    XCTAssertFalse(capture.touchEnabled);
    XCTAssertFalse(capture.gestureEnabled);
    XCTAssertFalse(capture.focusEnabled);
    XCTAssertFalse(capture.rageTapEnabled);
}

@end
