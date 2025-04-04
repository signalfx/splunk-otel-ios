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
internal import SplunkLogger

/// Structure that holds a configuration for an initial SDK setup.
///
/// Configuration is always bound to a specific URL.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public struct AgentConfiguration: AgentConfigurationProtocol, Codable, Equatable {

    // MARK: - Public mandatory properties

    /// A required RUM access token, authenticates requests to the RUM instrumentation collector.
    public let rumAccessToken: String

    /// A required endpoint configuration defining URLs to the instrumentation collector.
    public let endpoint: EndpointConfiguration

    /// Required application name. Identifies the application in the RUM dashboard. App name is sent in all signals as a resource.
    public let appName: String

    /// Required deployment environment. Identifies environment in the RUM dashboard, e.g. `dev`, `production` etc.
    /// Deployment environment is sent in all signals as a resource.
    public let deploymentEnvironment: String


    // MARK: - Public optional properties

    /// A `String` containing the current application version. Application version is sent in all signals as a resource.
    ///
    /// The default value corresponds to the value of `CFBundleShortVersionString`.
    public var appVersion: String = ConfigurationDefaults.appVersion

    /// Enables or disables debug logging. Debug logging prints span contents into the console.
    ///
    /// Defaults to `false`.
    public var enableDebugLogging: Bool = ConfigurationDefaults.enableDebugLogging

    /// Sets the sampling rate with at which sessions will be sampled. The sampling rate is from the `<0.0, 1.0>` interval.
    ///
    /// `1.0` equals to zero sampling (all instrumentation is sent), `0.0` equals to all session being sampled, `0.5` equals to 50% sampling. Defaults to `1.0`.
    public var sessionSamplingRate: Double = ConfigurationDefaults.sessionSamplingRate

    /// Sets global attributes, which are sent with all signals.
    ///
    /// Defaults to an empty dictionary.
    public var globalAttributes: [String: String] = ConfigurationDefaults.globalAttributes

    /// Span filter to be used to filter all outgoing spans.
    ///
    /// If the callback is provided, all spans are funneled to the callback, and can be either approved by returning the span in the callback,
    /// or discarded by returning `nil` in the callback.
    public var spanFilter: ((SpanData) -> SpanData?)?


    // MARK: - Private

    /// Final computed Traces URL used by the agent.
    let tracesUrl: URL

    /// Final computed Logs URL used by the agent.
    let logsUrl: URL

    /// Final computed config URL used by the agent. Not in use at the moment.
    let configUrl: URL

    /// Final computed session replay URL used by the agent.
    let sessionReplayUrl: URL?

    var sessionTimeout: Double = ConfigurationDefaults.sessionTimeout
    var maxSessionLength: Double = ConfigurationDefaults.maxSessionLength
    var recordingEnabled: Bool = ConfigurationDefaults.recordingEnabled
    let internalLogger = InternalLogger(configuration: .agent(category: "Configuration"))


    // MARK: - Initialization

    /// Initializes a new Agent configuration with which the Agent is initialized.
    ///
    /// - Parameters:
    ///   - rumAccessToken: A required RUM access token to authenticate requests with the RUM instrumentation collector.
    ///   - endpoint: A required endpoint configuration defining URLs to the RUM instrumentation collector.
    ///   - appName: A required application name. Identifies the application in the RUM dashboard. App name is sent in all signals as a resource.
    ///   - deploymentEnvironment: A required deployment environment. Identifies environment in the RUM dashboard, e.g. `dev`, `production` etc.
    ///   Deployment environment is sent in all signals as a resource.
    ///   
    /// - Throws: `AgentConfigurationError` if provided configuration is invalid.
    public init(rumAccessToken: String, endpoint: EndpointConfiguration, appName: String, deploymentEnvironment: String) throws {

        guard rumAccessToken.count > 0 else {
            throw AgentConfigurationError.invalidRumAccessToken(supplied: rumAccessToken)
        }

        guard appName.count > 0 else {
            throw AgentConfigurationError.invalidAppName(supplied: appName)
        }

        guard deploymentEnvironment.count > 0 else {
            throw AgentConfigurationError.invalidDeploymentEnvironment(supplied: deploymentEnvironment)
        }

        guard let tracesEndpoint = endpoint.tracesEndpoint else {
            throw AgentConfigurationError.invalidEndpoint(supplied: endpoint)
        }

        self.rumAccessToken = rumAccessToken
        self.endpoint = endpoint
        self.appName = appName
        self.deploymentEnvironment = deploymentEnvironment

        // Build traces url
        tracesUrl = try Self.authenticate(endpoint: tracesEndpoint, with: rumAccessToken, in: endpoint)

        // Build session replay url
        if let sessionReplayEndpoint = endpoint.sessionReplayEndpoint {
            sessionReplayUrl = try Self.authenticate(endpoint: sessionReplayEndpoint, with: rumAccessToken, in: endpoint)
        } else {
            sessionReplayUrl = nil
        }

        // ⚠️ Logs endpoint not in the api at the moment, using traces URL as a placeholder.
        logsUrl = tracesUrl

        // ⚠️ Config endpoint not in use at the moment, using traces URL as a placeholder.
        configUrl = tracesUrl
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

    /// Sets the sampling rate with which sessions will be sampled.
    ///
    /// - Parameter sessionSamplingRate: A sampling rate in the `<0.0, 1.0>` interval.
    /// `1.0` equals to zero sampling (all instrumentation is sent), `0.0` equals to all session being sampled, `0.5` equals to 50% sampling.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func sessionSamplingRate(_ sessionSamplingRate: Double) -> Self {
        var updated = self
        updated.sessionSamplingRate = sessionSamplingRate

        return updated
    }

    /// Sets global attributes, which are sent with all signals.
    ///
    /// - Parameter globalAttributes: A dictionary containing the global attributes to be sent with all signals.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func globalAttributes(_ globalAttributes: [String: String]) -> Self {
        var updated = self
        updated.globalAttributes = globalAttributes

        return updated
    }

    /// Sets the span filter callback. If the callback is provided, all spans will be funneled to the callback,
    /// and can be either approved by returning the span in the callback, or discarded by returning `nil`.
    ///
    /// - Parameter spanFilter: A span filter callback.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func spanFilter(_ spanFilter: ((SpanData) -> SpanData?)?) -> Self {
        var updated = self
        updated.spanFilter = spanFilter

        return updated
    }


    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {

        // Public mandatory properties
        case rumAccessToken
        case endpoint
        case appName
        case deploymentEnvironment

        // Optional public properties except span filter
        case appVersion
        case enableDebugLogging
        case sessionSamplingRate
        case globalAttributes

        // Private properties
        case tracesUrl
        case logsUrl
        case configUrl
        case sessionReplayUrl
    }


    // MARK: - Equatable

    public static func == (lhs: AgentConfiguration, rhs: AgentConfiguration) -> Bool {
        return
            lhs.rumAccessToken == rhs.rumAccessToken &&
            lhs.endpoint == rhs.endpoint &&
            lhs.appName == rhs.appName &&
            lhs.deploymentEnvironment == rhs.deploymentEnvironment &&

            lhs.appVersion == rhs.appVersion &&
            lhs.enableDebugLogging == rhs.enableDebugLogging &&
            lhs.sessionSamplingRate == rhs.sessionSamplingRate &&
            lhs.globalAttributes == rhs.globalAttributes &&

            lhs.tracesUrl == rhs.tracesUrl &&
            lhs.logsUrl == rhs.logsUrl &&
            lhs.configUrl == rhs.configUrl &&
            lhs.sessionReplayUrl == rhs.sessionReplayUrl
    }


    // MARK: - Endpoint authentication

    /// Authenticates an endpoint URL by appending the auth token to the URL's query. Throws a `AgentConfigurationError` in case of invalid data.
    private static func authenticate(endpoint: URL, with authToken: String, in endpointConfiguration: EndpointConfiguration) throws -> URL {

        guard var urlCompoments = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw AgentConfigurationError.invalidEndpoint(supplied: endpointConfiguration)
        }

        urlCompoments.queryItems = [URLQueryItem(name: "auth", value: authToken)]

        guard urlCompoments.queryItems?.count ?? 0 > 0 else {
            throw AgentConfigurationError.invalidRumAccessToken(supplied: authToken)
        }

        guard let authenticatedUrl = urlCompoments.url else {
            throw AgentConfigurationError.invalidEndpoint(supplied: endpointConfiguration)
        }

        return authenticatedUrl
    }
}
