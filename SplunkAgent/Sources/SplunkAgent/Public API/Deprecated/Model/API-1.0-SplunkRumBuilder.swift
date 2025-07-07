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
internal import SplunkCommon
internal import SplunkNavigation
internal import SplunkNetwork

import Foundation

@available(*, deprecated, message:
    """
    The SplunkRumBuilder class is no longer supported and will be removed in a later version.
    Use the `SplunkRum.install` API instead.
    """)
public class SplunkRumBuilder {

    // MARK: - Configuration properties

    private var beaconUrl: String
    private var rumAuth: String
    private var debug: Bool = false
    private var environment: String?
    private var sessionSamplingRatio: Double = ConfigurationDefaults.sessionSamplingRate
    private var appName: String?

    private var endpointConfiguration: EndpointConfiguration?


    // MARK: - Instrumentations properties

    private var screenNameSpans: Bool = true
    private var showVCInstrumentation: Bool = false
    private var networkInstrumentation: Bool = true
    private var ignoreURLs: NSRegularExpression?


    // MARK: - Logging

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkRumBuilder")


    // MARK: - Builder initialization

    @available(*, deprecated, message:
        """
        This initializer will be removed in a later version.
        Use the `SplunkRum.install` API instead.
        """)
    public init(beaconUrl: String, rumAuth: String) {
        self.beaconUrl = beaconUrl
        self.rumAuth = rumAuth

        guard let traceUrl = URL(string: beaconUrl) else {
            logger.log(level: .error) {
                "Unable to initialize SplunkRumBuilder: Invalid beacon URL"
            }

            return
        }

        endpointConfiguration = EndpointConfiguration(trace: traceUrl)
    }

    @available(*, deprecated, message:
        """
        This initializer will be removed in a later version.
        Use the `SplunkRum.install` API instead.
        """)
    public init(realm: String, rumAuth: String) {
        beaconUrl = "https://rum-ingest.\(realm).signalfx.com/v1/rum"
        self.rumAuth = rumAuth

        endpointConfiguration = EndpointConfiguration(realm: realm, rumAccessToken: rumAuth)
    }


    // MARK: - Public configuration builder methods

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use `AgentConfiguration`'s `enableDebugLogging` instead.
        """)
    @discardableResult
    public func debug(enabled: Bool) -> SplunkRumBuilder {
        debug = enabled
        return self
    }

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use `AgentConfiguration`'s `deploymentEnvironment` instead.
        """)
    @discardableResult
    public func deploymentEnvironment(environment: String) -> SplunkRumBuilder {
        self.environment = environment
        return self
    }

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use `AgentConfiguration`'s `sessionConfiguration` instead.
        """)
    @discardableResult
    public func sessionSamplingRatio(samplingRatio: Double) -> SplunkRumBuilder {
        sessionSamplingRatio = samplingRatio
        return self
    }

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use `AgentConfiguration`'s `enableDebugLogging` instead.
        """)
    @discardableResult
    public func setApplicationName(_ appName: String) -> SplunkRumBuilder {
        self.appName = appName
        return self
    }

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        """)
    @discardableResult
    public func enableDiskCache(enabled: Bool) -> SplunkRumBuilder {
        return self
    }


    // MARK: - Instrumentations builder methods

    /// Sets whether or not the Navigation module should automatically detect navigation in the application.
    ///
    /// - Parameter show: If `true`, the Navigation module will automatically detect navigation.
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use `SplunkRum.shared.navigation.preferences.enableAutomatedTracking` instead.
        """)
    @discardableResult
    public func showVCInstrumentation(_ show: Bool) -> SplunkRumBuilder {
        showVCInstrumentation = show
        return self
    }


    /// Specifies whether the Navigation module should be activated and generate navigation spans.
    ///
    /// - Parameter enabled: If `true`, the Navigation module generates navigation spans.
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func screenNameSpans(enabled: Bool) -> SplunkRumBuilder {
        screenNameSpans = enabled
        return self
    }


    /// Specifies whether the Network Instrumentation module should be activated and generate spans.
    ///
    /// - Parameter enabled: If `true`, the Network Instrumentation module generates spans.
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func networkInstrumentation(enabled: Bool) -> SplunkRumBuilder {
        networkInstrumentation = enabled
        return self
    }


    /// Network Instrumention can ignore URLs as appropriate
    ///
    /// - Parameter ignoreURLs: A regular expression that resolves to URLs to be ignored during network activity
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func ignoreURLs(ignoreURLs: NSRegularExpression?) -> SplunkRumBuilder {
        self.ignoreURLs = ignoreURLs
        return self
    }


    // MARK: - Build translation method

    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        Use the `SplunkRum.install` API instead.
        """)
    @discardableResult
    public func build() -> Bool {

        // Check the properties required for new AgentConfiguration
        guard let appName = appName else {
            logger.log(level: .error) {
                "Application name must be set."
            }

            return false
        }

        guard let developmentEnvironment = environment else {
            logger.log(level: .error) {
                "Environment must be set."
            }

            return false
        }

        guard let endpointConfiguration = endpointConfiguration else {
            logger.log(level: .error) {
                "Endpoint must be set."
            }

            return false
        }

        // Construct module configurations
        var moduleConfigurations: [ModuleConfiguration] = []

        let navigationModuleConfiguration = SplunkNavigation.NavigationConfiguration(
            isEnabled: screenNameSpans,
            enableAutomatedTracking: showVCInstrumentation
        )

        moduleConfigurations.append(navigationModuleConfiguration)

        let networkModuleConfiguration = SplunkNetwork.NetworkInstrumentationConfiguration(
            isEnabled: networkInstrumentation,
            ignoreURLs: IgnoreURLs(containing: ignoreURLs)
        )

        moduleConfigurations.append(networkModuleConfiguration)

        // Construct AgentConfiguration with the supplied builder properties
        let agentConfiguration = AgentConfiguration(endpoint: endpointConfiguration, appName: appName, deploymentEnvironment: developmentEnvironment)
            .sessionConfiguration(SessionConfiguration(samplingRate: sessionSamplingRatio))
            .enableDebugLogging(debug)

        // Call the `install` method
        do {
            _ = try SplunkRum.install(with: agentConfiguration, moduleConfigurations: moduleConfigurations)
        } catch {
            logger.log(level: .error) {
                "SplunkRum installation failed: \(error)"
            }

            return false
        }

        return true
    }
}
