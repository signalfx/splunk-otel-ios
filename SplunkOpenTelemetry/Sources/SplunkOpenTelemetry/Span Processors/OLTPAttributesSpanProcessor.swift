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
import SplunkSharedProtocols

/// The class implements a generic span processor that adds runtime attributes to all spans.
public class OLTPAttributesSpanProcessor: SpanProcessor {

    // MARK: - Private

    private unowned let runtimeAttributes: any RuntimeAttributes


    // MARK: - SpanProcessor settings

    public let isStartRequired = true

    public let isEndRequired = false


    // MARK: - Initialization
    
    /// Initializes new span processor with given runtime attributes.
    /// 
    /// - Parameter runtimeAttributes: An object that holds and manages runtime attributes.
    /// 
    /// - Note: The processor itself does not own the object with runtime attributes.
    ///         So, ensuring its existence outside this span processor is always necessary.
    public init(with runtimeAttributes: RuntimeAttributes) {
        self.runtimeAttributes = runtimeAttributes
    }


    // MARK: - SpanProcessor methods

    public func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        inject(attributes: runtimeAttributes.all, to: span)
    }

    public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {}

    public func shutdown(explicitTimeout: TimeInterval?) {}

    public func forceFlush(timeout: TimeInterval?) {}


    // MARK: - Private methods

    private func inject(attributes: [String: Any], to span: any OpenTelemetrySdk.ReadableSpan) {
        // Attributes with a type not supported in OpenTelemetry are omitted
        for (key, value) in attributes {
            if let attributeValue = AttributeValue(value) {
                span.setAttribute(key: key, value: attributeValue)
            }
        }
    }
}

