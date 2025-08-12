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
import OpenTelemetrySdk

/// Defines the properties of the agent configuration.
protocol AgentConfigurationProtocol: Codable, Equatable {

    // MARK: - Mandatory parameters

    /// The endpoint configuration for data transmission.
    var endpoint: EndpointConfiguration { get }

    /// The name of the application being monitored.
    var appName: String { get }

    /// The deployment environment of the application (e.g., "production", "staging").
    var deploymentEnvironment: String { get }


    // MARK: - Optional parameters

    /// The version of the application.
    var appVersion: String { get set }

    /// A Boolean value that determines whether debug logging is enabled.
    var enableDebugLogging: Bool { get set }

    /// A mutable collection of attributes to be applied to all spans.
    var globalAttributes: MutableAttributes { get set }

    /// An optional closure that can intercept and modify span data before it is exported.
    var spanInterceptor: ((SpanData) -> SpanData?)? { get set }

    /// The configuration related to user information.
    var user: UserConfiguration { get set }

    /// The configuration related to session management.
    var session: SessionConfiguration { get set }


    // MARK: - Remote configuration parameters

    /// The session timeout interval in seconds, often configured remotely.
    var sessionTimeout: Double { get set }

    /// The maximum length of a session in seconds, often configured remotely.
    var maxSessionLength: Double { get set }
}
