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
import SplunkAgent

/// Class that holds a configuration for an initial SDK setup.
///
/// Configuration is always bound to a specific URL.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
@objc(SPLKAgentConfiguration)
public final class AgentConfigurationObjC: NSObject {

    // MARK: - Public mandatory properties

    /// An optional endpoint configuration defining URLs to the instrumentation collector.
    @objc
    public let endpoint: EndpointConfigurationObjC?

    /// Required application name.
    ///
    /// Identifies the application in the RUM dashboard.
    /// App name is sent in all signals as a resource.
    @objc
    public let appName: String

    /// Required deployment environment.
    ///
    /// Identifies environment in the RUM dashboard, e.g. `dev`, `production` etc.
    /// Deployment environment is sent in all signals as a resource.
    @objc
    public let deploymentEnvironment: String


    // MARK: - Public optional properties

    /// A `NSString` containing the current application version.
    ///
    /// Application version is sent in all signals as a resource.
    /// The default value corresponds to the value of `CFBundleShortVersionString`.
    @objc
    public var appVersion: String

    /// Enables or disables debug logging.
    ///
    /// Debug logging prints span contents into the console.
    /// Defaults to `NO`.
    @objc
    public var enableDebugLogging: Bool

    /// Sets global attributes, which are sent with all signals.
    ///
    /// Defaults to an empty `NSDictionary` object.
    @objc
    public var globalAttributes: [String: AttributeValueObjC]

    /// Sets the `SPLKUserConfiguration` object.
    @objc
    public var user: UserConfigurationObjC

    /// Sets the `SPLKSessionConfiguration` object.
    @objc
    public var session: SessionConfigurationObjC


    // MARK: - Initialization

    /// Initializes a new Agent configuration with which the Agent is initialized.
    ///
    /// - Parameters:
    ///   - endpoint: An optional endpoint configuration defining URLs to the RUM instrumentation collector.
    ///   - appName: A required application name. Identifies the application in the RUM dashboard. App name is sent in all signals as a resource.
    ///   - deploymentEnvironment: A required deployment environment. Identifies environment in the RUM dashboard, e.g. `dev`, `production` etc.
    ///   Deployment environment is sent in all signals as a resource.
    @objc
    public convenience init(endpoint: EndpointConfigurationObjC?, appName: String, deploymentEnvironment: String) {
        let endpointConfiguration = endpoint?.endpointConfiguration()

        let agentConfiguration = AgentConfiguration(
            endpoint: endpointConfiguration,
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        self.init(for: agentConfiguration)
    }


    // MARK: - Conversion utils

    init(for agentConfiguration: AgentConfiguration) {
        // Initialize according to the native Swift variant
        endpoint = agentConfiguration.endpoint.map { EndpointConfigurationObjC(for: $0) }
        appName = agentConfiguration.appName
        deploymentEnvironment = agentConfiguration.deploymentEnvironment

        appVersion = agentConfiguration.appVersion
        enableDebugLogging = agentConfiguration.enableDebugLogging

        globalAttributes = agentConfiguration.globalAttributes.attributesDictionary

        user = UserConfigurationObjC(for: agentConfiguration.user)
        session = SessionConfigurationObjC(for: agentConfiguration.session)
    }

    func agentConfiguration() -> AgentConfiguration {
        // We return a native variant for Swift language
        var agentConfiguration = AgentConfiguration(
            endpoint: endpoint?.endpointConfiguration(),
            appName: appName,
            deploymentEnvironment: deploymentEnvironment
        )

        agentConfiguration.appVersion = appVersion
        agentConfiguration.enableDebugLogging = enableDebugLogging

        agentConfiguration.globalAttributes = MutableAttributes(with: globalAttributes)

        agentConfiguration.user = user.userConfiguration()
        agentConfiguration.session = session.sessionConfiguration()

        return agentConfiguration
    }
}
