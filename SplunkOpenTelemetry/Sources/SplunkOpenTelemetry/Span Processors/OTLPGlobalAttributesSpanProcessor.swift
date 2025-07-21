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

/// A span processor that enriches every new span with a set of global attributes.
///
/// This processor retrieves attributes from a provided closure at the moment a span is started
/// and adds them to the span's attributes.
public class OTLPGlobalAttributesSpanProcessor: SpanProcessor {
    private let globalAttributes: () -> [String: AttributeValue]

    /// Initializes a new global attributes span processor.
    ///
    /// - Parameter globalAttributes: A closure that returns a dictionary of attributes to be added to each span. This closure is called every time a new span starts.
    public init(with globalAttributes: @escaping () -> [String: AttributeValue]) {
        self.globalAttributes = globalAttributes
    }

    // MARK: - SpanProcessor

    /// A Boolean value indicating that the `onStart(parentContext:span:)` method should be called for each span.
    public var isStartRequired: Bool { true }
    /// A Boolean value indicating that the `onEnd(span:)` method is not required for each span.
    public var isEndRequired: Bool { false }

    /// Called when a `ReadableSpan` is started.
    ///
    /// This method adds the global attributes to the span by invoking the `globalAttributes` closure.
    /// - Parameters:
    ///   - parentContext: The context of the parent span, if any.
    ///   - span: The `ReadableSpan` that is starting.
    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        // Add global attributes to the span attributes when it's created
        for (key, value) in globalAttributes() {
            span.setAttribute(key: key, value: value)
        }
    }

    /// Called when a `ReadableSpan` has ended.
    ///
    /// This method performs no action.
    /// - Parameter span: The `ReadableSpan` that has ended.
    public func onEnd(span: ReadableSpan) {
        // No action needed when span ends
    }

    /// Shuts down the processor.
    ///
    /// This method performs no action as there are no resources to clean up.
    /// - Parameter explicitTimeout: This parameter is ignored.
    public func shutdown(explicitTimeout: TimeInterval?) {
        // No cleanup needed
    }

    /// Forces the processor to flush any pending spans.
    ///
    /// This method performs no action as it does not buffer spans.
    /// - Parameter timeout: This parameter is ignored.
    public func forceFlush(timeout: TimeInterval?) {
        // No action needed
    }
}
