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

@import SplunkAgentObjC;

@interface API10RenderingModeObjCTests : XCTestCase

@end


@implementation API10RenderingModeObjCTests

// MARK: - API Tests

- (void)testModes {
    // Default mode (same as Native)
    NSNumber *defaultRenderingMode = SPLKRenderingMode.defaultRenderingMode;
    XCTAssertEqual(defaultRenderingMode.integerValue, 0);

    // Native
    NSNumber *nativeMode = SPLKRenderingMode.native;
    XCTAssertEqual(nativeMode.integerValue, 0);

    // Wireframe Only
    NSNumber *wireframeOnlyMode = SPLKRenderingMode.wireframeOnly;
    XCTAssertEqual(wireframeOnlyMode.integerValue, 1);
}

@end
