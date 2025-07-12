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

/// An error that indicates an invalid agent configuration.
enum AgentConfigurationError: Error, Equatable {

    /// An error indicating that the provided endpoint configuration is invalid.
    ///
    /// This can occur if the endpoint URLs cannot be constructed or are missing.
    /// - Parameter supplied: The invalid ``EndpointConfiguration`` that was provided.
    case invalidEndpoint(supplied: EndpointConfiguration)

    /// An error indicating that the application name is missing or empty.
    /// - Parameter supplied: The invalid app name that was provided.
    case invalidAppName(supplied: String?)

    /// An error indicating that the RUM access token is missing or empty.
    /// - Parameter supplied: The invalid token that was provided.
    case invalidRumAccessToken(supplied: String?)

    /// An error indicating that the deployment environment is missing or empty.
    /// - Parameter supplied: The invalid environment string that was provided.
    case invalidDeploymentEnvironment(supplied: String?)
}

extension AgentConfigurationError: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        switch self {
        case let .invalidEndpoint(endpointConfiguration):
            return """
            The supplied endpoint configuration is invalid. \
            Please check the agent configuration.
            Supplied endpoint configuration: \(endpointConfiguration.description)
            """

        case let .invalidAppName(appName):
            return "Invalid app name supplied, please check your configuration settings. Supplied app name: \"\(appName ?? "nil")\""

        case let .invalidRumAccessToken(token):
            return "Invalid RUM access token supplied, please check the agent configuration. Supplied access token: \"\(token ?? "nil")\""

        case let .invalidDeploymentEnvironment(environment):
            return "Invalid deployment environment supplied, please check the agent configuration. Supplied deployment environment: \"\(environment ?? "nil")\""
        }
    }

    public var debugDescription: String {
        return description
    }
}