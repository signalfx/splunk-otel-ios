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

#import <Foundation/Foundation.h>
@import SplunkAgentObjC;

@interface ConfigurationTestBuilderObjC : NSObject

// MARK: - Static constants

@property (nonatomic, readonly, class) NSURL *customTraceURL;
@property (nonatomic, readonly, class) NSURL *customSessionReplayURL;

@property (nonatomic, readonly, class) NSString *realm;
@property (nonatomic, readonly, class) NSString *deploymentEnvironment;
@property (nonatomic, readonly, class) NSString *appName;
@property (nonatomic, readonly, class) NSString *appVersion;
@property (nonatomic, readonly, class) NSString *rumAccessToken;


// MARK: - Basic builds

+ (SPLKAgentConfiguration *)buildDefault;
+ (SPLKAgentConfiguration *)buildWithCustomURLs;

@end
