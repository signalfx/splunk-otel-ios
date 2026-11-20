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
import OpenTelemetryApi

/// Internal extensions to the OpenTelemetry Span protocol
@_spi(SplunkInternal)
extension Span {

    /// Clears the existing value for a key and then sets a new value.
    ///
    /// This is useful for ensuring clean attribute updates without leftover values. The two
    /// underlying `Span.setAttribute` calls are not an atomic transaction; callers must serialize
    /// this operation with span finalization when they can run concurrently.
    ///
    /// - Parameters:
    ///   - key: The attribute key to clear and set
    ///   - value: The new value to set for the key
    public func clearAndSetAttribute(key: String, value: AttributeValue) {
        // First clear the existing value by setting it to nil
        setAttribute(key: key, value: nil as AttributeValue?)

        // Then set the new value
        setAttribute(key: key, value: value)
    }

    /// Clears the existing value for a key and then sets a new value.
    ///
    /// This is a convenience method that accepts Any and converts it to AttributeValue.
    ///
    /// - Parameters:
    ///   - key: The attribute key to clear and set
    ///   - value: The new value to set for the key (will be converted to AttributeValue)
    public func clearAndSetAttribute(key: String, value: Any) {
        clearAndSetAttribute(key: key, value: TelemetryAttributeConverter.attributeValue(from: value))
    }

    // MARK: - SemanticConventions Convenience Methods

    /// Clears the existing value for a semantic attribute key and then sets a new value.
    ///
    /// This is useful for ensuring clean attribute updates without leftover values.
    /// Works with any `SemanticConventions` nested enum (e.g., `SemanticConventions.Http`, `SemanticConventions.Url`).
    ///
    /// - Parameters:
    ///   - key: The semantic attribute key to clear and set (any RawRepresentable with String rawValue)
    ///   - value: The new value to set for the key
    public func clearAndSetAttribute<T: RawRepresentable>(key: T, value: AttributeValue) where T.RawValue == String {
        clearAndSetAttribute(key: key.rawValue, value: value)
    }

    /// Clears the existing value for a semantic attribute key and then sets a new value.
    ///
    /// This is a convenience method that accepts Any and converts it to AttributeValue.
    /// Works with any `SemanticConventions` nested enum (e.g., `SemanticConventions.Http`, `SemanticConventions.Url`).
    ///
    /// - Parameters:
    ///   - key: The semantic attribute key to clear and set (any RawRepresentable with String rawValue)
    ///   - value: The new value to set for the key (will be converted to AttributeValue)
    public func clearAndSetAttribute<T: RawRepresentable>(key: T, value: Any) where T.RawValue == String {
        clearAndSetAttribute(key: key.rawValue, value: value)
    }
}
