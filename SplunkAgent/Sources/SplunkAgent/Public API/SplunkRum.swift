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
import Combine
import Foundation
import OpenTelemetryApi
internal import SplunkCommon

/// The class implementing Splunk Agent public API.
public class SplunkRum: ObservableObject {

    // MARK: - Internal properties

    var agentConfigurationHandler: AgentConfigurationHandler

    var agentConfiguration: any AgentConfigurationProtocol {
        agentConfigurationHandler.configuration
    }

    var currentUser: AgentUser
    var currentSession: AgentSession
    var currentStatus: Status

    var modulesManager: AgentModulesManager?
    var eventManager: AgentEventManager?

    var appStateManager: AgentAppStateManager
    lazy var sharedState: AgentSharedState = DefaultSharedState(for: self)

    lazy var runtimeAttributes: AgentRuntimeAttributes = DefaultRuntimeAttributes(for: self)


    let logProcessor: LogProcessor
    let logger: LogAgent

    let sessionSampler: any AgentSessionSampler

    var screenNameChangeCallback: ((String) -> Void)?


    // MARK: - Internal (Modules Proxy)

    lazy var sessionReplayProxy: any SessionReplayModule = SessionReplayNonOperational()
    lazy var navigationProxy: any NavigationModule = NavigationNonOperational()
    lazy var webViewProxy: any WebViewInstrumentationModule = WebViewNonOperational()
    lazy var customTrackingProxy: any CustomTrackingModule = CustomTrackingNonOperational()
    lazy var interactions: any InteractionsModule = InteractionsNonOperational()
    lazy var slowFrameDetectorProxy: any SlowFrameDetectorModule = SlowFrameDetectorNonOperational()
    lazy var appStartProxy: any AppStartModule = AppStartNonOperational()


    // MARK: - Platform Support

    private static var isSupportedPlatform: Bool {
        PlatformSupport.current.scope == .full
    }


    // MARK: - Agent singleton

    /// A singleton shared instance of the Agent library.
    ///
    /// This shared instance is used to access all SDK functions.
    public internal(set) static var shared = SplunkRum(
        configurationHandler: ConfigurationHandlerNonOperational(for: AgentConfiguration.emptyConfiguration),
        user: NoOpUser(),
        session: NoOpSession(),
        appStateManager: NoOpAppStateManager(),
        logPoolName: PackageIdentifier.nonOperationalInstance(),
        sessionSampler: DefaultAgentSessionSampler()
    )


    // MARK: - Public API

    /// An object that holds the current ``User``.
    public private(set) lazy var user = User(for: self)

    /// An object that manages the associated ``Session``.
    public private(set) lazy var session = Session(for: self)

    /// An object that contains global attributes (a ``MutableAttributes`` instance) added to all signals.
    public private(set) lazy var globalAttributes: MutableAttributes = agentConfiguration.globalAttributes

    /// An object that reflects the current state and settings used for the recording (a ``RuntimeState`` instance).
    public private(set) lazy var state = RuntimeState(for: self)

    /// OpenTelemetry instance.
    public var openTelemetry: OpenTelemetry {
        OpenTelemetry.instance
    }


    // MARK: - Public API (Modules)

    /// An object that holds the ``SessionReplayModule``.
    public var sessionReplay: any SessionReplayModule {
        sessionReplayProxy
    }

    /// An object that holds the ``CustomTrackingModule``.
    public var customTracking: any CustomTrackingModule {
        customTrackingProxy
    }

    /// An object that holds the ``NavigationModule``.
    public var navigation: any NavigationModule {
        navigationProxy
    }

    /// An object that holds the ``SlowFrameDetectorModule``.
    public var slowFrameDetector: any SlowFrameDetectorModule {
        slowFrameDetectorProxy
    }

    /// An object that holds the ``AppStartModule``.
    ///
    /// - Warning: Internal use only.
    @_spi(SplunkInternal)
    public var appStart: any AppStartModule {
        appStartProxy
    }

    /// An object that provides a bridge for WebView instrumentation (a ``WebViewInstrumentationModule`` instance).
    public var webViewNativeBridge: any WebViewInstrumentationModule {
        webViewProxy
    }


    // MARK: - Agent builder

    /// Creates and initializes the singleton instance.
    ///
    /// - Parameters:
    ///   - configuration: An ``AgentConfiguration`` for the initial SDK setup.
    ///   - moduleConfigurations: An array of individual module-specific configurations.
    ///
    /// - Returns: A newly initialized ``SplunkRum`` instance.
    ///
    /// - Throws: ``AgentConfigurationError`` if provided configuration is invalid.
    public static func install(with configuration: AgentConfiguration, moduleConfigurations: [Any]? = nil) throws -> SplunkRum {

        // Install is allowed only once
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

            shared.logger.log(level: .notice, isPrivate: false) {
                "\(CompileInfo.platform) is not supported, Agent will not start."
            }

            return shared
        }

        // Re-configure and call the Session Sampler
        shared.sessionSampler.configure(with: configuration)
        let samplingDecision = shared.sessionSampler.sample()

        // Continue with a noop instance in case of sampling out
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

        // Send a session start event explicitly as soon as a Session and an EventManager are available
        (currentSession as? DefaultSession)?.sendInitialSessionStartEvent()

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

    private static func createConfigurationHandler(for configuration: any AgentConfigurationProtocol) -> AgentConfigurationHandler {
        // If the platform is not fully supported, we use the dummy handler
        guard isSupportedPlatform else {
            return ConfigurationHandlerNonOperational(for: configuration)
        }

        return SplunkConfigurationHandler(for: configuration)

        // Temporarily commented-out code until O11y implements a proper backend config endpoint
        //        return ConfigurationHandler(
        //            for: configuration,
        //            apiClient: APIClient(baseUrl: configuration.configUrl)
        //        )
    }


    // MARK: - Version

    /// A version of this agent.
    public static let version = "2.0.5"
}
