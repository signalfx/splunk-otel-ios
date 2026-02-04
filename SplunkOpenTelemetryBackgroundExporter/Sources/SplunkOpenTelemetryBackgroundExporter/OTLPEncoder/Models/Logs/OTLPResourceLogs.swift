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


// MARK: - OTLPResourceLogs

/// Container for log records from a single resource.
///
/// ResourceLogs groups all log records that share the same resource. Each
/// ResourceLogs can contain multiple ScopeLogs from different
/// instrumentation scopes.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/logs/v1/logs.proto
struct OTLPResourceLogs: Encodable {

    // MARK: - Properties

    /// The resource associated with these log records.
    let resource: OTLPResource?

    /// A list of ScopeLogs from different instrumentation scopes.
    let scopeLogs: [OTLPScopeLogs]

    /// The schema URL for the resource attributes.
    let schemaUrl: String?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case resource
        case scopeLogs
        case schemaUrl
    }


    // MARK: - Initialization

    /// Creates a new ResourceLogs container.
    ///
    /// - Parameters:
    ///   - resource: The resource associated with these log records.
    ///   - scopeLogs: A list of ScopeLogs from different instrumentation scopes.
    ///   - schemaUrl: The schema URL for the resource attributes.
    init(
        resource: OTLPResource?,
        scopeLogs: [OTLPScopeLogs],
        schemaUrl: String? = nil
    ) {
        self.resource = resource
        self.scopeLogs = scopeLogs
        self.schemaUrl = schemaUrl
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let resource = resource {
            try container.encode(resource, forKey: .resource)
        }

        try container.encode(scopeLogs, forKey: .scopeLogs)

        if let schemaUrl = schemaUrl, !schemaUrl.isEmpty {
            try container.encode(schemaUrl, forKey: .schemaUrl)
        }
    }
}
