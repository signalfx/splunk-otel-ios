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
import OpenTelemetrySdk

public class OTLPGlobalAttributesSpanProcessor: SpanProcessor {
    private let globalAttributes: [String: Any]

    public init(with globalAttributes: [String: Any]) {
        self.globalAttributes = globalAttributes
    }

    // MARK: - SpanProcessor

    public var isStartRequired: Bool { true }
    public var isEndRequired: Bool { false }

    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        // Add global attributes to the span when it's created
        for (key, value) in globalAttributes {
            if let stringValue = value as? String {
                span.setAttribute(key: key, value: .string(stringValue))
            } else if let boolValue = value as? Bool {
                span.setAttribute(key: key, value: .bool(boolValue))
            } else if let intValue = value as? Int {
                span.setAttribute(key: key, value: .int(intValue))
            } else if let doubleValue = value as? Double {
                span.setAttribute(key: key, value: .double(doubleValue))
            } else if let arrayValue = value as? [Any] {
                var attributeValues: [AttributeValue] = []
                for element in arrayValue {
                    if let stringElement = element as? String {
                        attributeValues.append(.string(stringElement))
                    } else if let boolElement = element as? Bool {
                        attributeValues.append(.bool(boolElement))
                    } else if let intElement = element as? Int {
                        attributeValues.append(.int(intElement))
                    } else if let doubleElement = element as? Double {
                        attributeValues.append(.double(doubleElement))
                    }
                }
                span.setAttribute(key: key, value: .array(AttributeArray(values: attributeValues)))
            }
        }
    }

    public func onEnd(span: ReadableSpan) {
        // No action needed when span ends
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        // No cleanup needed
    }

    public func forceFlush(timeout: TimeInterval?) {
        // No action needed
    }
}
