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


@interface NetworkAPI10ConfigurationObjCTests : XCTestCase

@end


@implementation NetworkAPI10ConfigurationObjCTests

// MARK: - API Tests

- (void)testInitialization {
    SPLKNetworkInstrumentationConfiguration *defaultConfiguration = [[SPLKNetworkInstrumentationConfiguration alloc] initWithEnabled:NO ignoreURLs:[[NSRegularExpression alloc] initWithPattern:@"a" options:0 error:nil]];

    SPLKNetworkInstrumentationConfiguration *minimalConfiguration = [[SPLKNetworkInstrumentationConfiguration alloc] initWithEnabled:NO];

    XCTAssertNotNil(defaultConfiguration);
    XCTAssertNotNil(minimalConfiguration);
}

- (void)testProperties {
    SPLKNetworkInstrumentationConfiguration *configuration = [[SPLKNetworkInstrumentationConfiguration alloc] init];

    // Properties (READ)
    BOOL initialIsEnabled = configuration.isEnabled;
    NSRegularExpression* initialIgnoreUrls = configuration.ignoreURLs;

    // Properties (WRITE)
    configuration.isEnabled = NO;
    configuration.ignoreURLs = [[NSRegularExpression alloc] initWithPattern:@"a" options:0 error:nil];
    
    XCTAssertEqual(initialIsEnabled, YES);
    XCTAssertNil(initialIgnoreUrls);
    XCTAssertEqual(configuration.isEnabled, NO);
    XCTAssertNotNil(configuration.ignoreURLs);
    XCTAssertTrue([configuration.ignoreURLs isEqual:[[NSRegularExpression alloc] initWithPattern:@"a" options:0 error:nil]]);
}

@end
