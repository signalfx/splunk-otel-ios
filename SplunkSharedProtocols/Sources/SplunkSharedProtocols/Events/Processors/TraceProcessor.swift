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

/// TraceProcessor processes Spans - enriches them with provided Resources, and sends those events to
/// an exporter.
public protocol TraceProcessor {

    // MARK: - Initialization

    /// Initialize Trace Processor by providing traces API endpoint,
    /// resources, runtime attributes, and a setting to enable debug logging.
    ///
    /// - Parameters:
    ///   - tracesEndpoint: Traces api endpoint.
    ///   - resources: Resources which enrich all Traces.
    ///   - runtimeAttributes: An object that holds and manages runtime attributes.
    ///   - debugEnabled: Enables logging span contents into a console.
    init(with tracesEndpoint: URL, resources: AgentResources, runtimeAttributes: RuntimeAttributes, debugEnabled: Bool)
}
