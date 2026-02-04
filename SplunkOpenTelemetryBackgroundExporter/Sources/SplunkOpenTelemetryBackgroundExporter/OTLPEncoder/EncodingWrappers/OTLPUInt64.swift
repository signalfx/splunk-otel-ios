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


// MARK: - OTLPUInt64

/// Wrapper for UInt64 values that encodes as a decimal string in JSON.
///
/// OTLP JSON encoding requires 64-bit unsigned integers to be encoded as
/// decimal strings to avoid precision loss in JavaScript and other environments
/// that use IEEE 754 double-precision floating-point numbers.
///
/// This is commonly used for:
/// - `timeUnixNano` timestamps
/// - `startTimeUnixNano` timestamps
/// - `count` values in metrics
/// - `bucketCounts` in histograms
///
/// Example JSON output: `"1544712660000000000"` (quoted decimal string)
///
/// Based on OTLP specification v1.9.0.
/// See: https://opentelemetry.io/docs/specs/otlp/
struct OTLPUInt64: Encodable {

    // MARK: - Properties

    /// The underlying UInt64 value.
    let value: UInt64


    // MARK: - Initialization

    /// Creates a new OTLPUInt64 wrapper.
    ///
    /// - Parameter value: The UInt64 value to wrap.
    init(_ value: UInt64) {
        self.value = value
    }


    // MARK: - Encodable

    /// Encodes the UInt64 value as a decimal string per OTLP JSON specification.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // OTLP JSON requires 64-bit integers as decimal strings
        try container.encode(String(value))
    }
}
