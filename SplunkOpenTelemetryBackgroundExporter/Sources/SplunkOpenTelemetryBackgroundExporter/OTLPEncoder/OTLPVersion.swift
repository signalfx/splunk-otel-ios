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

// MARK: - OTLP Version

/// OTLP specification version this implementation is based on.
///
/// This implementation follows the OTLP JSON encoding rules which differ from
/// standard protobuf JSON mapping. Key differences include:
/// - `traceId`/`spanId` as lowercase hex strings (not base64)
/// - Enum values as integers (not strings)
/// - 64-bit integers as decimal strings
/// - Binary data as base64 encoded strings
///
/// When updating OTLP version, review the changelog at:
/// https://github.com/open-telemetry/opentelemetry-proto/releases
///
/// Based on OTLP specification v1.9.0.
/// See: https://opentelemetry.io/docs/specs/otlp/
enum OTLPVersion {

    // MARK: - Static Constants

    /// The OTLP specification version this implementation is based on.
    static let version = "1.9.0"

    /// URL to the OTLP specification documentation.
    static let specURL = "https://opentelemetry.io/docs/specs/otlp/"

    /// URL to the OTLP protobuf definitions for this version.
    static let protoURL = "https://github.com/open-telemetry/opentelemetry-proto/tree/v1.9.0"
}
