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

// MARK: - OTLPScopeLogs

/// Container for log records from a single instrumentation scope.
///
/// ScopeLogs groups all log records that were produced by the same
/// instrumentation library/scope. This allows receivers to process log
/// records from the same instrumentation together.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/logs/v1/logs.proto
struct OTLPScopeLogs: Encodable {

    // MARK: - Properties

    /// The instrumentation scope that produced these log records.
    let scope: OTLPInstrumentationScope?

    /// The list of log records from this scope.
    let logRecords: [OTLPLogRecord]

    /// The schema URL for the instrumentation scope.
    let schemaUrl: String?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case scope
        case logRecords
        case schemaUrl
    }


    // MARK: - Initialization

    /// Creates a new ScopeLogs container.
    ///
    /// - Parameters:
    ///   - scope: The instrumentation scope that produced these log records.
    ///   - logRecords: The list of log records from this scope.
    ///   - schemaUrl: The schema URL for the instrumentation scope.
    init(
        scope: OTLPInstrumentationScope?,
        logRecords: [OTLPLogRecord],
        schemaUrl: String? = nil
    ) {
        self.scope = scope
        self.logRecords = logRecords
        self.schemaUrl = schemaUrl
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let scope {
            try container.encode(scope, forKey: .scope)
        }

        try container.encode(logRecords, forKey: .logRecords)

        if let schemaUrl, !schemaUrl.isEmpty {
            try container.encode(schemaUrl, forKey: .schemaUrl)
        }
    }
}
