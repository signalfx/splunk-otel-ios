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

#import "ConfigurationTestBuilderObjC.h"


@implementation ConfigurationTestBuilderObjC

// MARK: - Static constants

+ (NSURL *)customTraceURL {
    return [[NSURL alloc] initWithString:@"http://sampledomain.com/tenant/traces"];
}

+ (NSURL *)customSessionReplayURL {
    return [[NSURL alloc] initWithString:@"http://sampledomain.com/tenant/sessionreplay"];
}


+ (NSString *)realm {
    return @"dev";
}

+ (NSString *)deploymentEnvironment {
    return @"testenv";
}

+ (NSString *)appName {
    return @"Tests";
}

+ (NSString *)appVersion {
    return @"1.0.1";
}

+ (NSString *)rumAccessToken {
    return @"token";
}


// MARK: - Basic builds

+ (SPLKAgentConfiguration *)buildDefault {
    // Default endpoint configuration for unit testing
    SPLKEndpointConfiguration *endpoint = [[SPLKEndpointConfiguration alloc]
        initWithRealm:[self realm] rumAccessToken:[self rumAccessToken]];

    // Default configuration for unit testing
    SPLKAgentConfiguration *configuration = [[SPLKAgentConfiguration alloc]
        initWithEndpoint:endpoint appName:[self appName] deploymentEnvironment:[self deploymentEnvironment]];

    SPLKSessionConfiguration *sessionConfiguration = [[SPLKSessionConfiguration alloc]
        initWithSamplingRate:1.0];

    NSMutableDictionary<NSString *, SPLKAttributeValue *> *globalAttributes = [[NSMutableDictionary alloc] init];
    SPLKAttributeValue *stringAttribute = [SPLKAttributeValue attributeWithString:@"value"];
    [globalAttributes setObject:stringAttribute forKey:@"attribute"];

    configuration.appVersion = [self appVersion];
    configuration.enableDebugLogging = NO;
    configuration.session = sessionConfiguration;
    configuration.globalAttributes = globalAttributes;


    return configuration;
}

+ (SPLKAgentConfiguration *)buildWithCustomURLs {
    // Endpoint configuration with custom traces and session replay urls
    SPLKEndpointConfiguration *endpoint = [[SPLKEndpointConfiguration alloc]
        initWithTrace:[self customTraceURL] sessionReplay:[self customSessionReplayURL]];

    SPLKAgentConfiguration *configuration = [[SPLKAgentConfiguration alloc]
        initWithEndpoint:endpoint appName:[self appName] deploymentEnvironment:[self deploymentEnvironment]];

    return configuration;
}

@end
