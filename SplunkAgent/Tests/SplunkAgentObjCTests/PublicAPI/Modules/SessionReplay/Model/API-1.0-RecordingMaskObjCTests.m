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
#import "../../../Builders/AgentTestBuilderObjC.h"

@import SplunkAgentObjC;


@interface API10RecordingMaskObjCTests : XCTestCase

@end


@implementation API10RecordingMaskObjCTests

// MARK: - API Tests

- (void)testRecordingMaskModel {
    CGRect coveringRect = CGRectMake(30, 30, 120, 120);
    CGRect erasingRect = CGRectMake(50, 50, 60, 20);


    /* Mask Type */
    SPLKMaskElementType coveringMask = SPLKMaskElementTypeCovering;
    SPLKMaskElementType erasingMask = SPLKMaskElementTypeErasing;

    /* Mask Element */
    SPLKMaskElement *coveringElement = [[SPLKMaskElement alloc] initWithRect:coveringRect maskElementType:coveringMask];

    SPLKMaskElement *erasingElement = [[SPLKMaskElement alloc] initWithRect:erasingRect maskElementType:erasingMask];

    /* Recording Mask */
    SPLKRecordingMask *recordingMask = [[SPLKRecordingMask alloc] initWithElements:@[coveringElement, erasingElement]];


    XCTAssertNotNil(coveringElement);
    XCTAssertNotNil(erasingElement);

    XCTAssertTrue(CGRectEqualToRect(coveringElement.rect, coveringRect));
    XCTAssertEqual(coveringElement.type, SPLKMaskElementTypeCovering);
    XCTAssertEqual(erasingElement.type, SPLKMaskElementTypeErasing);

    XCTAssertNotNil(recordingMask);
    XCTAssertNotNil(recordingMask.elements);
    XCTAssertEqual(recordingMask.elements.count, 2);
}

- (void)testRecordingMask {
    NSString *testName = @"sessionReplayRecordingMaskTest";
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefaultForTestNamed:testName];

    // We need to give the agent some time to load the modules in the background
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        CGRect coveringRect = CGRectMake(50, 60, 200, 500);
        SPLKMaskElement *coveringElement = [[SPLKMaskElement alloc] initWithRect:coveringRect maskElementType:SPLKMaskElementTypeCovering];
        
        SPLKRecordingMask *recordingMask = [[SPLKRecordingMask alloc] initWithElements:@[coveringElement]];
        
        
        // Set recording mask
        [agent.sessionReplay setRecordingMask:recordingMask];
        SPLKRecordingMask *readRecordingMask = agent.sessionReplay.recordingMask;
        
        XCTAssertNotNil(readRecordingMask);
        XCTAssertNotNil(readRecordingMask.elements);
        XCTAssertEqual(readRecordingMask.elements.count, 1);
        
        
        // Clear recording mask
        [agent.sessionReplay setRecordingMask:nil];
        SPLKRecordingMask *nilRecordingMask = agent.sessionReplay.recordingMask;
        SPLKMaskElement *readElement = recordingMask.elements.firstObject;
        
        XCTAssertNotNil(readElement);
        XCTAssertTrue(CGRectEqualToRect(readElement.rect, coveringRect));
        XCTAssertEqual(readElement.type, SPLKMaskElementTypeCovering);
        
        XCTAssertNil(nilRecordingMask);
    });
}

@end
