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
@_implementationOnly import SplunkSharedProtocols

/// Event manager publishes Module data, sends other events to exporters.
///
/// Event manager provides communication channels for sending Logs, Traces and other events.
/// Event manager is also responsible for all signals being enriched by required metadata.
protocol AgentEventManager {

    // MARK: - Private properties

    /// Event processor to process Logs and Events.
    var logEventProcessor: LogEventProcessor { get }

    /// Trace processor to process Traces.
    var traceProcesssor: TraceProcessor { get }


    // MARK: - Initialization

    /// Initializes the Event Manager using the supplied Agent Configuration.
    ///
    /// - Parameters:
    ///   - configuration: Agent Configuration object.
    ///   - agent: Agent object, used to obtain Session information and User information.
    ///   - eventsModel: Events model object to store persisted events metadata.
    init(with configuration: AgentConfiguration, agent: SplunkRum, eventsModel: EventsModel)


    // MARK: - Module Events

    /// Sends data from any Module to backend. If a new module wants to send data,
    /// this method needs additional implementation with corresponding module Data and module Metadata types.
    ///
    ///  - Parameters:
    ///    - data: Module event data.
    ///    - metadata: Module event metadata.
    ///    - completion: Completion block, returns `true` if the data was processed and sent correctly.
    func publish(data: any ModuleEventData, metadata: any ModuleEventMetadata, completion: @escaping (Bool) -> Void)


    // MARK: - Session Start event

    /// Sends session replay start event.
    func sendSessionStartEvent()


    // MARK: - Session Pulse event

    /// Sends session replay pulse event.
    func sendSessionPulseEvent()
}
