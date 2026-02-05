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

// MARK: - OTLPKeyValue

/// OTLP KeyValue for attributes.
///
/// KeyValue represents a single attribute with a string key and an AnyValue value.
/// This is used throughout OTLP for resource attributes, span attributes,
/// log record attributes, and metric data point attributes.
///
/// JSON shape: `{"key": "attribute.name", "value": {"stringValue": "..."}}`
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/common/v1/common.proto
struct OTLPKeyValue: Encodable {

    // MARK: - Properties

    /// The attribute key/name.
    let key: String

    /// The attribute value.
    let value: OTLPAnyValue


}
