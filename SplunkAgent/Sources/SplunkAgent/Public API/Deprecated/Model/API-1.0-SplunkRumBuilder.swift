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
internal import SplunkSlowFrameDetector

import Foundation

/// A deprecated builder for initializing the RUM agent.
@available(*, deprecated, message:
    """
    The SplunkRumBuilder class is no longer supported and will be removed in a later version.
    Use the `SplunkRum.install` API instead.
    """)
public class SplunkRumBuilder {

    // MARK: - Configuration properties

    // The beacon URL for sending trace data.
    private var beaconUrl: String
    // The RUM authentication token.
    private var rumAuth: String
    // A flag to enable or disable debug logging.
    private var debug: Bool = false
    // The deployment environment string.
    private var environment: String?
    // The session sampling ratio, from 0.0 to 1.0.
    private var sessionSamplingRatio: Double = ConfigurationDefaults.sessionSamplingRate
    // The name of the application.
    private var appName: String?
    // A dictionary of global attributes.
    private var globalAttributes: [String: Any]?
    // The modern endpoint configuration object.
    private var endpointConfiguration: EndpointConfiguration?


    // MARK: - Instrumentations properties

    // A flag to enable or disable screen name spans.
    private var screenNameSpans: Bool = true
    // A flag to enable or disable automatic view controller instrumentation.
    private var showVCInstrumentation: Bool = false
    // A flag to enable or disable slow rendering detection.
    private var slowRenderingDetectionEnabled: Bool = true
    // A flag to enable or disable network instrumentation.
    private var networkInstrumentation: Bool = true
    // A regex for URLs to ignore in network instrumentation.
    private var ignoreURLs: NSRegularExpression?


    // MARK: - Logging

    // The internal logger for the builder.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkRumBuilder")


    // MARK: - Builder initialization

    /// Initializes the builder with a beacon URL and RUM authentication token.
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

    /// Initializes the builder with a realm and RUM authentication token.
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

    /// Enables or disables debug logging.
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

    /// Sets the deployment environment.
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

    /// Sets the session sampling ratio.
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

    /// Sets the application name.
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

    /// This method is a no-op and has no effect.
    @available(*, deprecated, message:
        """
        This builder method is a no-op and will be removed in a later version.
        """)
    @discardableResult
    public func enableDiskCache(enabled: Bool) -> SplunkRumBuilder {
        return self
    }

    /// Sets global attributes to be included in all spans.
    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version.
        """)
    @discardableResult
    public func globalAttributes(globalAttributes: [String: Any]) -> SplunkRumBuilder {
        self.globalAttributes = globalAttributes
        return self
    }


    // MARK: - Instrumentations builder methods

    /// Enables or disables automatic tracking of view controller appearances.
    ///
    /// - Parameter show: If `true`, the Navigation module will automatically track view controllers.
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


    /// Enables or disables the creation of screen name spans.
    ///
    /// - Parameter enabled: If `true`, the Navigation module generates screen name spans.
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func screenNameSpans(enabled: Bool) -> SplunkRumBuilder {
        screenNameSpans = enabled
        return self
    }

    /// Enables or disables slow and frozen frame detection.
    ///
    /// - Parameter isEnabled: If `true`, the agent will detect and report slow and frozen frames.
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    public func slowRenderingDetectionEnabled(_ isEnabled: Bool) -> SplunkRumBuilder {
        slowRenderingDetectionEnabled = isEnabled
        return self
    }

    /// This method is a no-op and has no effect. Thresholds are now managed automatically.
    ///
    /// - Parameter thresholdMs: This parameter is ignored.
    /// - Returns: The builder instance to allow for continued chaining.
    @available(*, deprecated, message: "This configuration has been discontinued and has no effect. Thresholds are now managed automatically.")
    @discardableResult
    public func slowFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        // This method is intentionally empty as the feature is discontinued.
        // We return 'self' to allow for continued builder chaining.
        return self
    }

    /// This method is a no-op and has no effect. Thresholds are now managed automatically.
    ///
    /// - Parameter thresholdMs: This parameter is ignored.
    /// - Returns: The builder instance to allow for continued chaining.
    @available(*, deprecated, message: "This configuration has been discontinued and has no effect. Thresholds are now managed automatically.")
    @discardableResult
    public func frozenFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        // Intentionally empty.
        // We return 'self' to allow for continued builder chaining.
        return self
    }

    /// Enables or disables network instrumentation.
    ///
    /// - Parameter enabled: If `true`, the agent will automatically instrument network requests.
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func networkInstrumentation(_ enabled: Bool) -> SplunkRumBuilder {
        networkInstrumentation = enabled
        return self
    }


    /// Sets a regular expression to exclude certain URLs from network instrumentation.
    ///
    /// - Parameter ignoreURLs: A regular expression matching URLs to be ignored.
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version.")
    @discardableResult
    public func ignoreURLs(_ ignoreURLs: NSRegularExpression?) -> SplunkRumBuilder {
        self.ignoreURLs = ignoreURLs
        return self
    }


    // MARK: - Build translation method

    /// Translates the builder settings into the modern configuration and initializes the RUM agent.
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

        // Navigation
        let navigationModuleConfiguration = SplunkNavigation.NavigationConfiguration(
            isEnabled: screenNameSpans,
            enableAutomatedTracking: showVCInstrumentation
        )
        moduleConfigurations.append(navigationModuleConfiguration)

        // SlowFrameDetector
        let slowFrameDetectorConfiguration = SlowFrameDetectorConfiguration(
            isEnabled: slowRenderingDetectionEnabled
        )
        moduleConfigurations.append(slowFrameDetectorConfiguration)

        // Network
        let networkModuleConfiguration = SplunkNetwork.NetworkInstrumentationConfiguration(
            isEnabled: networkInstrumentation,
            ignoreURLs: IgnoreURLs(containing: ignoreURLs)
        )
        moduleConfigurations.append(networkModuleConfiguration)

        // Construct global attributes
        let attributes: MutableAttributes
        if let globalAttributes = globalAttributes {
            attributes = MutableAttributes(from: globalAttributes)
        } else {
            attributes = MutableAttributes()
        }

        // Construct AgentConfiguration with the supplied builder properties
        let agentConfiguration = AgentConfiguration(endpoint: endpointConfiguration, appName: appName, deploymentEnvironment: developmentEnvironment)
            .sessionConfiguration(SessionConfiguration(samplingRate: sessionSamplingRatio))
            .globalAttributes(attributes)
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