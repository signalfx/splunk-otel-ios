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

@testable import SplunkAgent

/// The protocol is used to hide and suppress warnings related
/// to deprecated API calls on the `AgentConfiguration` structure.
///
/// We must use this workaround since we still need to test these
/// deprecated APIs, and Swift does not provide a direct solution.
public protocol AgentConfigurationDeprecated {

    // MARK: - Instrumentation properties (Legacy)

    var screenNameSpans: Bool { get set }
    var showVCInstrumentation: Bool { get set }


    // MARK: - Instrumentation methods (Legacy)

    func screenNameSpans(enabled: Bool) -> Self
    func showVCInstrumentation(_ show: Bool) -> Self
}


extension AgentConfiguration: AgentConfigurationDeprecated {

    // MARK: - Instrumentation properties (Legacy)

    var deprecatedScreenNameSpans: Bool {
        get {
            return (self as AgentConfigurationDeprecated).screenNameSpans
        }
        set {
            var configuration = self as AgentConfigurationDeprecated
            configuration.screenNameSpans = newValue

            if let agentConfiguration = configuration as? AgentConfiguration {
                self = agentConfiguration
            }
        }
    }

    var deprecatedShowVCInstrumentation: Bool {
        get {
            return (self as AgentConfigurationDeprecated).showVCInstrumentation
        }
        set {
            var configuration = self as AgentConfigurationDeprecated
            configuration.showVCInstrumentation = newValue

            if let agentConfiguration = configuration as? AgentConfiguration {
                self = agentConfiguration
            }
        }
    }


    // MARK: - Instrumentation methods (Legacy)

    func deprecatedScreenNameSpans(enabled: Bool) -> Self {
        let deprecatedSelf = (self as AgentConfigurationDeprecated)
            .screenNameSpans(enabled: enabled)

        if let agentConfiguration = deprecatedSelf as? AgentConfiguration {
            return agentConfiguration
        }

        return self
    }

    func deprecatedShowVCInstrumentation(_ show: Bool) -> Self {
        let deprecatedSelf = (self as AgentConfigurationDeprecated)
            .showVCInstrumentation(show)

        if let agentConfiguration = deprecatedSelf as? AgentConfiguration {
            return agentConfiguration
        }

        return self
    }
}
