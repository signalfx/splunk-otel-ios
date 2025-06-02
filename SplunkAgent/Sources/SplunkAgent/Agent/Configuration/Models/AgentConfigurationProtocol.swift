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
import OpenTelemetrySdk

/// Defines the properties of the agent configuration.
protocol AgentConfigurationProtocol: Codable, Equatable {

    // MARK: - Mandatory parameters

    var endpoint: EndpointConfiguration { get }
    var appName: String { get }
    var deploymentEnvironment: String { get }


    // MARK: - Optional parameters

    var appVersion: String { get set }
    var enableDebugLogging: Bool { get set }
    var globalAttributes: MutableAttributes { get set }
    var spanInterceptor: ((SpanData) -> SpanData?)? { get set }

    var user: UserConfiguration { get set }
    var session: SessionConfiguration { get set }


    // MARK: - Remote configuration parameters

    var sessionTimeout: Double { get set }
    var maxSessionLength: Double { get set }
}
