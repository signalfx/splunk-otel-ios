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

/// A configuration object for initializing the agent.
///
/// This object holds all the settings required for the agent to connect to the collector and report data.
///
/// - Note: You can configure the agent by setting properties directly or by using the builder-style methods.
///         Both approaches achieve the same result.
public struct AgentConfiguration: AgentConfigurationProtocol, Codable, Equatable {

    // MARK: - Public mandatory properties

    /// The endpoint configuration defining URLs to the instrumentation collector.
    public let endpoint: EndpointConfiguration

    /// The application name, which identifies the application in the RUM dashboard.
    ///
    /// The app name is sent in all signals as a resource.
    public let appName: String

    /// The deployment environment of the application, e.g., `dev` or `production`.
    ///
    /// The deployment environment is sent in all signals as a resource and helps identify the environment in the RUM dashboard.
    public let deploymentEnvironment: String


    // MARK: - Public optional properties

    /// The version of the application.
    ///
    /// The application version is sent in all signals as a resource. The default value corresponds to `CFBundleShortVersionString`.
    public var appVersion: String = ConfigurationDefaults.appVersion

    /// A Boolean value that enables or disables debug logging.
    ///
    /// When enabled, debug logging prints span contents to the console. Defaults to `false`.
    public var enableDebugLogging: Bool = ConfigurationDefaults.enableDebugLogging

    /// A dictionary of global attributes that are sent with all signals.
    ///
    /// Defaults to an empty ``MutableAttributes`` object.
    public var globalAttributes: MutableAttributes = ConfigurationDefaults.globalAttributes

    /// A closure that intercepts outgoing spans, allowing for modification or filtering.
    ///
    /// If this closure is provided, all spans are passed through it before being exported.
    /// You can return the `SpanData` to approve it, return a modified `SpanData` to alter it, or return `nil` to discard the span entirely.
    public var spanInterceptor: ((SpanData) -> SpanData?)?

    /// The configuration for user-specific information.
    ///
    /// See ``UserConfiguration`` for more details.
    public var user = UserConfiguration()

    /// The configuration for session handling.
    ///
    /// See ``SessionConfiguration`` for more details.
    public var session = SessionConfiguration()


    // MARK: - Private

    /// The time, in seconds, after which a session is considered expired.
    var sessionTimeout: Double = ConfigurationDefaults.sessionTimeout
    /// The maximum duration, in seconds, for a single session.
    var maxSessionLength: Double = ConfigurationDefaults.maxSessionLength
    /// A Boolean value that enables or disables session recording.
    var recordingEnabled: Bool = ConfigurationDefaults.recordingEnabled
    // The internal logger for the agent.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Initialization

    /// Initializes the agent configuration with required settings.
    ///
    /// - Parameter endpoint: The endpoint configuration, such as ``EndpointConfiguration/init(realm:rumAccessToken:)``.
    /// - Parameter appName: The application name for identifying the app in the RUM dashboard.
    /// - Parameter deploymentEnvironment: The deployment environment, e.g., `dev` or `production`.
    ///
    /// ### Example ###
    /// ```
    /// let endpointConfig = EndpointConfiguration(
    ///     realm: "us0",
    ///     rumAccessToken: "YOUR_RUM_ACCESS_TOKEN"
    /// )
    ///
    /// let agentConfig = AgentConfiguration(
    ///     endpoint: endpointConfig,
    ///     appName: "MyAwesomeApp",
    ///     deploymentEnvironment: "production"
    /// )
    /// ```
    public init(endpoint: EndpointConfiguration, appName: String, deploymentEnvironment: String) {
        self.endpoint = endpoint
        self.appName = appName
        self.deploymentEnvironment = deploymentEnvironment
    }


    // MARK: - Builder methods

    /// Sets the application version.
    ///
    /// - Parameter appVersion: A `String` containing the application version.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func appVersion(_ appVersion: String) -> Self {
        var updated = self
        updated.appVersion = appVersion

        return updated
    }


    /// Enables or disables debug logging.
    ///
    /// - Parameter enableDebugLogging: A `Bool` to enable or disable debug logging.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func enableDebugLogging(_ enableDebugLogging: Bool) -> Self {
        var updated = self
        updated.enableDebugLogging = enableDebugLogging

        return updated
    }

    /// Sets the user configuration.
    ///
    /// - Parameter userConfiguration: A configuration object for the agent's user.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func userConfiguration(_ userConfiguration: UserConfiguration) -> Self {
        var updated = self
        updated.user = userConfiguration

        return updated
    }

    /// Sets the session configuration.
    ///
    /// - Parameter sessionConfiguration: A configuration object for the agent's session.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func sessionConfiguration(_ sessionConfiguration: SessionConfiguration) -> Self {
        var updated = self
        updated.session = sessionConfiguration

        return updated
    }

    /// Sets global attributes to be sent with all signals.
    ///
    /// - Parameter globalAttributes: A dictionary of global attributes.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func globalAttributes(_ globalAttributes: MutableAttributes) -> Self {
        var updated = self
        updated.globalAttributes = globalAttributes

        return updated
    }

    /// Sets the span interceptor callback.
    ///
    /// - Parameter spanInterceptor: A closure to intercept, modify, or discard spans.
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func spanInterceptor(_ spanInterceptor: ((SpanData) -> SpanData?)?) -> Self {
        var updated = self
        updated.spanInterceptor = spanInterceptor

        return updated
    }


    // MARK: - Codable

    // Defines the keys used for encoding and decoding the configuration.
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

    /// Validates the agent configuration.
    ///
    /// - Throws: `AgentConfigurationError` if the endpoint configuration is invalid.
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