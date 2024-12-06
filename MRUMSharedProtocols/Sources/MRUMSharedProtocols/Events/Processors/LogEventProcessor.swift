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

/// LogEventProcessor processes Events - enriches them with provided Resources, and sends those events to
/// an exporter.
public protocol LogEventProcessor {

    // MARK: - Initialization

    /// Initialise Log Event Processor by providing API base url and resources.
    ///
    /// - Parameters:
    ///   - baseURL: API base url.
    ///   - resources: Resources which enrich all Logs.
    init(with baseURL: URL, resources: AgentResources)


    // MARK: - Events

    /// Sends Log Event to an exporter.
    ///
    /// Implementation should decide whether to send the event synchronously or asynchronously by default.
    ///
    /// - Parameters:
    ///   - event: Event to be sent to exporter.
    ///   - completion: Completion block, returns `true` if the event was sent correctly.
    func sendEvent(_: any Event, completion: @escaping (Bool) -> Void)

    /// Sends Log Event to an exporter.
    ///
    /// Implementation should decide whether to send the event synchronously or asynchronously by default.
    /// Using `immediateProcessing = true`  processes the event synchronously, useful for time critical operations
    /// like sending a crash report.
    ///
    /// - Parameters:
    ///   - event: Event to be sent to exporter.
    ///   - immediateProcessing: `true` processes the event synchronously,
    ///   `false` processes the event on a background thread.
    ///   - completion: Completion block, returns `true` if the event was sent correctly.
    func sendEvent(event: any Event, immediateProcessing: Bool, completion: @escaping (Bool) -> Void)
}
