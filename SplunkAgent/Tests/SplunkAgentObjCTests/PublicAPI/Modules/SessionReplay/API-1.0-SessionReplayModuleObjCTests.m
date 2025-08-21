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


@interface SessionReplayAPI10ModuleObjCTests : XCTestCase

@property SPLKAgent *agent;

@end


@implementation SessionReplayAPI10ModuleObjCTests

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

- (void)testProperties {
    NSString *testName = @"sessionReplyPropertiesTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    // Touch module properties
    SPLKSessionReplayModuleSensitivity *sensitivity = agent.sessionReplay.sensitivity;
    SPLKSessionReplayModuleCustomID *customIdentifiers = agent.sessionReplay.customIdentifiers;
    SPLKSessionReplayModuleState *state = agent.sessionReplay.state;
    SPLKSessionReplayModulePreferences *preferences = agent.sessionReplay.preferences;

    // Touch recording mask
    SPLKRecordingMask *recordingMask = agent.sessionReplay.recordingMask;


    XCTAssertNotNil(sensitivity);
    XCTAssertNotNil(customIdentifiers);
    XCTAssertNotNil(state);
    XCTAssertNotNil(preferences);

    // Default recording mask should be `nil`
    XCTAssertNil(recordingMask);
}

- (void)testRecordingMethods {
    NSString *testName = @"sessionReplyRecordingMethodsTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    // Start/Stop
    [agent.sessionReplay start];
    [agent.sessionReplay stop];
}


// MARK: - Custom ID

- (void)testCustomIdentifiers {
    NSString *testName = @"sessionReplyCustomIdentifiersTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    UIView *someView = [[UIView alloc] init];
    NSString *customIdentifier = @"Test";

    SPLKSessionReplayModuleCustomID *customIdentifiers = agent.sessionReplay.customIdentifiers;

    // Touch READ/WRITE methods
    NSString *defaultIdentifier = [customIdentifiers customIDForView:someView];

    [customIdentifiers setCustomID:customIdentifier forView:someView];
    NSString *readIdentifier = [customIdentifiers customIDForView:someView];

    // Methods should accepts `nil`
    [customIdentifiers setCustomID:nil forView:someView];
    NSString *nilIdentifier = [customIdentifiers customIDForView:someView];

    XCTAssertNil(defaultIdentifier);
    XCTAssertNil(nilIdentifier);
}


// MARK: - Sensitivity

- (void)testSensitivity {
    NSString *testName = @"sessionReplySensitivityTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    CGRect labelViewRect = CGRectMake(0, 0, 100, 50);
    UILabel *labelView = [[UILabel alloc] initWithFrame:labelViewRect];

    SPLKSessionReplayModuleSensitivity *sensitivity = agent.sessionReplay.sensitivity;

    // Touch READ/WRITE methods
    NSNumber *defaultViewSensitivity = [sensitivity sensitivityForView:labelView];
    NSNumber *defaultClassSensitivity = [sensitivity sensitivityForViewClass:[labelView class]];

    [sensitivity setSensitivity:@YES forView:labelView];
    NSNumber *readViewSensitivity = [sensitivity sensitivityForView:labelView];
    BOOL readViewSensitivityValue = readViewSensitivity.boolValue;

    [sensitivity setSensitivity:@NO forViewClass:[labelView class]];
    NSNumber *readClassSensitivity = [sensitivity sensitivityForViewClass:[labelView class]];
    BOOL readClassSensitivityValue = readClassSensitivity.boolValue;

    // Methods should accepts `nil`
    [sensitivity setSensitivity:nil forView:labelView];
    NSNumber *nilViewSensitivity = [sensitivity sensitivityForView:labelView];

    [sensitivity setSensitivity:nil forViewClass:[labelView class]];
    NSNumber *nilClassSensitivity = [sensitivity sensitivityForViewClass:[labelView class]];

    XCTAssertNil(defaultViewSensitivity);
    XCTAssertNil(defaultClassSensitivity);
}


// MARK: - State

- (void)testState {
    NSString *testName = @"sessionReplyStateTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    SPLKSessionReplayModuleState *state = agent.sessionReplay.state;

    // Touch individual properties
    NSNumber *status = state.status;
    BOOL isRecording = state.isRecording;
    NSNumber *renderingMode = state.renderingMode;


    // The module remains stopped, and the rendering mode
    // is now set to the default `.native` mode
    XCTAssertNotNil(status);
    XCTAssertEqual(status.integerValue, SPLKSessionReplayStatus.notRecordingNotStarted.integerValue);

    XCTAssertEqual(isRecording, NO);

    XCTAssertNotNil(renderingMode);
    XCTAssertEqual(renderingMode.integerValue, SPLKRenderingMode.native.integerValue);
}


// MARK: - Preferences

- (void)testPreferences {
    NSString *testName = @"sessionReplyPreferencesTest";
    agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    SPLKSessionReplayModulePreferences *preferences = agent.sessionReplay.preferences;

    // Touch individual properties
    NSNumber *renderingMode = agent.sessionReplay.preferences.renderingMode;

    // Update individual properties
    agent.sessionReplay.preferences.renderingMode = SPLKRenderingMode.wireframeOnly;
    NSNumber *updatedRenderingMode = agent.sessionReplay.preferences.renderingMode;

    // Property renderingMode should accepts `nil`
    agent.sessionReplay.preferences.renderingMode = nil;


    // Default mode should be `nil` (no exact preference)
    XCTAssertNil(renderingMode);
}


@end
