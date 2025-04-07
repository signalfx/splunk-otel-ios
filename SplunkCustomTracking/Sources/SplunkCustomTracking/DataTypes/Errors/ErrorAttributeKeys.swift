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
import SplunkSharedProtocols


// MARK: - AttributeKey helper

/// Protocol for type-safe attribute keys
public protocol AttributeKey {
    var rawValue: String { get }
}


// MARK: - ErrorAttributeKeys

/// Namespace containing OpenTelemetry semantic convention keys for error reporting
public enum ErrorAttributeKeys {
    /// Exception-specific attribute keys
    public enum Exception: String, AttributeKey {
        case type = "exception.type"
        case message = "exception.message"
        case stacktrace = "exception.stacktrace"
        case code = "exception.code"
        case escaped = "exception.escaped"
    }
    
    /// ErrorCode-specific attribute keys... did not use `Code` here because Xcode flags it as reserved
    public enum ErrorCode: String, AttributeKey {
        case namespace = "code.namespace"
    }
    
    /// Service-specific attribute keys
    public enum Service: String, AttributeKey {
        case name = "service.name"
    }
    
}


// MARK: - Dictionary Convenience Extensions

extension Dictionary where Key == String, Value == EventAttributeValue {
    /// Initialize a dictionary from attribute keys
    init<T: AttributeKey>(_ keyed: [T: Value]) {
        self.init(uniqueKeysWithValues: keyed.map { ($0.rawValue, $1) })
    }

}
