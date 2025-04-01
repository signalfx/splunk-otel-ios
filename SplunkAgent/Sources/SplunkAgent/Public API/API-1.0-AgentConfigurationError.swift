//
/*
Copyright 2024 Splunk Inc.

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
enum AgentConfigurationError: Error, Equatable {

    /// Invalid endpoint. Either one of the supplied endpoint urls (traces, session replay) is invalid, or the supplied realm is empty.
    case invalidEndpoint(supplied: EndpointConfiguration)

    /// Invalid app name.
    case invalidAppName(supplied: String?)

    /// Invalid RUM access token.
    case invalidRumAccessToken(supplied: String?)

    /// Invalid deployment environment.
    case invalidDeploymentEnvironment(supplied: String?)
}

extension AgentConfigurationError: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        switch self {
        case let .invalidEndpoint(endpointConfiguration):
            return """
            Invalid endpoint configuration supplied. Either one of the supplied endpoint urls (traces, session, replay) \
            is invalid, or the supplied realm is empty. \
            Please check the agent configuration.
            Supplied endpoint configuration: \(endpointConfiguration.description)
            """

        case let .invalidAppName(appName):
            return "Invalid app name supplied, please check your configuration settings. Supplied: \(appName ?? "nil")"

        case let .invalidRumAccessToken(token):
            return "Invalid RUM access token supplied, please check the agent configuration. Supplied: \(token ?? "nil")"

        case let .invalidDeploymentEnvironment(environment):
            return "Invalid deployment environment supplied, please check the agent configuration. Supplied: \(environment ?? "nil")"
        }
    }

    public var debugDescription: String {
        return description
    }
}
