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

// MARK: - OTLPResource

/// OTLP Resource model.
///
/// A Resource represents the entity producing telemetry, identified by a set
/// of attributes. Common attributes include service.name, service.version,
/// host.name, etc.
///
/// Note: The `schemaUrl` field is NOT on this model - it's on the parent
/// container types (ResourceSpans, ResourceLogs, ResourceMetrics).
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/resource/v1/resource.proto
struct OTLPResource: Encodable {

    // MARK: - Properties

    /// The attributes describing this resource.
    let attributes: [OTLPKeyValue]

    /// The number of attributes that were dropped due to limits.
    /// Only encoded if greater than 0.
    let droppedAttributesCount: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case attributes
        case droppedAttributesCount
    }


    // MARK: - Initialization

    /// Creates a new resource.
    ///
    /// - Parameters:
    ///   - attributes: The attributes describing this resource.
    ///   - droppedAttributesCount: The number of dropped attributes (nil or 0 means none).
    init(attributes: [OTLPKeyValue], droppedAttributesCount: UInt32? = nil) {
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
    }


    // MARK: - Encodable

    /// Custom encoding to omit droppedAttributesCount when zero or nil.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(attributes, forKey: .attributes)

        // Only encode droppedAttributesCount if it's non-zero
        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }
    }
}
