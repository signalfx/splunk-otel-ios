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
            if let arrayValue = value as? [Any] {
                var attributeValues: [AttributeValue] = []

                for element in arrayValue {
                    if let attributeValue = AttributeValue(element) {
                        attributeValues.append(attributeValue)
                    }
                }

                span.setAttribute(key: key, value: .array(AttributeArray(values: attributeValues)))

            } else {
                if let attributeValue = AttributeValue(value) {
                    span.setAttribute(key: key, value: attributeValue)
                }
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
