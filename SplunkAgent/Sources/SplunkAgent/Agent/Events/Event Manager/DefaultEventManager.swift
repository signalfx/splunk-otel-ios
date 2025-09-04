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
internal import CiscoSessionReplay
import Foundation
internal import SplunkCommon
internal import SplunkCustomTracking
internal import SplunkCrashReports
internal import SplunkOpenTelemetry

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

    // Session Replay processor
    var sessionReplayProcessor: LogEventProcessor?
    var sessionReplayIndexer: EventIndexer

    // Trace processor
    var traceProcessor: TraceProcessor

    // Agent reference
    private unowned let agent: SplunkRum

    // Logger
    private var logger: LogAgent {
        agent.logger
    }

    // Automatically repeated events
    private var pulseEventJob: AgentRepeatingJob?


    // MARK: - Initialization

    required init(with configuration: any AgentConfigurationProtocol, agent: SplunkRum) throws {
        guard let traceUrl = configuration.endpoint.traceEndpoint else {
            throw AgentConfigurationError.invalidEndpoint(supplied: configuration.endpoint)
        }

        // ‼️ Using trace endpoint as a placeholder
        let logUrl = traceUrl

        self.agent = agent

        // Will be used later by hybrid agents
        let hybridType: String? = nil

        // Build resources
        let resources = DefaultResources(
            appName: configuration.appName,
            appVersion: configuration.appVersion,
            appBuild: AppInfo.buildId ?? "-",
            appDeploymentEnvironment: configuration.deploymentEnvironment,
            agentHybridType: hybridType,
            agentVersion: SplunkRum.version,
            deviceID: DeviceInfo.deviceID ?? "-",
            deviceModelIdentifier: DeviceInfo.type ?? "-",
            deviceManufacturer: "Apple",
            osName: SystemInfo.name,
            osVersion: SystemInfo.version ?? "-",
            osDescription: SystemInfo.description,
            osType: SystemInfo.type
        )

        // Initialize log event processor
        logEventProcessor = OTLPLogToSpanEventProcessor(
            with: logUrl,
            resources: resources,
            debugEnabled: configuration.enableDebugLogging
        )

        // Initialize session replay processor (optional)
        sessionReplayProcessor = OTLPSessionReplayEventProcessor(
            with: configuration.endpoint.sessionReplayEndpoint,
            resources: resources,
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { agent.globalAttributes.getAll() },
            debugEnabled: configuration.enableDebugLogging
        )

        sessionReplayIndexer = SessionReplayEventIndexer(named: "replay")

        // Initialize trace processor
        traceProcessor = OTLPTraceProcessor(
            with: traceUrl,
            resources: resources,
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { agent.globalAttributes.getAll() },
            debugEnabled: configuration.enableDebugLogging,
            spanInterceptor: configuration.spanInterceptor
        )

        logger.log(level: .info, isPrivate: false) {
            "Using trace url: \(traceUrl)"
        }
    }


    // MARK: - Module Events

    func publish(data: any ModuleEventData, metadata: any ModuleEventMetadata, completion: @escaping (Bool) -> Void) {
        // Create and send an Event based on modules' metadata and data types
        switch (metadata, data) {

        // Session Replay module data
        case let (metadata as Metadata, data as Data):
            publishSessionReplay(data: data, metadata: metadata, completion: completion)

        // Crash Reports module data
        case let (metadata as CrashReportsMetadata, data as String):
            publishCrashReports(data: data, metadata: metadata, completion: completion)

        // Custom Tracking module data
        case let (metadata as CustomTrackingMetadata, data as CustomTrackingData):
            publishCustomTracking(data: data, metadata: metadata, completion: completion)

        // Unknown module data
        default:
            logger.log(level: .error, isPrivate: false) {
                "Missing Event for module published metadata: \(metadata), data: \(data)"
            }

            completion(false)
        }
    }

    private func publishSessionReplay(data: Data, metadata: Metadata, completion: @escaping (Bool) -> Void) {
        guard
            let sessionReplayProcessor,
            let sessionId = agent.session.sessionId(for: metadata.timestamp)
        else {
            completion(false)

            return
        }

        // Prepare and send the event as a separate transaction
        Task {
            guard
                await sessionReplayIndexer.isReady,
                let eventIndex = await prepareSessionReplayIndex(
                    sessionId: sessionId,
                    timestamp: metadata.timestamp
                )
            else {
                completion(false)

                return
            }

            // Use scriptInstanceId as a 16 character substring of a sessionId
            let scriptInstanceId = String(sessionId.prefix(upTo: sessionId.index(sessionId.startIndex, offsetBy: 16)))

            let event = SessionReplayDataEvent(
                metadata: metadata,
                data: data,
                index: eventIndex,
                sessionId: sessionId,
                scriptInstanceId: scriptInstanceId
            )

            sessionReplayProcessor.sendEvent(
                event: event,
                immediateProcessing: false,
                completion: { [weak self] processed in
                    if processed {
                        self?.removeSessionReplayIndex(
                            sessionId: sessionId,
                            timestamp: metadata.timestamp
                        )
                    }

                    completion(processed)
                }
            )
        }
    }

    private func publishCrashReports(data: String, metadata: CrashReportsMetadata, completion: @escaping (Bool) -> Void) {
        let sessionId = agent.session.sessionId(for: metadata.timestamp)
        let event = CrashReportsDataEvent(metadata: metadata, data: data, sessionID: sessionId)

        logEventProcessor.sendEvent(
            event: event,
            immediateProcessing: true,
            completion: completion
        )
    }

    private func publishCustomTracking(data: CustomTrackingData, metadata: CustomTrackingMetadata, completion: @escaping (Bool) -> Void) {
        let sessionId = agent.session.sessionId(for: metadata.timestamp)
        let event = CustomTrackingDataEvent(metadata: metadata, data: data, sessionId: sessionId)

        logEventProcessor.sendEvent(
            event: event,
            immediateProcessing: false,
            completion: completion
        )
    }


    // MARK: - Module utils

    private func prepareSessionReplayIndex(sessionId: String, timestamp: Date) async -> Int? {
        do {
            return try await sessionReplayIndexer.prepareIndex(
                sessionId: sessionId,
                eventTimestamp: timestamp
            )
        } catch {
            logger.log(level: .debug, isPrivate: false) {
                "Preparing the index for the Session Replay event ended with an error: \n\t\(error)"
            }
        }

        return nil
    }

    private func removeSessionReplayIndex(sessionId: String, timestamp: Date) {
        Task {
            do {
                try await sessionReplayIndexer.removeIndex(
                    sessionId: sessionId,
                    eventTimestamp: timestamp
                )
            } catch {
                logger.log(level: .debug, isPrivate: false) {
                    "Removing the index for the Session Replay event ended with an error: \n\t\(error)"
                }
            }
        }
    }
}
