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

import Foundation

/// Defines an interface for processing and exporting log events.
public protocol LogEventProcessor {

    // MARK: - Events

    /// Sends a log event to an exporter.
    ///
    /// The default processing strategy (e.g., synchronous or asynchronous) is determined by the conforming type.
    ///
    /// - Parameters:
    ///   - Parameter: The event to be sent to the exporter.
    ///   - completion: A closure called after processing is attempted. Returns `true` on success.
    func sendEvent(_: any AgentEvent, completion: @escaping (Bool) -> Void)

    /// Sends a log event to an exporter with a specific processing requirement.
    ///
    /// Using `immediateProcessing = true` forces synchronous processing, which is useful for time-critical operations
    /// like sending a crash report.
    ///
    /// - Parameters:
    ///   - event: The event to be sent to the exporter.
    ///   - immediateProcessing: If `true`, the event is processed synchronously. If `false`, the event may be
    ///   processed asynchronously.
    ///   - completion: A closure called after processing is attempted. Returns `true` on success.
    func sendEvent(event: any AgentEvent, immediateProcessing: Bool, completion: @escaping (Bool) -> Void)
}
