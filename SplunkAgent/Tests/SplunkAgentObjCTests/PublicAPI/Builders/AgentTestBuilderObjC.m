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

#import "AgentTestBuilderObjC.h"


@implementation AgentTestBuilderObjC

// MARK: - Basic builds

+ (SPLKAgent *)buildDefault {
    return [self buildDefaultForTestNamed:@"agent"];
}

+ (SPLKAgent *)buildDefaultForTestNamed:(NSString *)testName {
    // Empty configuration for agent build
    SPLKAgentConfiguration *configuration = [STSAgentTesting buildTestConfiguration];

    // The default agent for unit testing
    SPLKAgent *agent = [STSAgentTesting buildTestAgentWith:configuration testNamed:testName];

    return agent;
}

@end
