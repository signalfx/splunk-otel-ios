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


    // MARK: - Internal (Modules Proxy)

    lazy var sessionReplayProxy: any SessionReplayModule = SessionReplayNonOperational()


    // MARK: - Platform Support

    private static var isSupportedPlatform: Bool {
        PlatformSupport.current.scope == .full
    }


    // MARK: - Agent singleton

    /// A singleton shared instance of the Agent library.
    ///
    /// This shared instance is used to access all SDK functions.
    public private(set) static var shared = SplunkRum(
        configurationHandler: ConfigurationHandlerNonOperational(for: AgentConfiguration.emptyConfiguration),
        user: NoOpUser(),
        session: NoOpSession(),
        appStateManager: NoOpAppStateManager()
    )


    // MARK: - Public API

    /// An object that holds current user.
    public private(set) lazy var user = User(for: self)

    /// An object that holds current manages associated session.
    public private(set) lazy var session = Session(for: self)

    /// An object reflects the current state and setting used for the recording.
    public private(set) lazy var state = RuntimeState(for: self)

    /// OpenTelemetry instance.
    public var openTelemetry: OpenTelemetry {
        return OpenTelemetry.instance
    }


    // MARK: - Public API (Modules)

    /// An object that holds session replay module.
    public var sessionReplay: any SessionReplayModule {
        sessionReplayProxy
    }


    // MARK: - Agent builder

    /// Creates and initializes the singleton instance.
    ///
    /// - Parameters:
    ///   - configuration: A configuration for the initial SDK setup.
    ///   - moduleConfigurations: An array of individual module-specific configurations.
    ///
    /// - Returns: A newly initialized `SplunkRum` instance.
    ///
    /// - Throws: `AgentConfigurationError` if provided configuration is invalid.
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

        // Preparation for sampling check
        let sampledOut = false
        if sampledOut {
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

    required init(configurationHandler: AgentConfigurationHandler, user: AgentUser, session: AgentSession, appStateManager: AgentAppStateManager) {
        // Pass user configuration
        agentConfigurationHandler = configurationHandler

        // Set current instance status
        currentStatus = .notRunning(.notInstalled)

        // Assign identification
        currentUser = user
        currentSession = session

        let logPoolName = PackageIdentifier.instance()
        let verboseLogging = agentConfigurationHandler.configuration.enableDebugLogging

        // Configure internal logging
        logProcessor = DefaultLogProcessor(
            poolName: logPoolName,
            subsystem: PackageIdentifier.default
        )
        .verbosity(verboseLogging ? .verbose : .default)

        logger = DefaultLogAgent(poolName: logPoolName, category: "Agent")

        // Assign AppState manager
        self.appStateManager = appStateManager
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
            appStateManager: AppStateManager()
        )

        initializeEvents["agent_instance_initialized"] = Date()

        // Links the current session with the agent
        (currentSession as? DefaultSession)?.owner = self

        // The agent is running, so we set the corresponding status
        currentStatus = .running

        // Initialize Event manager
        eventManager = try DefaultEventManager(with: configuration, agent: self)

        initializeEvents["event_manager_initialized"] = Date()

        // Send session start event immediately as the session already started in the SplunkRum init method.
        eventManager?.sendSessionStartEvent()

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

    /// A version of this agent.
    public static let version = "24.4.1"
}
