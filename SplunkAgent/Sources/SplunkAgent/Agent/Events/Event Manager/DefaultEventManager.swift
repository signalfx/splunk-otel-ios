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
internal import SplunkCrashReports
internal import SplunkCustomTracking
internal import SplunkOpenTelemetry

/// Default Event Manager instantiates LogEventProcessor for sending logs, instantiates TraceProcessor for sending traces.
///
/// Default event manager also takes care of sending Session Pulse events, and makes sure Session Start events are not duplicated.
class DefaultEventManager: AgentEventManager {

    // MARK: - Types

    /// Container for event processors.
    struct Processors {
        let logEventProcessor: LogEventProcessor
        let sessionReplayProcessor: LogEventProcessor?
        let traceProcessor: TraceProcessor
    }

    // MARK: - Constants

    /// Interval for sending pulse events (5 minutes).
    let pulseEventInterval: TimeInterval = 300

    // MARK: - Internal properties

    /// Event processor.
    var logEventProcessor: LogEventProcessor

    /// Session Replay processor.
    var sessionReplayProcessor: LogEventProcessor?
    var sessionReplayIndexer: EventIndexer
    var sessionReplayMemorizer: EventMemorizer

    /// Trace processor.
    var traceProcessor: TraceProcessor

    /// Agent reference.
    unowned let agent: SplunkRum

    /// Stored configuration for updating endpoint later.
    var configuration: any AgentConfigurationProtocol

    /// Logger.
    var logger: LogAgent {
        agent.logger
    }

    // MARK: - Initialization

    required init(with configuration: any AgentConfigurationProtocol, agent: SplunkRum) throws {
        self.agent = agent
        self.configuration = configuration
        sessionReplayIndexer = SessionReplayEventIndexer(named: "replay")
        sessionReplayMemorizer = SessionReplayEventMemorizer(named: "replay")

        // Initialize processors based on whether endpoint is available
        if let endpoint = configuration.endpoint,
            let traceUrl = endpoint.traceEndpoint
        {
            // Initialize with real processors
            let processors = Self.createProcessors(
                traceUrl: traceUrl,
                sessionReplayUrl: endpoint.sessionReplayEndpoint,
                accessToken: endpoint.rumAccessToken,
                configuration: configuration,
                agent: agent
            )

            logEventProcessor = processors.logEventProcessor
            sessionReplayProcessor = processors.sessionReplayProcessor
            traceProcessor = processors.traceProcessor

            logger.log(level: .info, isPrivate: false) {
                "Using trace url: \(traceUrl)"
            }
        }
        else if let cachingUrl = Self.cachingUrl {
            // Initialize with caching processors - spans will be cached to disk
            // and sent when an endpoint is configured
            let processors = Self.createProcessors(
                traceUrl: cachingUrl,
                sessionReplayUrl: nil,
                accessToken: nil,
                configuration: configuration,
                agent: agent
            )

            logEventProcessor = processors.logEventProcessor
            sessionReplayProcessor = processors.sessionReplayProcessor
            traceProcessor = processors.traceProcessor

            logger.log(level: .info, isPrivate: false) {
                "No endpoint configured. Spans will be cached and sent when endpoint is configured."
            }
        }
        else {
            // Fallback to NoOp if caching URL is somehow invalid
            logEventProcessor = NoOpLogEventProcessor()
            sessionReplayProcessor = nil
            traceProcessor = NoOpTraceProcessor()

            logger.log(level: .info, isPrivate: false) {
                "No endpoint configured. Spans will not be sent until endpoint is updated."
            }
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

        // Prepare and send `isRecording` event (if was not yet send)
        Task {
            if await sessionReplayMemorizer.isReady {
                await emitSessionReplayRecordingEvent(at: metadata.timestamp, sessionId: sessionId)
            }
        }

        // Prepare and send the event as a separate transaction
        Task {
            guard
                await sessionReplayIndexer.isReady,
                let eventIndex = await prepareSessionReplayIndex(sessionId: sessionId, timestamp: metadata.timestamp)
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
                        self?
                            .removeSessionReplayIndex(
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

    private func emitSessionReplayRecordingEvent(at timestamp: Date, sessionId: String) async {
        do {
            // Send event if it has not yet been sent for this session
            if try await sessionReplayMemorizer.checkAndMarkIfNeeded(eventKey: sessionId) {
                let event = SessionReplayRefreshEvent(
                    timestamp: timestamp,
                    sessionId: sessionId
                )

                agent.eventManager?.sendEvent(event)
            }
        }
        catch {
            logger.log(level: .debug, isPrivate: false) {
                "Failed to check `isRecording` event status for Session Replay (sessionId: \(sessionId)): \(error)"
            }
        }
    }


    // MARK: - Internal events

    func sendEvent(_ event: AgentEvent) {
        logEventProcessor.sendEvent(
            event: event,
            immediateProcessing: false
        ) { _ in }
    }
}


// MARK: - Session Replay Utils

extension DefaultEventManager {

    func prepareSessionReplayIndex(sessionId: String, timestamp: Date) async -> Int? {
        do {
            return try await sessionReplayIndexer.prepareIndex(
                sessionId: sessionId,
                eventTimestamp: timestamp
            )
        }
        catch {
            logger.log(level: .debug, isPrivate: false) {
                "Preparing the index for the Session Replay event ended with an error: \(error)"
            }
        }

        return nil
    }

    func removeSessionReplayIndex(sessionId: String, timestamp: Date) {
        Task {
            do {
                try await sessionReplayIndexer.removeIndex(
                    sessionId: sessionId,
                    eventTimestamp: timestamp
                )
            }
            catch {
                logger.log(level: .debug, isPrivate: false) {
                    "Removing the index for the Session Replay event ended with an error: \(error)"
                }
            }
        }
    }
}
