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
import OpenTelemetryApi

// MARK: - OTLPTraceId

/// Wrapper for TraceId that encodes as a lowercase hex string in JSON.
///
/// OTLP JSON encoding requires `traceId` to be a case-insensitive hex-encoded
/// string representation of the 16-byte trace identifier. This differs from
/// standard protobuf JSON mapping which uses base64 encoding.
///
/// The hex string is always 32 characters (16 bytes * 2 hex chars per byte).
///
/// Example JSON output: `"5b8efff798038103d269b633813fc60c"` (lowercase hex)
///
/// Based on OTLP specification v1.9.0.
/// See: https://opentelemetry.io/docs/specs/otlp/
struct OTLPTraceId: Encodable {

    // MARK: - Properties

    /// The lowercase hex string representation of the trace ID.
    /// Always 32 characters long.
    let hexString: String


    // MARK: - Initialization

    /// Creates a new OTLPTraceId from an OpenTelemetry TraceId.
    ///
    /// - Parameter traceId: The OpenTelemetry TraceId to convert.
    init(from traceId: TraceId) {
        // Convert to lowercase hex per OTLP JSON spec
        self.hexString = traceId.hexString.lowercased()
    }

    /// Creates a new OTLPTraceId from a hex string.
    ///
    /// - Parameter hexString: The hex string representation (will be lowercased).
    init(hexString: String) {
        self.hexString = hexString.lowercased()
    }


    // MARK: - Encodable

    /// Encodes the trace ID as a lowercase hex string per OTLP JSON specification.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // OTLP JSON requires hex-encoded trace IDs (not base64)
        try container.encode(hexString)
    }
}
