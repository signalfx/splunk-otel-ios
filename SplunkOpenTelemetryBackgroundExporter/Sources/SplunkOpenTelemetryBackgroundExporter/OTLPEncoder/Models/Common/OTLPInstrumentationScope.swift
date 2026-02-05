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

// MARK: - OTLPInstrumentationScope

/// OTLP InstrumentationScope model.
///
/// InstrumentationScope represents the instrumentation library or component
/// that produced the telemetry data. It includes the library name, version,
/// and optional attributes.
///
/// Note: The `schemaUrl` field is NOT on this model - it's on the parent
/// container types (ScopeSpans, ScopeLogs, ScopeMetrics).
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/common/v1/common.proto
struct OTLPInstrumentationScope: Encodable {

    // MARK: - Properties

    /// The name of the instrumentation scope (e.g., library name).
    let name: String

    /// The version of the instrumentation scope.
    let version: String?

    /// Additional attributes describing this scope.
    let attributes: [OTLPKeyValue]?

    /// The number of attributes that were dropped due to limits.
    ///
    /// Only encoded if greater than 0.
    let droppedAttributesCount: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case name
        case version
        case attributes
        case droppedAttributesCount
    }


    // MARK: - Initialization

    /// Creates a new instrumentation scope.
    ///
    /// - Parameters:
    ///   - name: The name of the instrumentation scope.
    ///   - version: The version of the instrumentation scope.
    ///   - attributes: Additional attributes describing this scope.
    ///   - droppedAttributesCount: The number of dropped attributes (nil or 0 means none).
    init(
        name: String,
        version: String? = nil,
        attributes: [OTLPKeyValue]? = nil,
        droppedAttributesCount: UInt32? = nil
    ) {
        self.name = name
        self.version = version
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)

        if let version = version {
            try container.encode(version, forKey: .version)
        }

        if let attributes = attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        // Only encode droppedAttributesCount if it's non-zero
        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }
    }
}
