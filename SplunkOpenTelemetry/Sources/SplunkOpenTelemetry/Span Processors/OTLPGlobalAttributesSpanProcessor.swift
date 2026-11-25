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

public class OTLPGlobalAttributesSpanProcessor: SpanProcessor {
    private let globalAttributes: () -> [String: AttributeValue]
    private let ownsSessionId: Bool

    public convenience init(with globalAttributes: @escaping () -> [String: AttributeValue]) {
        self.init(with: globalAttributes, ownsSessionId: false)
    }

    /// Initializes a span processor that can leave `session.id` and `session.previous_id` to the agent.
    ///
    /// With `ownsSessionId`, global attributes with these keys are not written to spans. They would be
    /// removed later anyway, and on a span that is at its attribute limit they could take the slot that the
    /// agent's own `session.id` needs. Pass `true` only for an agent's pipeline.
    package init(with globalAttributes: @escaping () -> [String: AttributeValue], ownsSessionId: Bool) {
        self.globalAttributes = globalAttributes
        self.ownsSessionId = ownsSessionId
    }

    // MARK: - SpanProcessor

    public var isStartRequired: Bool {
        true
    }

    public var isEndRequired: Bool {
        false
    }

    public func onStart(parentContext _: SpanContext?, span: ReadableSpan) {
        // Add global attributes to the span attributes when it's created
        for (key, value) in globalAttributes() {
            if ownsSessionId, SessionAttributeKeys.agentOnly.contains(key) {
                continue
            }

            span.clearAndSetAttribute(key: key, value: value)
        }
    }

    public func onEnd(span _: ReadableSpan) {
        // No action needed when span ends
    }

    public func shutdown(explicitTimeout _: TimeInterval?) {
        // No cleanup needed
    }

    public func forceFlush(timeout _: TimeInterval?) {
        // No action needed
    }
}
