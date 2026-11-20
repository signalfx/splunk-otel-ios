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

    agent = [AgentTestBuilderObjC
        buildWithOperationalSessionReplayForTestNamed:@"sessionReplayInteractionCaptureTest"];
}

- (void)tearDown {
    [agent.sessionReplay.preferences.interactionCapture enableAll];
    agent = nil;

    [super tearDown];
}


// MARK: - Categories

- (void)testInitialValues {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    XCTAssertNotNil(capture);
    XCTAssertTrue([capture isKeyboardEnabled]);
    XCTAssertTrue([capture isTouchEnabled]);
    XCTAssertTrue([capture isGestureEnabled]);
    XCTAssertTrue([capture isFocusEnabled]);
    XCTAssertTrue([capture isRageTapEnabled]);
}

- (void)testSetters {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    capture.keyboardEnabled = NO;
    XCTAssertFalse([capture isKeyboardEnabled]);

    capture.touchEnabled = NO;
    XCTAssertFalse([capture isTouchEnabled]);

    capture.gestureEnabled = NO;
    XCTAssertFalse([capture isGestureEnabled]);

    capture.focusEnabled = NO;
    XCTAssertFalse([capture isFocusEnabled]);

    capture.rageTapEnabled = NO;
    XCTAssertFalse([capture isRageTapEnabled]);
}


// MARK: - Bulk updates

- (void)testBulkUpdates {
    SPLKSessionReplayModuleInteractionCapture *capture = agent.sessionReplay.preferences.interactionCapture;

    [capture disableAll];

    XCTAssertFalse(capture.keyboardEnabled);
    XCTAssertFalse(capture.touchEnabled);
    XCTAssertFalse(capture.gestureEnabled);
    XCTAssertFalse(capture.focusEnabled);
    XCTAssertFalse(capture.rageTapEnabled);

    [capture enableAll];

    XCTAssertTrue(capture.keyboardEnabled);
    XCTAssertTrue(capture.touchEnabled);
    XCTAssertTrue(capture.gestureEnabled);
    XCTAssertTrue(capture.focusEnabled);
    XCTAssertTrue(capture.rageTapEnabled);
}

@end
