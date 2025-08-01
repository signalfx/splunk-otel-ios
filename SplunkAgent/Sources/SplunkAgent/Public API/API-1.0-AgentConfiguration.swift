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

internal import CiscoLogger
import Foundation
import OpenTelemetrySdk
internal import SplunkCommon

/// Structure that holds a configuration for an initial SDK setup.
///
/// Configuration is always bound to a specific URL.
public struct AgentConfiguration: AgentConfigurationProtocol, Codable, Equatable {

    // MARK: - Public mandatory properties

    /// The endpoint configuration specifying the Splunk realm and RUM access token.
    public let endpoint: EndpointConfiguration

    /// The name of your application, used to identify your data in Splunk RUM.
    public let appName: String

    /// The deployment environment (e.g., "production", "staging", "development") for your application.
    public let deploymentEnvironment: String


    // MARK: - Public optional properties

    /// The version of the application. This is sent as a resource attribute with all telemetry.
    public var appVersion: String = ConfigurationDefaults.appVersion

    /// A boolean indicating whether debug logging is enabled for the agent.
    public var enableDebugLogging: Bool = ConfigurationDefaults.enableDebugLogging

    /// A collection of global attributes that will be attached to all telemetry sent by the agent.
    public var globalAttributes: MutableAttributes = ConfigurationDefaults.globalAttributes

    /// Span interceptor to be used to filter or modify all outgoing `SpanData` instances.
    ///
    /// If the callback is provided, all spans are funneled through the callback, and can be either approved by returning the span in the callback,
    /// or discarded by returning `nil` in the callback. Spans can also be modified by the callback.
    public var spanInterceptor: ((SpanData) -> SpanData?)?

    /// Configuration related to user tracking, including the user tracking mode.
    public var user = UserConfiguration()

    /// Configuration related to session sampling, including the session sampling rate.
    public var session = SessionConfiguration()


    // MARK: - Private

    var sessionTimeout: Double = ConfigurationDefaults.sessionTimeout
    var maxSessionLength: Double = ConfigurationDefaults.maxSessionLength
    var recordingEnabled: Bool = ConfigurationDefaults.recordingEnabled
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Initialization

    public init(endpoint: EndpointConfiguration, appName: String, deploymentEnvironment: String) {
        self.endpoint = endpoint
        self.appName = appName
        self.deploymentEnvironment = deploymentEnvironment
    }


    // MARK: - Builder methods

    /// Sets the application version. `appVersion` is sent in all signals as a resource.
    ///
    /// - Parameter appVersion: A `String` containing the application version.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func appVersion(_ appVersion: String) -> Self {
        var updated = self
        updated.appVersion = appVersion

        return updated
    }


    /// Enables or disables debug logging. Debug logging prints span contents into the console.
    ///
    /// - Parameter enableDebugLogging: A `Bool` to enable or disable debug logging.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func enableDebugLogging(_ enableDebugLogging: Bool) -> Self {
        var updated = self
        updated.enableDebugLogging = enableDebugLogging

        return updated
    }

    /// Sets the ``UserConfiguration`` object.
    ///
    /// - Parameter userConfiguration: A configuration object representing properties of the Agent's ``User``.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func userConfiguration(_ userConfiguration: UserConfiguration) -> Self {
        var updated = self
        updated.user = userConfiguration

        return updated
    }

    /// Sets the ``SessionConfiguration`` object.
    ///
    /// - Parameter sessionConfiguration: A configuration object representing properties of the Agent's ``Session``.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func sessionConfiguration(_ sessionConfiguration: SessionConfiguration) -> Self {
        var updated = self
        updated.session = sessionConfiguration

        return updated
    }

    /// Sets global attributes, which are sent with all signals.
    ///
    /// - Parameter globalAttributes: A ``MutableAttributes`` object containing the global attributes to be sent with all signals.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func globalAttributes(_ globalAttributes: MutableAttributes) -> Self {
        var updated = self
        updated.globalAttributes = globalAttributes

        return updated
    }

    /// Sets the span interceptor callback. If the callback is provided, all spans will be funneled through the callback,
    /// and can be either approved by returning the span in the callback, or discarded by returning `nil`.
    /// Spans can also be modified by the callback.
    ///
    /// - Parameter spanInterceptor: A `SpanData` interceptor callback.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func spanInterceptor(_ spanInterceptor: ((SpanData) -> SpanData?)?) -> Self {
        var updated = self
        updated.spanInterceptor = spanInterceptor

        return updated
    }


    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {

        // Public mandatory properties
        case endpoint
        case appName
        case deploymentEnvironment

        // Optional public properties except span filter
        case appVersion
        case enableDebugLogging
        case globalAttributes

        // Optional public configuration objects
        case user
        case session
    }


    // MARK: - Equatable

    public static func == (lhs: AgentConfiguration, rhs: AgentConfiguration) -> Bool {
        return
            lhs.endpoint == rhs.endpoint &&
            lhs.appName == rhs.appName &&
            lhs.deploymentEnvironment == rhs.deploymentEnvironment &&

            lhs.appVersion == rhs.appVersion &&
            lhs.enableDebugLogging == rhs.enableDebugLogging &&
            lhs.globalAttributes == rhs.globalAttributes &&
            lhs.user == rhs.user &&
            lhs.session == rhs.session
    }
}

extension AgentConfiguration {

    // MARK: - Validation

    /// Validate a configuration by checking the endpoint first, then other configuration parameters.
    ///
    /// - Throws: ``AgentConfigurationError`` if provided configuration is invalid.
    func validate() throws {
        try endpoint.validate()

        // Validate app name
        if appName.isEmpty {
            logger.log(level: .error, isPrivate: false) {
                AgentConfigurationError
                    .invalidAppName(supplied: appName)
                    .description
            }
        }

        // Validate deployment environment
        if deploymentEnvironment.isEmpty {
            logger.log(level: .error) {
                AgentConfigurationError
                    .invalidDeploymentEnvironment(supplied: deploymentEnvironment)
                    .description
            }
        }
    }
}
