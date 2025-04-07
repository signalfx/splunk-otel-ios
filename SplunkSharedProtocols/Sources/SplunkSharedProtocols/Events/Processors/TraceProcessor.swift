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

/// TraceProcessor enriches traces by provided Resources, and exports traces to an exporter.
public protocol TraceProcessor {

    // MARK: - Initialization

    /// Initialize Trace Processor by providing API base url and Resources.
    ///
    /// - Parameters:
    ///   - baseURL: API base url.
    ///   - resources: Resources which enrich all Traces.
    init(with baseURL: URL, resources: AgentResources)

    /// Sends Span Event to an exporter.
    ///
    /// - Parameters:
    ///   - event: Event to be sent to exporter.
    ///   - completion: Completion block, returns `true` if the event was sent correctly.
    func sendEvent(event: any Event, completion: @escaping (Bool) -> Void)
}
