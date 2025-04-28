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

/// Structure that holds a configuration for an initial SDK setup.
///
/// Configuration is always bound to a specific URL.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public struct AgentConfiguration: AgentConfigurationProtocol, Codable, Equatable {

    // MARK: - Public mandatory properties

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

    /// Span interceptor to be used to filter or modify all outgoing spans.
    ///
    /// If the callback is provided, all spans are funneled through the callback, and can be either approved by returning the span in the callback,
    /// or discarded by returning `nil` in the callback. Spans can also be modified by the callback.
    public var spanInterceptor: ((inout SpanData) -> SpanData?)?


    // MARK: - Private

    var sessionTimeout: Double = ConfigurationDefaults.sessionTimeout
    var maxSessionLength: Double = ConfigurationDefaults.maxSessionLength
    var recordingEnabled: Bool = ConfigurationDefaults.recordingEnabled


    // MARK: - Initialization

    /// Initializes a new Agent configuration with which the Agent is initialized.
    ///
    /// - Parameters:
    ///   - endpoint: A required endpoint configuration defining URLs to the RUM instrumentation collector.
    ///   - appName: A required application name. Identifies the application in the RUM dashboard. App name is sent in all signals as a resource.
    ///   - deploymentEnvironment: A required deployment environment. Identifies environment in the RUM dashboard, e.g. `dev`, `production` etc.
    ///   Deployment environment is sent in all signals as a resource.
    ///
    /// - Throws: `AgentConfigurationError` if provided configuration is invalid.
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

    /// Sets the span interceptor callback. If the callback is provided, all spans will be funneled through the callback,
    /// and can be either approved by returning the span in the callback, or discarded by returning `nil`.
    /// Spans can also be modified by the callback.
    ///
    /// - Parameter spanInterceptor: A span interceptor callback.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func spanInterceptor(_ spanInterceptor: ((inout SpanData) -> SpanData?)?) -> Self {
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
        case sessionSamplingRate
        case globalAttributes
    }


    // MARK: - Equatable

    public static func == (lhs: AgentConfiguration, rhs: AgentConfiguration) -> Bool {
        return
            lhs.endpoint == rhs.endpoint &&
            lhs.appName == rhs.appName &&
            lhs.deploymentEnvironment == rhs.deploymentEnvironment &&

            lhs.appVersion == rhs.appVersion &&
            lhs.enableDebugLogging == rhs.enableDebugLogging &&
            lhs.sessionSamplingRate == rhs.sessionSamplingRate &&
            lhs.globalAttributes == rhs.globalAttributes
    }
}

extension AgentConfiguration {

    // MARK: - Validation

    /// Validate a configuration by checking the endpoint first, then other configuration parameterers.
    ///
    /// - Throws: `AgentConfigurationError` if provided configuration is invalid.
    func validate() throws {
        try endpoint.validate()

        // Validate app name
        if appName.isEmpty {
            internalLogger.log(level: .error) {
                AgentConfigurationError
                    .invalidAppName(supplied: appName)
                    .description
            }
        }

        // Validate deployment environment
        if deploymentEnvironment.isEmpty {
            internalLogger.log(level: .error) {
                AgentConfigurationError
                    .invalidDeploymentEnvironment(supplied: deploymentEnvironment)
                    .description
            }
        }
    }
}
