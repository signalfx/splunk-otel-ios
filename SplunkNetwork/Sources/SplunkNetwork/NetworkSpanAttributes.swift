//
/*
Copyright 2026 Splunk Inc.

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

/// Span attribute keys and values used by network instrumentation that are not covered by
/// OpenTelemetry ``SemanticConventions`` alone.
///
/// Standard HTTP, URL, network, server, and error keys should use ``SemanticConventions`` directly.
enum NetworkSpanAttributes {

    // MARK: - Splunk-specific keys

    /// Splunk RUM component attribute key.
    static let component = "component"

    /// Value for ``component`` on HTTP spans.
    static let componentValueHttp = "http"

    /// Legacy HTTP protocol version attribute (retained for backend compatibility).
    ///
    /// OpenTelemetry stable convention is `network.protocol.version` (``SemanticConventions/Network/protocolVersion``).
    static let httpProtocolVersion = "http.protocol.version"

    /// Trace ID extracted from `Server-Timing` traceparent for span linking.
    static let linkTraceId = "link.traceId"

    /// Span ID extracted from `Server-Timing` traceparent for span linking.
    static let linkSpanId = "link.spanId"

    /// Session identifier shared with other Splunk RUM modules.
    static let sessionId = "session.id"

    /// Indicates the span recorded an error.
    static let error = "error"


    // MARK: - Dynamic header attribute keys

    /// Prefix for captured request header attributes (`http.request.header.<name>`).
    static let requestHeaderPrefix = "http.request.header."

    /// Prefix for captured response header attributes (`http.response.header.<name>`).
    static let responseHeaderPrefix = "http.response.header."

    /// Builds the span attribute key for a captured request header.
    static func requestHeader(_ name: String) -> String {
        requestHeaderPrefix + name
    }

    /// Builds the span attribute key for a captured response header.
    static func responseHeader(_ name: String) -> String {
        responseHeaderPrefix + name
    }
}
