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
import SplunkAgent

final class ConfigurationTestBuilder {

    // MARK: - Static constants

    public static let customTraceUrl = URL(string: "http://sampledomain.com/tenant/traces")!
    public static let customSessionReplayUrl = URL(string: "http://sampledomain.com/tenant/sessionreplay")!
    public static let realm = "dev"
    public static let deploymentEnvironment = "testenv"
    public static let appName = "Tests"
    public static let appVersion = "1.0.1"
    public static let rumAccessToken = "token"


    // MARK: - Basic builds

    public static func buildDefault() throws -> AgentConfiguration {

        // Default endpoint configuration for unit testing
        let endpoint = EndpointConfiguration(
            realm: realm,
            rumAccessToken: rumAccessToken
        )

        // Default configuration for unit testing
        var configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        configuration.appVersion = appVersion
        configuration.enableDebugLogging = true
        configuration.sessionSamplingRate = 0.1
        configuration.globalAttributes = ["attribute": "value"]
        configuration.spanInterceptor = { spanData in
            spanData
        }

        return configuration
    }

    public static func buildMinimal() throws -> AgentConfiguration {
        // Minimal endpoint configuration for unit testing
        let endpoint = EndpointConfiguration(
            realm: realm,
            rumAccessToken: rumAccessToken
        )

        // Minimal configuration for unit testing
        let minimal = AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        return minimal
    }

    public static func buildWithCustomUrls() throws -> AgentConfiguration {
        // Endpoint configuration with custom traces and session replay urls
        let endpoint = EndpointConfiguration(
            trace: customTraceUrl,
            sessionReplay: customSessionReplayUrl
        )

        let configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        return configuration
    }

    public static func buildInvalidEndpoint() throws -> AgentConfiguration {
        // Build invalid endpoint endpoint configuration
        let endpoint = EndpointConfiguration(
            realm: "\\//",
            rumAccessToken: rumAccessToken
        )

        let configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        return configuration
    }
}
