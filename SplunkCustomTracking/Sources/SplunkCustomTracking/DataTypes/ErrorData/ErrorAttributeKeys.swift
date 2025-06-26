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
import SplunkCommon


// MARK: - AttributeKey Protocol

/// Protocol defining the base requirements for attribute keys.
protocol AttributeKey {
    var rawValue: String { get }
}


// MARK: - ErrorAttributeKeys

/// Namespace with OpenTelemetry semantic convention keys for error reporting.
enum ErrorAttributeKeys {
    /// Exception-specific attribute keys.
    enum Exception: String, AttributeKey {
        case type = "exception.type"
        case message = "exception.message"
        case stacktrace = "exception.stacktrace"
        case code = "exception.code"
        case escaped = "exception.escaped"
    }

    /// ErrorCode-specific attribute keys.
    enum ErrorCode: String, AttributeKey {
        case namespace = "code.namespace"
    }

    /// Service-specific attribute keys.
    enum Service: String, AttributeKey {
        case name = "service.name"
    }
}
