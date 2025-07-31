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

import Foundation
@_spi(objc) import SplunkAgent

/// Private class for supporting automated API testing.
///
/// **Warning:** This class is not meant for client applications and may produce
///            unexpected results.
@objc(STSAgentTesting) @objcMembers
public class AgentTestingObjC: NSObject {

    // MARK: - Configurations builds

    /// Private method for creating test agent configurations.
    ///
    /// **Warning:** This method is not meant for client applications and may produce
    ///            unexpected results, which are not supported by the product.
    public static func buildTestConfiguration() -> AgentConfigurationObjC {
        let endpoint = EndpointConfiguration(
            realm: "realm",
            rumAccessToken: "token"
        )

        let configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: "test",
            deploymentEnvironment: "dev"
        )

        return AgentConfigurationObjC(for: configuration)
    }


    // MARK: - Agent builds

    /// Private method for creating test instances of the agent.
    ///
    /// **Warning:** This method is not meant for client applications and may produce
    ///            unexpected results, which are not supported by the product.
    ///
    /// - Parameters:
    ///   - configuration: A `SPLKAgentConfiguration` for the initial SDK setup.
    ///   - named: A `NSString` with the name of the test being performed.
    public static func buildTestAgent(with configuration: AgentConfigurationObjC, testNamed named: String? = nil) -> SplunkRumObjC {
        let configuration = buildTestConfiguration()
        let agent = SplunkRum.buildTestInstance(
            with: configuration.agentConfiguration(),
            testNamed: named
        )

        return SplunkRumObjC(with: agent)
    }
}
