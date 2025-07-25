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
import SplunkCommon

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

    /// Called when a `ReadableSpan` is started.
    ///
    /// This method injects all current runtime attributes from the `runtimeAttributes` provider into the span.
    /// - Parameters:
    ///   - parentContext: The context of the parent span, if any.
    ///   - span: The `ReadableSpan` that is starting.
    public func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        inject(attributes: runtimeAttributes.all, to: span)
    }

    /// Called when a `ReadableSpan` has ended.
    ///
    /// This method performs no action.
    /// - Parameter span: The `ReadableSpan` that has ended.
    public func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {}

    /// Shuts down the processor.
    ///
    /// This method performs no action as there are no resources to clean up.
    /// - Parameter explicitTimeout: This parameter is ignored.
    public func shutdown(explicitTimeout: TimeInterval?) {}

    /// Forces the processor to flush any pending spans.
    ///
    /// This method performs no action as it does not buffer spans.
    /// - Parameter timeout: This parameter is ignored.
    public func forceFlush(timeout: TimeInterval?) {}


    // MARK: - Private methods

    private func inject(attributes: [String: Any], to span: any OpenTelemetrySdk.ReadableSpan) {
        // Attributes with a type not supported in OpenTelemetry are omitted
        for (key, value) in attributes {
            if let attributeValue = AttributeValue(value) {
                // Regarding screen spans, we do not directly assign the screen name.
                // Instead, we utilize the entry that is already part of the span
                if key == "screen.name", isScreenSpan(span) {
                    continue
                }

                span.setAttribute(key: key, value: attributeValue)
            }
        }
    }

    private func isScreenSpan(_ span: any OpenTelemetrySdk.ReadableSpan) -> Bool {
        span.name == "screen name change" || span.name == "ShowVC"
    }
}
