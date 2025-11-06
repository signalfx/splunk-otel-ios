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

enum ConfigurationTestBuilderError: Error {
    case invalidURL(String)
}

final class ConfigurationTestBuilder {

    // MARK: - Static constants

    static let customTraceAddress = "http://sampledomain.com/tenant/traces"
    static let customSessionReplayAddress = "http://sampledomain.com/tenant/sessionreplay"
    static let realm = "dev"
    static let deploymentEnvironment = "testenv"
    static let appName = "Tests"
    static let appVersion = "1.0.1"
    static let rumAccessToken = "token"


    // MARK: - Basic builds

    static func buildDefault() throws -> AgentConfiguration {

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

        var sessionConfiguration = SessionConfiguration()
        sessionConfiguration.samplingRate = 1.0

        configuration.appVersion = appVersion
        configuration.enableDebugLogging = true
        configuration.session = sessionConfiguration
        configuration.globalAttributes = MutableAttributes(dictionary: ["attribute": .string("value")])

        configuration.spanInterceptor = { spanData in
            spanData
        }

        return configuration
    }

    static func buildDefaultSampledOut() throws -> AgentConfiguration {

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

        var sessionConfiguration = SessionConfiguration()
        sessionConfiguration.samplingRate = 0.0

        configuration.appVersion = appVersion
        configuration.enableDebugLogging = true
        configuration.session = sessionConfiguration
        configuration.globalAttributes = MutableAttributes(dictionary: ["attribute": .string("value")])

        configuration.spanInterceptor = { spanData in
            spanData
        }

        return configuration
    }

    static func buildMinimal() throws -> AgentConfiguration {
        // Minimal endpoint configuration for unit testing
        let endpoint = EndpointConfiguration(
            realm: realm,
            rumAccessToken: rumAccessToken
        )

        // Minimal configuration for unit testing
        return AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )
    }

    static func buildWithCustomUrls() throws -> AgentConfiguration {
        // Endpoint configuration with custom traces and session replay urls
        let endpoint = try EndpointConfiguration(
            trace: customUrl(for: customTraceAddress),
            sessionReplay: customUrl(for: customSessionReplayAddress)
        )

        return AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )
    }

    static func buildInvalidEndpoint() throws -> AgentConfiguration {
        // Build invalid endpoint endpoint configuration
        let endpoint = EndpointConfiguration(
            realm: "\\//",
            rumAccessToken: rumAccessToken
        )

        return AgentConfiguration(
            endpoint: endpoint,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )
    }


    // MARK: - URL builders

    static func customUrl(for string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw ConfigurationTestBuilderError.invalidURL(string)
        }

        return url
    }
}
