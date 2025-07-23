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
    Use the `SplunkRum.install(with:moduleConfigurations:)` API instead.
    """)
public class SplunkRumBuilder {

    // MARK: - Configuration properties

    private var beaconUrl: String
    private var rumAuth: String
    private var debug: Bool = false
    private var environment: String?
    private var sessionSamplingRatio: Double = ConfigurationDefaults.sessionSamplingRate
    private var appName: String?
    private var globalAttributes: [String: Any]?

    private var endpointConfiguration: EndpointConfiguration?


    // MARK: - Instrumentations properties

    private var screenNameSpans: Bool = true
    private var showVCInstrumentation: Bool = false
    private var slowRenderingDetectionEnabled: Bool = true
    private var networkInstrumentation: Bool = true
    private var ignoreURLs: NSRegularExpression?


    // MARK: - Logging

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkRumBuilder")


    // MARK: - Builder initialization

    /// Initializes the builder with a beacon URL and RUM authentication token.
    @available(*, deprecated, message:
        """
        This initializer will be removed in a later version.
        Use the `SplunkRum.install(with:moduleConfigurations:)` API instead.
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
        Use the `SplunkRum.install(with:moduleConfigurations:)` API instead.
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
        Use `AgentConfiguration` `enableDebugLogging` instead.
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
        Use `AgentConfiguration` `deploymentEnvironment` instead.
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
        Use `AgentConfiguration` `SessionConfiguration` instead.
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
        Use `AgentConfiguration` `appName` instead.
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
        Use `AgentConfiguration` `MutableAttributes` instead.
        """)
    @discardableResult
    public func globalAttributes(globalAttributes: [String: Any]) -> SplunkRumBuilder {
        self.globalAttributes = globalAttributes
        return self
    }


    
    // MARK: - Instrumentations builder methods


    /// Sets whether or not the Navigation module should automatically detect navigation in the application.
    ///
    /// - Parameter show: If `true`, the Navigation module will automatically detect navigation.
    /// - Returns: The updated builder instance.
    /// - Note: Deprecated. Use `NavigationModulePreferences.enableAutomatedTracking` instead.
    @available(*, deprecated, message:
        """
        This builder method will be removed in a later version. Use `NavigationModulePreferences.enableAutomatedTracking` instead.
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
    @available(*, deprecated, message: "This builder method will be removed in a later version. Use the `NavigationModule` configuration instead.")
    @discardableResult
    public func screenNameSpans(enabled: Bool) -> SplunkRumBuilder {
        screenNameSpans = enabled
        return self
    }

    /// Specifies whether the SlowFrameDetection should be activated and generate slow frame detection spans.
    ///
    /// - Parameter enabled: If `true`, the SlowFrameDetection module generates slow frame detection spans.
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version. Use the `SlowFrameDetectorModule` configuration instead.")
    public func slowRenderingDetectionEnabled(_ isEnabled: Bool) -> SplunkRumBuilder {
        slowRenderingDetectionEnabled = isEnabled
        return self
    }

    /// Specifies the legacy threshold for slow frame detection. This setting is now ignored.
    ///
    /// - Parameter thresholdMs: The legacy threshold in milliseconds. This value is not used.
    ///
    /// - Returns: The builder instance to allow for continued chaining.
    @available(*, deprecated, message: "This configuration has been discontinued and has no effect. Thresholds are now managed automatically.")
    @discardableResult
    public func slowFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        // This method is intentionally empty as the feature is discontinued.
        // We return 'self' to allow for continued builder chaining.
        return self
    }

    /// Specifies the legacy threshold for frozen frame detection. This setting is now ignored.
    ///
    /// - Parameter thresholdMs: The legacy threshold in milliseconds. This value is not used.
    ///
    /// - Returns: The builder instance to allow for continued chaining.
    @available(*, deprecated, message: "This configuration has been discontinued and has no effect. Thresholds are now managed automatically.")
    @discardableResult
    public func frozenFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        // Intentionally empty.
        // We return 'self' to allow for continued builder chaining.
        return self
    }

    /// Specifies whether the Network Instrumentation module should be activated and generate spans.
    ///
    /// - Parameter enabled: If `true`, the Network Instrumentation module generates spans.
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version. Use the `NetworkInstrumentationModule` configuration instead.")
    @discardableResult
    public func networkInstrumentation(_ enabled: Bool) -> SplunkRumBuilder {
        networkInstrumentation = enabled
        return self
    }


    /// Network Instrumention can ignore URLs as appropriate
    ///
    /// - Parameter ignoreURLs: A regular expression that resolves to URLs to be ignored during network activity
    ///
    /// - Returns: The updated builder instance.
    @available(*, deprecated, message: "This builder method will be removed in a later version. Use the `NetworkInstrumentationConfiguration` instead.")
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
        Use the `SplunkRum.install(with:moduleConfigurations:)` API instead.
        """)
    @discardableResult
    public func build() -> Bool {

        // Check the properties required for new ``AgentConfiguration``
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

        // Construct ``AgentConfiguration`` with the supplied builder properties
        let agentConfiguration = AgentConfiguration(endpoint: endpointConfiguration, appName: appName, deploymentEnvironment: developmentEnvironment)
            .sessionConfiguration(SessionConfiguration(samplingRate: sessionSamplingRatio))
            .globalAttributes(attributes)
            .enableDebugLogging(debug)

        // Call the ``SplunkRum.install(with:moduleConfigurations:)`` method
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
