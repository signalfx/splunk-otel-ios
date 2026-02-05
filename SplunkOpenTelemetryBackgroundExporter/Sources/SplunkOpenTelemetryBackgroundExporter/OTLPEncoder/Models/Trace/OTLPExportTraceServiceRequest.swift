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

// MARK: - OTLPExportTraceServiceRequest

/// OTLP ExportTraceServiceRequest - the top-level message for trace export.
///
/// This is the request body sent to the OTLP trace endpoint (`/v1/traces`).
/// It contains a list of ResourceSpans, each representing spans from a
/// single resource.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/collector/trace/v1/trace_service.proto
struct OTLPExportTraceServiceRequest: Encodable {

    // MARK: - Properties

    /// The list of ResourceSpans to export.
    ///
    /// Each ResourceSpans contains spans from a single resource.
    let resourceSpans: [OTLPResourceSpans]
}
