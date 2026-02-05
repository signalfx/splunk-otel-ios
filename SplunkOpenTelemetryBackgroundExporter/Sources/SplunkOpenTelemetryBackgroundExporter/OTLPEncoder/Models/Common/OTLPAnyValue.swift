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

// MARK: - OTLPAnyValue

/// OTLP AnyValue with custom encoding to produce correct JSON shape.
///
/// AnyValue is used throughout OTLP to represent attribute values that can be
/// of various types. The JSON encoding must produce the correct shape with
/// type-specific keys.
///
/// Example JSON shapes:
/// - String: `{"stringValue": "hello"}`
/// - Bool: `{"boolValue": true}`
/// - Int: `{"intValue": "123"}` (note: decimal string)
/// - Double: `{"doubleValue": 3.14}`
/// - Bytes: `{"bytesValue": "SGVsbG8="}` (base64 encoded)
/// - Array: `{"arrayValue": {"values": [...]}}`
/// - KVList: `{"kvlistValue": {"values": [...]}}`
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/common/v1/common.proto
enum OTLPAnyValue: Encodable {

    // MARK: - Cases

    /// A string value.
    case stringValue(String)

    /// A boolean value.
    case boolValue(Bool)

    /// An integer value (encoded as decimal string per OTLP JSON spec).
    case intValue(Int64)

    /// A double-precision floating-point value.
    case doubleValue(Double)

    /// Binary data (encoded as base64 string per OTLP JSON spec).
    case bytesValue(Data)

    /// An array of AnyValue items.
    case arrayValue(OTLPArrayValue)

    /// A list of key-value pairs (map-like structure).
    case kvlistValue(OTLPKeyValueList)


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case stringValue
        case boolValue
        case intValue
        case doubleValue
        case bytesValue
        case arrayValue
        case kvlistValue
    }


    // MARK: - Encodable

    /// Encodes the AnyValue with the correct JSON shape per OTLP specification.
    ///
    /// Each case encodes as an object with a single type-specific key.
    /// Int64 values are encoded as decimal strings to avoid precision loss.
    /// Data values are encoded as base64 strings.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .stringValue(let value):
            try container.encode(value, forKey: .stringValue)

        case .boolValue(let value):
            try container.encode(value, forKey: .boolValue)

        case .intValue(let value):
            // CRITICAL: OTLP JSON requires 64-bit integers as decimal strings
            try container.encode(String(value), forKey: .intValue)

        case .doubleValue(let value):
            try container.encode(value, forKey: .doubleValue)

        case .bytesValue(let value):
            // OTLP JSON requires binary data as base64 encoded strings
            try container.encode(value.base64EncodedString(), forKey: .bytesValue)

        case .arrayValue(let value):
            try container.encode(value, forKey: .arrayValue)

        case .kvlistValue(let value):
            try container.encode(value, forKey: .kvlistValue)
        }
    }
}


// MARK: - OTLPArrayValue

/// Array container for OTLPAnyValue items.
///
/// JSON shape: `{"arrayValue": {"values": [...]}}`
///
/// Based on OTLP specification v1.9.0.
struct OTLPArrayValue: Encodable {

    // MARK: - Properties

    /// The array of values.
    let values: [OTLPAnyValue]


    // MARK: - Initialization

    /// Creates a new array value.
    ///
    /// - Parameter values: The array of AnyValue items.
    init(values: [OTLPAnyValue]) {
        self.values = values
    }
}


// MARK: - OTLPKeyValueList

/// Key-value list container for map-like attributes.
///
/// JSON shape: `{"kvlistValue": {"values": [{"key": "k1", "value": {...}}, ...]}}`
///
/// Based on OTLP specification v1.9.0.
struct OTLPKeyValueList: Encodable {

    // MARK: - Properties

    /// The list of key-value pairs.
    let values: [OTLPKeyValue]


    // MARK: - Initialization

    /// Creates a new key-value list.
    ///
    /// - Parameter values: The list of key-value pairs.
    init(values: [OTLPKeyValue]) {
        self.values = values
    }
}
