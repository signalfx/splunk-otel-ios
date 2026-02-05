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

// MARK: - OTLPStatus

/// OTLP Span Status model.
///
/// Status indicates whether the span operation succeeded or failed.
/// The code field is an integer enum:
/// - 0 = STATUS_CODE_UNSET: The default status (operation outcome unknown)
/// - 1 = STATUS_CODE_OK: The operation completed successfully
/// - 2 = STATUS_CODE_ERROR: The operation failed
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/trace/v1/trace.proto
struct OTLPStatus: Encodable {

    // MARK: - Status Codes

    /// Status code indicating the operation outcome is unknown (default).
    static let unset = 0

    /// Status code indicating the operation completed successfully.
    static let ok = 1

    /// Status code indicating the operation failed.
    static let error = 2


    // MARK: - Properties

    /// Optional description of the status (typically used for errors).
    let message: String?

    /// Status code as an integer enum.
    /// 0 = UNSET, 1 = OK, 2 = ERROR
    let code: Int


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case message
        case code
    }


    // MARK: - Initialization

    /// Creates a new status.
    ///
    /// - Parameters:
    ///   - message: Optional description of the status.
    ///   - code: Status code (0=UNSET, 1=OK, 2=ERROR).
    init(message: String? = nil, code: Int) {
        self.message = message
        self.code = code
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional message field.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let message, !message.isEmpty {
            try container.encode(message, forKey: .message)
        }

        try container.encode(code, forKey: .code)
    }
}
