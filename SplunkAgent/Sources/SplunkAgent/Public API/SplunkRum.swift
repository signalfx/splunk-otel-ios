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

internal import CiscoLogger
internal import CiscoSessionReplay

import Combine
import Foundation
import OpenTelemetryApi

internal import SplunkAppStart
internal import SplunkCommon

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

internal import SplunkNetwork
internal import SplunkOpenTelemetry

internal import SplunkWebView
internal import SplunkWebViewProxy


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

    /// A singleton instance of the Agent library.
    ///
    /// This instance is used to access all SDK functions.
    public static var instance = SplunkRum(
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


    // MARK: - Initialization

    init(configurationHandler: AgentConfigurationHandler, user: AgentUser, session: AgentSession, appStateManager: AgentAppStateManager) {
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


    // MARK: - Agent builder

    /// Creates and initializes the singleton instance.
    ///
    /// - Parameters:
    ///   - configuration: A configuration for the initial SDK setup.
    ///   - moduleConfigurations: An array of individual module-specific configurations.
    ///
    /// - Returns: A newly initialized `SplunkRum` instance.
    public static func install(with configuration: AgentConfiguration, moduleConfigurations: [Any]? = nil) -> SplunkRum {

        // Initialization metrics to be sent in the Initialize span
        let initializeStart = Date()
        var initializeEvents: [String: Date] = [:]

        // Install is allowed only once.
        // ‼️ This condition check ensures that sampling check or platform check are performed only once
        if instance.currentStatus != .notRunning(.notInstalled) {
            return instance
        }

        // We will not continue to initialize additional
        // agent capabilities on unsupported platforms
        guard isSupportedPlatform else {
            instance.currentStatus = .notRunning(.unsupportedPlatform)

            return instance
        }

        // Preparation for sampling
        let sampledOut = false
        if sampledOut {
            instance.currentStatus = .notRunning(.sampledOut)

            instance.logger.log(level: .notice, isPrivate: false) {
                "Agent sampled out."
            }

            return instance
        }

        // Prepare handler for stored configuration and download remote configuration
        let configurationHandler = createConfigurationHandler(for: configuration)

        // Builds agent with default logic
        instance.agentConfigurationHandler = configurationHandler
        instance.currentUser = DefaultUser()
        instance.currentSession = DefaultSession()
        instance.appStateManager = AppStateManager()

        initializeEvents["agent_instance_initialized"] = Date()

        // Links the current session with the agent
        (instance.currentSession as? DefaultSession)?.owner = instance

        // The agent is running, so we set the corresponding status
        instance.currentStatus = .running

        // Initialize Event manager
        instance.eventManager = DefaultEventManager(with: configuration, agent: instance)

        initializeEvents["event_manager_initialized"] = Date()

        // Send session start event immediately as the session already started in the SplunkRum init method.
        instance.eventManager?.sendSessionStartEvent()

        // Starts connecting available modules to agent
        instance.modulesManager = DefaultModulesManager(
            rawConfiguration: configurationHandler.configurationData,
            moduleConfigurations: moduleConfigurations
        )

        // Get WebViewInstrumentation module, set its sharedState
        if let webViewInstrumentationModule = instance.modulesManager?.module(ofType: SplunkWebView.WebViewInstrumentationInternal.self) {
            WebViewInstrumentationInternal.instance.sharedState = instance.sharedState
            instance.logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module installed."
            }
        } else {
            instance.logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module not installed."
            }
        }


        initializeEvents["modules_connected"] = Date()

        // Send events on data publish
        instance.modulesManager?.onModulePublish(data: { metadata, data in
            instance.eventManager?.publish(data: data, metadata: metadata) { success in
                if success {
                    instance.modulesManager?.deleteModuleData(for: metadata)
                } else {
                    // TODO: MRUM_AC-1061 (post GA): Handle a case where data is not sent.
                }
            }
        })

        // Runs module-specific customizations
        instance.customizeModules()

        // Fetch modules initialization times from the Modules manager
        instance.modulesManager?.modulesInitializationTimes.forEach { moduleName, time in
            let moduleName = "\(moduleName)_initialized"
            initializeEvents[moduleName] = time
        }

        initializeEvents["modules_customized"] = Date()

        instance.logger.log(level: .notice, isPrivate: false) {
            "Splunk RUM Agent v\(Self.version)."
        }

        // Report initialize events to App Start module
        if let appStartModule = instance.modulesManager?.module(ofType: SplunkAppStart.AppStart.self) {
            appStartModule.reportAgentInitialize(
                start: initializeStart,
                end: Date(),
                events: initializeEvents,
                configurationSettings: instance.configurationSettings
            )
        }

        return instance
    }


    // MARK: - Modules customization

    /// Perform specific pre-defined customizations for some modules.
    private func customizeModules() {
        customizeCrashReports()
        customizeSessionReplay()
        customizeNetwork()
        customizeAppStart()
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
        var excludedEndpoints: [URL] = [
            agentConfiguration.tracesUrl,
            agentConfiguration.logsUrl,
            agentConfiguration.configUrl
        ]

        if let sessionReplayUrl = agentConfiguration.sessionReplayUrl {
            excludedEndpoints.append(sessionReplayUrl)
        }

        networkModule?.excludedEndpoints = excludedEndpoints
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

    /// Configure App start module
    private func customizeAppStart() {
        let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self)

        appStartModule?.sharedState = sharedState
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

    private var configurationSettings: [String: String] {
        var settings = [String: String]()

        settings["enableDebugLogging"] = String(agentConfigurationHandler.configuration.enableDebugLogging)
        settings["sessionSamplingRate"] = String(agentConfigurationHandler.configuration.sessionSamplingRate)

        if let modulesConfigurations = modulesManager?.modulesConfigurationDescription {
            settings.merge(modulesConfigurations) { $1 }
        }

        return settings
    }


    // MARK: - Version

    /// A version of this agent.
    public static let version = "24.4.1"
}
