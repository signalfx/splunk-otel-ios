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


@interface CustomTrackingAPI10ModuleObjCTests : XCTestCase

@end


@implementation CustomTrackingAPI10ModuleObjCTests

// MARK: - API Tests

- (NSDictionary<NSString *, SPLKAttributeValue *> *)sampleAttributes {
    return @{
        @"str": [SPLKAttributeValue attributeWithString :@"value"],
        @"int": [SPLKAttributeValue attributeWithInteger:@1],
        @"dbl": [SPLKAttributeValue attributeWithDouble:2.5],
        @"bol": [SPLKAttributeValue attributeWithBool:@YES]
    };
}

- (void)testTrackCustomEvent {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    XCTAssertNoThrow([agent.customTracking trackCustomEventWithName:@"testEvent"]);
}

- (void)testTrackCustomEvent_withAttributes {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSDictionary<NSString *, SPLKAttributeValue *> *attrs = [self sampleAttributes];
    XCTAssertNoThrow([agent.customTracking trackCustomEventWithName:@"testEvent" attributes:attrs]);
}

- (void)testTrackError_withString {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    XCTAssertNoThrow([agent.customTracking trackErrorMessageWithMessage:@"Test error message"]);
}

- (void)testTrackError_withString_andAttributes {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSDictionary<NSString *, SPLKAttributeValue *> *attrs = [self sampleAttributes];
    XCTAssertNoThrow([agent.customTracking trackErrorMessageWithMessage:@"Test error message" attributes:attrs]);
}

- (void)testTrackError_withNSError {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSError *nsError = [NSError errorWithDomain:@"com.splunk.test" code:1 userInfo:nil];
    XCTAssertNoThrow([agent.customTracking trackErrorWithError:nsError]);
}

- (void)testTrackError_withNSError_andAttributes {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSError *nsError = [NSError errorWithDomain:@"com.splunk.test" code:1 userInfo:nil];
    NSDictionary<NSString *, SPLKAttributeValue *> *attrs = [self sampleAttributes];
    XCTAssertNoThrow([agent.customTracking trackErrorWithError:nsError attributes:attrs]);
}

- (void)testTrackError_withNSException {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSException *exception = [NSException exceptionWithName:NSGenericException reason:@"Test exception" userInfo:nil];
    XCTAssertNoThrow([agent.customTracking trackExceptionWithException:exception]);
}

- (void)testTrackError_withNSException_andAttributes {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    NSException *exception = [NSException exceptionWithName:NSGenericException reason:@"Test exception" userInfo:nil];
    NSDictionary<NSString *, SPLKAttributeValue *> *attrs = [self sampleAttributes];
    XCTAssertNoThrow([agent.customTracking trackExceptionWithException:exception attributes:attrs]);
}

- (void)testTrackWorkflow {
    SPLKAgent *agent = [AgentTestBuilderObjC buildDefault];
    XCTAssertNoThrow([agent.customTracking trackWorkflowWithWorkflowName:@"Test Custom Workflow"]);
}


@end
