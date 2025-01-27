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
@_implementationOnly import SplunkCrashReports
@_implementationOnly import SplunkLogger
@_implementationOnly import SplunkOpenTelemetry
@_implementationOnly import CiscoSessionReplay
@_implementationOnly import SplunkSharedProtocols

/// Default Event Manager instantiates LogEventProcessor for sending logs, instantiates TraceProcessor for sending traces.
///
/// Default event manager also takes care of sending Session Pulse events, and makes sure Session Start events are not duplicated.
class DefaultEventManager: AgentEventManager {

    // MARK: - Constants

    /// Interval for sending pulse events (5 minutes).
    let pulseEventInterval: TimeInterval = 300


    // MARK: - Private properties

    // Event processor
    var logEventProcessor: LogEventProcessor

    // Trace processor
    var traceProcesssor: TraceProcessor

    // Agent reference
    private unowned let agent: SplunkRum

    // Logger
    private let logger = InternalLogger(configuration: .agent(category: "EventManager"))

    // Events state storage
    let eventsModel: EventsModel

    // Automatically repeated events
    private var pulseEventJob: AgentRepeatingJob?


    // MARK: - Initialization

    required init(with configuration: AgentConfiguration, agent: SplunkRum, eventsModel: EventsModel = EventsModel()) {
        self.agent = agent
        self.eventsModel = eventsModel

        let appName = configuration.appName ?? ""

        let deviceManufacturer = "Apple"

        // Will be used later by hybrid agents
        let hybridType: String? = nil

        let agentVersion = SplunkRum.version

        // Build resources
        let resources = DefaultResources(
            appName: appName,
            appVersion: AppInfo.version ?? "-",
            appBuild: AppInfo.buildId ?? "-",
            agentHybridType: hybridType,
            agentVersion: agentVersion,
            deviceID: DeviceInfo.deviceID ?? "-",
            deviceModelIdentifier: DeviceInfo.type ?? "-",
            deviceManufacturer: deviceManufacturer,
            osName: SystemInfo.name,
            osVersion: SystemInfo.version ?? "-",
            osDescription: SystemInfo.description,
            osType: SystemInfo.type
        )

        // Initialize log event processor
        logEventProcessor = OTLPLogEventProcessor(with: configuration.url, resources: resources)

        // Initialize trace processor
        traceProcesssor = OTLPTraceProcessor(with: configuration.url, resources: resources)

        // Schedule job for Pulse Events
        pulseEventJob = LifecycleRepeatingJob(interval: pulseEventInterval) { [weak self] in
            self?.sendSessionPulseEvent()
        }.resume()

        // Starts listening to a Session Reset nofification to send the Session Start event.
        NotificationCenter.default.addObserver(forName: DefaultSession.sessionDidResetNotification, object: nil, queue: nil) { _ in
            self.sendSessionStartEvent()
        }
    }


    // MARK: - Module Events

    func publish(data: any ModuleEventData, metadata: any ModuleEventMetadata, completion: @escaping (Bool) -> Void) {
        // Create and send an Event based on modules' metadata and data types
        switch (metadata, data) {

        // Session Replay module data
        case let (metadata as Metadata, data as Data):
            let sessionID = agent.session.sessionId(for: metadata.timestamp)
            let event = SessionReplayDataEvent(metadata: metadata, data: data, sessionID: sessionID)

            logEventProcessor.sendEvent(
                event: event,
                immediateProcessing: false,
                completion: completion
            )

        // Crash Reports module data
        case let (metadata as CrashReportsMetadata, data as String):
            let sessionID = agent.session.sessionId(for: metadata.timestamp)
            let event = CrashReportsDataEvent(metadata: metadata, data: data, sessionID: sessionID)

            logEventProcessor.sendEvent(
                event: event,
                immediateProcessing: true,
                completion: completion
            )

        // Unknown module data
        default:
            logger.log(level: .error) {
                "Missing Event for module published metadata: \(metadata), data: \(data)"
            }

            completion(false)
        }
    }


    // MARK: - Session Start event

    func shouldSendSessionStart(_ sessionID: String) -> Bool {
        let sending = eventsModel.isSessionStartSending(sessionID)
        let sent = eventsModel.isSessionStartSent(sessionID)

        return !sending && !sent
    }

    // Sends session replay start event, once per session.
    func sendSessionStartEvent() {
        let sessionItem = agent.currentSession.currentSessionItem
        let sessionID = sessionItem.id
        let timestamp = sessionItem.start

        // Check if the session start event for this session is being sent or was already sent
        guard shouldSendSessionStart(sessionID) else {
            logger.log(level: .info) {
                "Skipping session start event for: \(sessionID)"
            }

            return
        }

        let userID = agent.currentUser.userIdentifier

        let event = SessionStartEvent(
            sessionID: sessionID,
            timestamp: timestamp,
            userID: userID
        )

        // Mark the session start event as "sending"
        eventsModel.markSessionStartSending(sessionID)

        // Send event
        logEventProcessor.sendEvent(event) { success in
            self.logger.log(level: .info) {
                "Session Start event sent with success: \(success)"
            }

            // Mark the session start event as "sent"
            if success {
                self.eventsModel.markSessionStartSent(sessionID)
            }
        }
    }


    // MARK: - Session Pulse event

    func sendSessionPulseEvent() {
        let sessionID = agent.currentSession.currentSessionId
        let timestamp = Date()

        let event = SessionPulseEvent(
            sessionID: sessionID,
            timestamp: timestamp
        )

        logEventProcessor.sendEvent(event) { success in
            self.logger.log(level: .info) {
                "Session Pulse event sent with success: \(success)"
            }
        }
    }
}
