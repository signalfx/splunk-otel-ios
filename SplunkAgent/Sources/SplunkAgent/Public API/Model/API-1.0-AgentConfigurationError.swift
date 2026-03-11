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

/// Describes an invalid agent configuration.
public enum AgentConfigurationError: Error, Equatable {

    /// Invalid endpoint. Either one of the supplied endpoint urls (traces, session replay) is invalid, the supplied realm is empty, or the endpoint is missing.
    case invalidEndpoint(supplied: EndpointConfiguration?)

    /// Invalid app name.
    case invalidAppName(supplied: String?)

    /// Invalid RUM access token.
    case invalidRumAccessToken(supplied: String?)

    /// Invalid deployment environment.
    case invalidDeploymentEnvironment(supplied: String?)
}


extension AgentConfigurationError: CustomStringConvertible, CustomDebugStringConvertible {

    /// A human-readable string representation of the `AgentConfigurationError` instance.
    public var description: String {
        switch self {
        case let .invalidEndpoint(endpointConfiguration):
            return """
                The supplied endpoint configuration is invalid. \
                Please check the agent configuration.
                Supplied endpoint configuration: \(endpointConfiguration?.description ?? "nil")
                """

        case let .invalidAppName(appName):
            return "Invalid app name supplied, please check your configuration settings. Supplied app name: \"\(appName ?? "nil")\""

        case let .invalidRumAccessToken(token):
            return "Invalid RUM access token supplied, please check the agent configuration. Supplied access token: \"\(token ?? "nil")\""

        case let .invalidDeploymentEnvironment(environment):
            return "Invalid deployment environment supplied, please check the agent configuration. Supplied deployment environment: \"\(environment ?? "nil")\""
        }
    }

    /// A string representation of an `AgentConfigurationError` instance intended for diagnostic output, identical to `description`.
    public var debugDescription: String {
        description
    }
}


extension AgentConfigurationError: LocalizedError {

    /// A string with localized message describing the error and why it occurred.
    public var errorDescription: String? {
        description
    }
}
