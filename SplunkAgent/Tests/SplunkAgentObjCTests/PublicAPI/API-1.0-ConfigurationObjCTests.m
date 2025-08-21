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
#import "Builders/ConfigurationTestBuilderObjC.h"

@import SplunkAgentObjC;


@interface API10ConfigurationObjCTests : XCTestCase

@end


@implementation API10ConfigurationObjCTests

// MARK: - API Tests

- (void)testRealmConfiguration {
    // Default initialization
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildDefault];

    NSURL *traceURL = configuration.endpoint.traceEndpoint;
    XCTAssertNotNil(traceURL);


    // Trace URL
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:traceURL resolvingAgainstBaseURL:NO];
    NSString *realm = [ConfigurationTestBuilderObjC realm];
    NSString *expectedHost = [NSString stringWithFormat:@"rum-ingest.%@.signalfx.com", realm];

    XCTAssertTrue([urlComponents.scheme isEqualToString:@"https"]);
    XCTAssertTrue([urlComponents.host isEqualToString:expectedHost]);
    XCTAssertTrue([urlComponents.path isEqualToString:@"/v1/rumotlp"]);


    // Authentication
    NSArray<NSURLQueryItem *> * queryItems = urlComponents.queryItems;
    NSURLQueryItem *authQuery = queryItems.firstObject;
    NSString *expectedRumAccessToken = [ConfigurationTestBuilderObjC rumAccessToken];

    XCTAssertTrue([authQuery.name isEqualToString:@"auth"]);
    XCTAssertTrue([authQuery.value isEqualToString:expectedRumAccessToken]);
}

- (void)testCustomUrlConfiguration {
    // Custom urls initialization
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildWithCustomURLs];

    NSString *traceURL = configuration.endpoint.traceEndpoint.absoluteString;
    NSString *expectedTraceURL = [[ConfigurationTestBuilderObjC customTraceURL] absoluteString];

    NSString *sessionReplayURL = configuration.endpoint.sessionReplayEndpoint.absoluteString;
    NSString *exceptedSessionReplayURL = [[ConfigurationTestBuilderObjC customSessionReplayURL] absoluteString];

    XCTAssertTrue([traceURL isEqualToString:expectedTraceURL]);
    XCTAssertTrue([sessionReplayURL isEqualToString:exceptedSessionReplayURL]);
}

- (void)testConfigurationReadProperties {
    // Default initialization
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildDefault];

    // Properties (READ)
    NSString *expectedRealm = [ConfigurationTestBuilderObjC realm];
    NSString *expectedRumAccessToken = [ConfigurationTestBuilderObjC rumAccessToken];

    XCTAssertTrue([configuration.endpoint.realm isEqualToString:expectedRealm]);
    XCTAssertTrue([configuration.endpoint.rumAccessToken isEqualToString:expectedRumAccessToken]);
    XCTAssertNotNil(configuration.endpoint.traceEndpoint);
    XCTAssertNotNil(configuration.endpoint.sessionReplayEndpoint);


    NSString *expectedDeploymentEnvironment = [ConfigurationTestBuilderObjC deploymentEnvironment];
    NSString *expectedAppName = [ConfigurationTestBuilderObjC appName];

    XCTAssertTrue([configuration.deploymentEnvironment isEqualToString:expectedDeploymentEnvironment]);
    XCTAssertTrue([configuration.appName isEqualToString:expectedAppName]);


    NSString *expectedAppVersion = [ConfigurationTestBuilderObjC appVersion];
    BOOL expectedEnableDebugLogging = NO;

    XCTAssertTrue([configuration.appVersion isEqualToString:expectedAppVersion]);
    XCTAssertEqual(configuration.enableDebugLogging, expectedEnableDebugLogging);
    XCTAssertNotNil(configuration.globalAttributes);


    double expectedSampligRate = 1.0;
    NSInteger expectedUserTrackingModeValue = SPLKUserTrackingMode.noTracking.integerValue;

    XCTAssertEqual(configuration.session.samplingRate, expectedSampligRate);
    XCTAssertNotNil(configuration.user.trackingMode);
    XCTAssertEqual(configuration.user.trackingMode.integerValue, expectedUserTrackingModeValue);
}

- (void)testConfigurationWriteProperties {
    // Default initialization
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildDefault];

    // Properties (WRITE)
    configuration.appVersion = @"0.1";
    XCTAssertTrue([configuration.appVersion isEqualToString:@"0.1"]);

    configuration.enableDebugLogging = YES;
    XCTAssertEqual(configuration.enableDebugLogging, YES);


    // Session configuration
    configuration.session.samplingRate = 0.7;
    XCTAssertEqual(configuration.session.samplingRate, 0.7);

    SPLKSessionConfiguration *sessionConfiguration = [[SPLKSessionConfiguration alloc] init];
    sessionConfiguration.samplingRate = 0.5;

    configuration.session = sessionConfiguration;
    XCTAssertEqual(configuration.session.samplingRate, 0.5);


    // User configuration
    configuration.user.trackingMode = SPLKUserTrackingMode.anonymousTracking;
    NSInteger expectedUserTrackingModeValue = SPLKUserTrackingMode.anonymousTracking.integerValue;
    XCTAssertEqual(configuration.user.trackingMode.integerValue, expectedUserTrackingModeValue);

    SPLKUserConfiguration *userConfiguration = [[SPLKUserConfiguration alloc]
        initWithTrackingMode:SPLKUserTrackingMode.noTracking];

    configuration.user = userConfiguration;
    expectedUserTrackingModeValue = SPLKUserTrackingMode.noTracking.integerValue;
    XCTAssertEqual(configuration.user.trackingMode.integerValue, expectedUserTrackingModeValue);

    NSString *attributeKey = @"key_one";
    NSString *attributeValue = @"value_one";

    NSMutableDictionary<NSString *, SPLKAttributeValue *> *testAttributes = [[NSMutableDictionary alloc] init];
    SPLKAttributeValue *stringAttribute = [SPLKAttributeValue attributeWithInteger:attributeValue];
    [testAttributes setObject:stringAttribute forKey:attributeKey];

    configuration.globalAttributes = testAttributes;
    XCTAssertTrue([configuration.globalAttributes isEqualToDictionary:testAttributes]);
}

- (void)testGlobalAttributes {
    // Default initialization
    SPLKAgentConfiguration *configuration = [ConfigurationTestBuilderObjC buildDefault];

    SPLKAttributeValue *integerAttribute = [SPLKAttributeValue attributeWithInteger:-1];
    SPLKAttributeValue *stringAttribute = [SPLKAttributeValue attributeWithString:@"Test"];

    // Add some supported values as attributes
    NSMutableDictionary<NSString *, SPLKAttributeValue *> *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"integer"] = integerAttribute;
    attributes[@"string"] = stringAttribute;
    configuration.globalAttributes = attributes;

    NSDictionary<NSString *, SPLKAttributeValue *> *readedAttributes = configuration.globalAttributes;
    XCTAssertTrue([attributes isEqualToDictionary:readedAttributes]);
}

@end
