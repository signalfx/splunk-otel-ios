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

import Combine
import Foundation


#if canImport(SplunkCrashReports)
    @_implementationOnly import SplunkCrashReports
#endif
@_implementationOnly import SplunkLogger
@_implementationOnly import SplunkNetwork
@_implementationOnly import SplunkOpenTelemetry
@_implementationOnly import CiscoSessionReplay
@_implementationOnly import SplunkSharedProtocols

/// The class implementing Splunk Agent public API.
public class SplunkRum: ObservableObject {

    // MARK: - Internal properties

    let agentConfigurationHandler: AgentConfigurationHandler

    var agentConfiguration: AgentConfiguration {
        agentConfigurationHandler.configuration
    }

    var currentUser: AgentUser
    var currentSession: AgentSession
    var currentStatus: Status

    var modulesManager: AgentModulesManager?
    var eventManager: AgentEventManager?

    let appStateManager: AgentAppStateManager
    lazy var sharedState: AgentSharedState = DefaultSharedState(for: self)

    let logger = InternalLogger(configuration: .default(subsystem: "Splunk RUM Agent"))


    // MARK: - Internal (Modules Proxy)

    lazy var sessionReplayProxy: any SessionReplayModule = SessionReplayNonOperational()


    // MARK: - Platform Support

    private static var isSupportedPlatform: Bool {
        PlatformSupport.current.scope == .full
    }


    // MARK: - Agent singleton

    /// An singleton instance of the Agent library.
    ///
    /// This instance is used to access all the SDK functions.
    public private(set) static var instance: SplunkRum?


    // MARK: - Public API

    /// An object that holds current user.
    public private(set) lazy var user = User(for: self)

    /// An object that holds current manages associated session.
    public private(set) lazy var session = Session(for: self)

    /// An object reflects the current state and setting used for the recording.
    public private(set) lazy var state = RuntimeState(for: self)

    // MARK: - Public API (Modules)

    /// An object that holds session replay module.
    public var sessionReplay: any SessionReplayModule {
        sessionReplayProxy
    }


    // MARK: - Initialization

    init(configurationHandler: AgentConfigurationHandler, user: AgentUser, session: AgentSession, appStateManager: AgentAppStateManager) {
        // Pass user configuration
        agentConfigurationHandler = configurationHandler

        // Set current instance status
        currentStatus = .notRunning(.notEnabled)

        // Assign identification
        currentUser = user
        currentSession = session

        // Assign AppState manager
        self.appStateManager = appStateManager
    }


    // MARK: - Agent builder

    /// Creates and initializes the singleton instance.
    ///
    /// - Parameters:
    ///   - configuration: A configuration for the initial SDK setup.
    ///   - moduleConfigurations: An array of individual module-specific configurations.
    ///
    /// - Returns: A newly initialized `SplunkRum` instance.
    public static func install(with configuration: Configuration, moduleConfigurations: [Any]? = nil) -> SplunkRum {
        // Only one instance is allowed
        if let sharedInstance = instance {
            return sharedInstance
        }

        // Prepare handler for stored configuration and download remote configuration
        let configurationHandler = createConfigurationHandler(for: configuration)

        // Builds agent with default logic
        let agent = SplunkRum(
            configurationHandler: configurationHandler,
            user: DefaultUser(),
            session: DefaultSession(),
            appStateManager: AppStateManager()
        )
        instance = agent


        // We will not continue to initialize additional
        // agent capabilities on unsupported platforms
        guard isSupportedPlatform else {
            agent.currentStatus = .notRunning(.unsupportedPlatform)

            return agent
        }

        // Links the current session with the agent
        (agent.currentSession as? DefaultSession)?.owner = agent

        // The agent is running, so we set the corresponding status
        agent.currentStatus = .running

        // Initialize Event manager
        agent.eventManager = DefaultEventManager(with: configuration, agent: agent)

        // Send session start event immediately as the session already started in the SplunkRum init method.
        agent.eventManager?.sendSessionStartEvent()

        // Starts connecting available modules to agent
        agent.modulesManager = DefaultModulesManager(
            rawConfiguration: configurationHandler.configurationData,
            moduleConfigurations: moduleConfigurations
        )

        // Send events on data publish
        agent.modulesManager?.onModulePublish(data: { metadata, data in
            agent.eventManager?.publish(data: data, metadata: metadata) { success in
                if success {
                    agent.modulesManager?.deleteModuleData(for: metadata)
                } else {
                    // TODO: MRUM_AC-1061 (post GA): Handle a case where data is not sent.
                }
            }
        })

        // Runs module-specific customizations
        agent.customizeModules()

        agent.logger.log {
            "Splunk RUM Agent v\(Self.version)."
        }

        return agent
    }

    private static func createConfigurationHandler(for configuration: AgentConfiguration) -> AgentConfigurationHandler {
        // If the platform is not fully supported, we use the dummy handler.
        guard isSupportedPlatform else {
            return ConfigurationHandlerNonOperational(for: configuration)
        }

        return ConfigurationHandler(
            for: configuration,
            apiClient: APIClient(baseUrl: configuration.url)
        )
    }


    // MARK: - Modules customization

    /// Perform specific pre-defined customizations for some modules.
    private func customizeModules() {
        customizeCrashReports()
        customizeSessionReplay()
        customizeNetwork()
    }

    /// Perform operations specific to the SessionReplay module.
    private func customizeSessionReplay() {
        let moduleType = CiscoSessionReplay.SessionReplay.self
        let sessionReplayModule = modulesManager?.module(ofType: moduleType)

        guard let sessionReplayModule else {
            return
        }

        // Initialize proxy API for this module
        sessionReplayProxy = SessionReplay(for: sessionReplayModule)
    }

    /// Configure Network module with shared state.
    private func customizeNetwork() {
        let networkModule = modulesManager?.module(ofType: SplunkNetwork.NetworkInstrumentation.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `sessionID` from the agent continuously.
        networkModule?.sharedState = sharedState

        // We need the endpoint url to manage trace exclusion logic
        networkModule?.traceEndpointURL = agentConfiguration.url
    }

    /// Configure Crash Reports module with shared state.
    private func customizeCrashReports() {
    // swiftformat:disable indent
    #if canImport(SplunkCrashReports)
        let crashReportsModule = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `appState` from the agent in the instance of a crash.
        crashReportsModule?.sharedState = sharedState

        // Check if a crash ended the previous run of the app
        crashReportsModule?.reportCrashIfPresent()
    #endif
    // swiftformat:enable indent
    }


    // MARK: - Version

    /// A version of this agent.
    public static let version = "24.4.1"
}
