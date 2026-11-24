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
@_spi(SplunkInternal) import SplunkCommon

/// The class implements a generic span processor that adds runtime attributes to all spans.
public class OTLPAttributesSpanProcessor: SpanProcessor {

    // MARK: - Private

    private unowned let runtimeAttributes: any RuntimeAttributes
    private let activityTracker: ActivityTracker
    private let ownsSessionId: Bool


    // MARK: - SpanProcessor settings

    public let isStartRequired = true

    public let isEndRequired = false


    // MARK: - Initialization

    /// Initializes new span processor with given runtime attributes.
    ///
    /// - Parameters:
    ///   -  runtimeAttributes: An object that holds and manages runtime attributes.
    ///   -  activityTracker: An object that can track session activity.
    ///
    /// - Note: The processor itself does not own the object with runtime attributes.
    ///         So, ensuring its existence outside this span processor is always necessary.
    public convenience init(with runtimeAttributes: RuntimeAttributes, activityTracker: ActivityTracker) {
        self.init(with: runtimeAttributes, activityTracker: activityTracker, ownsSessionId: false)
    }

    /// Initializes a span processor that can treat `session.id` and `session.previous_id` as set only by the
    /// runtime attributes.
    ///
    /// With `ownsSessionId`, a span started while the runtime attributes lack one of these keys loses any
    /// value for it that the span already holds, such as one set on the span builder. Pass `true` only
    /// for an agent's pipeline.
    package init(with runtimeAttributes: RuntimeAttributes, activityTracker: ActivityTracker, ownsSessionId: Bool) {
        self.runtimeAttributes = runtimeAttributes
        self.activityTracker = activityTracker
        self.ownsSessionId = ownsSessionId
    }


    // MARK: - SpanProcessor methods

    public func onStart(parentContext _: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        let startedSpan = span.toSpanData()
        activityTracker.trackActivity(at: startedSpan.startTime)

        let attributes = runtimeAttributes.all
        inject(attributes: attributes, to: span)

        if ownsSessionId {
            // The agent owns both session keys. Remove a value that the span already holds, such as one set
            // on the span builder, unless the runtime attributes carry the key. Only a key that the span
            // holds is removed, so the usual span start (no such value) writes nothing.
            for key in SessionAttributeKeys.agentOnly where attributes[key] == nil && startedSpan.attributes[key] != nil {
                span.setAttribute(key: key, value: nil)
            }
        }
    }

    public func onEnd(span _: any OpenTelemetrySdk.ReadableSpan) {}

    public func shutdown(explicitTimeout _: TimeInterval?) {}

    public func forceFlush(timeout _: TimeInterval?) {}


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

                span.clearAndSetAttribute(key: key, value: attributeValue)
            }
        }
    }

    private func isScreenSpan(_ span: any OpenTelemetrySdk.ReadableSpan) -> Bool {
        span.name == "app.ui.navigation" || span.name == "ShowVC" || span.name == "PresentationTransition"
    }
}
