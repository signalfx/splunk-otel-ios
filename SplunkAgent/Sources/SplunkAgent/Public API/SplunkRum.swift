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

import Combine
import Foundation
import OpenTelemetryApi


/// The primary class for interacting with the Splunk RUM agent.
///
/// Use the ``shared`` singleton instance to access all agent functionality.
public class SplunkRum: ObservableObject {

    // MARK: - Internal properties

    // Manages the agent's configuration, including remote updates.
    var agentConfigurationHandler: AgentConfigurationHandler

    // The current, effective agent configuration.
    var agentConfiguration: any AgentConfigurationProtocol {
        agentConfigurationHandler.configuration
    }

    // The object representing the current user.
    var currentUser: AgentUser
    // The object representing the current session.
    var currentSession: AgentSession
    // The current operational status of the agent.
    var currentStatus: Status

    // Manages the lifecycle and communication of all agent modules.
    var modulesManager: AgentModulesManager?
    // Manages the processing and export of telemetry events.
    var eventManager: AgentEventManager?

    // Manages the application's state, such as foreground/background transitions.
    var appStateManager: AgentAppStateManager
    // Provides a shared state accessible by various agent components.
    lazy var sharedState: AgentSharedState = DefaultSharedState(for: self)

    // Manages runtime attributes that can change during the agent's lifecycle.
    lazy var runtimeAttributes: AgentRuntimeAttributes = DefaultRuntimeAttributes(for: self)


    // The processor for internal agent logs.
    let logProcessor: LogProcessor
    // The internal logger for the agent.
    let logger: LogAgent

    // The sampler that decides whether a session should be recorded.
    let sessionSampler: any AgentSessionSampler

    // A callback for screen name changes.
    var screenNameChangeCallback: ((String) -> Void)?


    // MARK: - Internal (Modules Proxy)

    // A proxy for the Session Replay module.
    lazy var sessionReplayProxy: any SessionReplayModule = SessionReplayNonOperational()
    // A proxy for the Navigation module.
    lazy var navigationProxy: any NavigationModule = NavigationNonOperational()
    // A proxy for the WebView Instrumentation module.
    lazy var webViewProxy: any WebViewInstrumentationModule = WebViewNonOperational()
    // A proxy for the Custom Tracking module.
    lazy var customTrackingProxy: any CustomTrackingModule = CustomTrackingNonOperational()
    // A proxy for the Interactions module.
    lazy var interactions: any InteractionsModule = InteractionsNonOperational()
    // A proxy for the Slow Frame Detector module.
    lazy var slowFrameDetectorProxy: any SlowFrameDetectorModule = SlowFrameDetectorNonOperational()


    // MARK: - Platform Support

    // A check to determine if the current platform is fully supported.
    private static var isSupportedPlatform: Bool {
        PlatformSupport.current.scope == .full
    }


    // MARK: - Agent singleton

    /// The singleton instance of the RUM agent.
    ///
    /// Use this instance to configure the agent and access all of its features.
    public internal(set) static var shared = SplunkRum(
        configurationHandler: ConfigurationHandlerNonOperational(for: AgentConfiguration.emptyConfiguration),
        user: NoOpUser(),
        session: NoOpSession(),
        appStateManager: NoOpAppStateManager(),
        logPoolName: PackageIdentifier.nonOperationalInstance(),
        sessionSampler: DefaultAgentSessionSampler()
    )


    // MARK: - Public API

    /// An object for managing user-specific information and preferences.
    public private(set) lazy var user = User(for: self)

    /// An object for managing the current user session.
    public private(set) lazy var session = Session(for: self)

    /// A collection of attributes that will be added to all telemetry signals.
    public private(set) lazy var globalAttributes: MutableAttributes = agentConfiguration.globalAttributes

    /// An object that provides read-only access to the agent's current runtime state.
    public private(set) lazy var state = RuntimeState(for: self)

    /// The underlying OpenTelemetry instance used by the agent.
    public var openTelemetry: OpenTelemetry {
        return OpenTelemetry.instance
    }


    // MARK: - Public API (Modules)

    /// The interface for controlling Session Replay recordings.
    public var sessionReplay: any SessionReplayModule {
        sessionReplayProxy
    }

    /// The interface for tracking custom events, errors, and workflows.
    public var customTracking: any CustomTrackingModule {
        customTrackingProxy
    }

    /// The interface for tracking screen navigation events.
    public var navigation: any NavigationModule {
        navigationProxy
    }

    /// The interface for detecting slow and frozen frames.
    public var slowFrameDetector: any SlowFrameDetectorModule {
        slowFrameDetectorProxy
    }

    /// The interface for integrating with browser RUM in a `WKWebView`.
    public var webViewNativeBridge: any WebViewInstrumentationModule {
        webViewProxy
    }


    // MARK: - Agent builder

    /// Initializes and starts the RUM agent with a given configuration.
    ///
    /// This method should be called once, typically in your `AppDelegate`'s `application(_:didFinishLaunchingWithOptions:)` method.
    ///
    /// - Parameters:
    ///   - configuration: The ``AgentConfiguration`` for the agent.
    ///   - moduleConfigurations: An array of module-specific configurations.
    /// - Returns: The initialized `SplunkRum` instance.
    /// - Throws: `AgentConfigurationError` if the provided configuration is invalid.
    ///
    /// ### Example ###
    /// ```
    /// func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     let endpointConfig = EndpointConfiguration(realm: "us0", rumAccessToken: "YOUR_RUM_TOKEN")
    ///     let agentConfig = AgentConfiguration(
    ///         endpoint: endpointConfig,
    ///         appName: "MyAwesomeApp",
    ///         deploymentEnvironment: "production"
    ///     )
    ///
    ///     do {
    ///         _ = try SplunkRum.install(with: agentConfig)
    ///     } catch {
    ///         print("Splunk RUM installation failed: \(error)")
    ///     }
    ///
    ///     return true
    /// }
    /// ```
    public static func install(with configuration: AgentConfiguration, moduleConfigurations: [Any]? = nil) throws -> SplunkRum {

        // Install is allowed only once.
        //
        // ‼️ This condition check implies that other checks (supported platform check, sampling check) are performed only once,
        // and agent's shared instance can't be reinstalled
        guard shared.currentStatus == .notRunning(.notInstalled) else {
            return shared
        }

        // We will not continue to initialize additional
        // agent capabilities on unsupported platforms
        guard isSupportedPlatform else {
            shared.currentStatus = .notRunning(.unsupportedPlatform)

            return shared
        }

        // Re-configure and call the Session Sampler.
        shared.sessionSampler.configure(with: configuration)
        let samplingDecision = shared.sessionSampler.sample()

        // Continue with a noop instance in case of sampling out.
        if samplingDecision == .sampledOut {
            shared.currentStatus = .notRunning(.sampledOut)

            shared.logger.log(level: .notice, isPrivate: false) {
                "Agent sampled out."
            }

            return shared
        }

        // Initialize the full agent if all checks pass
        let agent = try SplunkRum(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        shared = agent

        return agent
    }


    // MARK: - Initialization

    /// Initializes a base `SplunkRum` instance with its core components.
    required init(
        configurationHandler: AgentConfigurationHandler,
        user: AgentUser,
        session: AgentSession,
        appStateManager: AgentAppStateManager,
        logPoolName: String? = nil,
        sessionSampler: AgentSessionSampler
    ) {
        // Pass user configuration
        agentConfigurationHandler = configurationHandler

        // Set current instance status
        currentStatus = .notRunning(.notInstalled)

        // Assign identification
        currentUser = user
        currentSession = session

        let poolName = logPoolName ?? PackageIdentifier.instance()
        let verboseLogging = agentConfigurationHandler.configuration.enableDebugLogging

        // Configure internal logging
        logProcessor = DefaultLogProcessor(
            poolName: poolName,
            subsystem: PackageIdentifier.default
        )
        .verbosity(verboseLogging ? .verbose : .default)

        logger = DefaultLogAgent(poolName: poolName, category: "Agent")

        // Assign AppState manager
        self.appStateManager = appStateManager

        // Assign and configure the session sampler
        self.sessionSampler = sessionSampler
        self.sessionSampler.configure(with: agentConfiguration)

        // Set default screen names
        runtimeAttributes.updateCustom(named: "screen.name", with: "unknown")
    }

    /// Initializes a fully operational `SplunkRum` instance with all modules.
    convenience init(with configuration: AgentConfiguration, moduleConfigurations: [Any]? = nil) throws {

        // Initialization metrics to be sent in the Initialize span
        let initializeStart = Date()
        var initializeEvents: [String: Date] = [:]

        // Validate the configuration
        try configuration.validate()

        // Prepare handler for stored configuration and download remote configuration
        let configurationHandler = Self.createConfigurationHandler(for: configuration)

        // Initialize the agent
        self.init(
            configurationHandler: configurationHandler,
            user: DefaultUser(),
            session: DefaultSession(),
            appStateManager: AppStateManager(),
            sessionSampler: DefaultAgentSessionSampler()
        )

        // Set the configured user tracking mode
        user.preferences.trackingMode = configuration.user.trackingMode

        initializeEvents["agent_instance_initialized"] = Date()

        // Links the current session with the agent
        (currentSession as? DefaultSession)?.owner = self

        // The agent is running, so we set the corresponding status
        currentStatus = .running

        // Initialize Event manager
        eventManager = try DefaultEventManager(with: configuration, agent: self)

        initializeEvents["event_manager_initialized"] = Date()

        // Starts connecting available modules to agent
        modulesManager = DefaultModulesManager(
            rawConfiguration: configurationHandler.configurationData,
            moduleConfigurations: moduleConfigurations
        )

        initializeEvents["modules_connected"] = Date()

        // Register modules' publish callback
        registerModulePublish()

        // Runs module-specific customizations
        customizeModules()

        initializeEvents["modules_customized"] = Date()

        // Report agent's initialization metrics for the app start event
        reportAgentInitialization(start: initializeStart, initializeEvents: initializeEvents)

        logger.log(level: .notice, isPrivate: false) {
            "Splunk RUM Agent v\(Self.version)."
        }
    }


    // MARK: - Configuration handler

    // Creates the appropriate configuration handler based on platform support.
    private static func createConfigurationHandler(for configuration: any AgentConfigurationProtocol) -> AgentConfigurationHandler {
        // If the platform is not fully supported, we use the dummy handler.
        guard isSupportedPlatform else {
            return ConfigurationHandlerNonOperational(for: configuration)
        }

        return SplunkConfigurationHandler(for: configuration)

        // Temporarily commented-out code until O11y implements a proper backend config endpoint.
//        return ConfigurationHandler(
//            for: configuration,
//            apiClient: APIClient(baseUrl: configuration.configUrl)
//        )
    }


    // MARK: - Version

    /// The version of the Splunk RUM agent.
    public static let version = "24.4.1"
}