//
/*
Copyright 2026 Splunk Inc.

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

/// The span returned to the app for a custom workflow.
///
/// It forwards every call to the span the tracer started, but ignores the attributes in
/// ``AgentOnlyAttributeKeys``. The agent stamps `session.id` when the span starts, so the app
/// cannot add, change or remove it afterwards: the span is exported under the session it started
/// in, or dropped if it started with none.
///
/// The SDK span cannot be subclassed, so wrapping it is the only way to see attribute writes.
/// Nothing is stored besides the wrapped span, which synchronizes its own state.
///
/// A child span started with this span as its parent keeps the parent's trace and span IDs, but the SDK
/// takes its timestamps from the child's own tracer clock, because it reuses a parent's clock only for an
/// SDK span.
final class CustomWorkflowSpan: Span {

    // MARK: - Properties

    /// The span the tracer started.
    let span: any Span


    // MARK: - Initialization

    init(span: any Span) {
        self.span = span
    }


    // MARK: - SpanBase

    var kind: SpanKind {
        span.kind
    }

    var context: SpanContext {
        span.context
    }

    var isRecording: Bool {
        span.isRecording
    }

    var status: Status {
        get { span.status }
        set { span.status = newValue }
    }

    var name: String {
        get { span.name }
        set { span.name = newValue }
    }

    var description: String {
        span.description
    }

    func setAttribute(key: String, value: AttributeValue?) {
        guard !AgentOnlyAttributeKeys.all.contains(key) else {
            return
        }

        span.setAttribute(key: key, value: value)
    }

    func setAttributes(_ attributes: [String: AttributeValue]) {
        span.setAttributes(attributes.removingAgentOnlyAttributes())
    }

    func addEvent(name: String) {
        span.addEvent(name: name)
    }

    func addEvent(name: String, timestamp: Date) {
        span.addEvent(name: name, timestamp: timestamp)
    }

    func addEvent(name: String, attributes: [String: AttributeValue]) {
        span.addEvent(name: name, attributes: attributes)
    }

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
        span.addEvent(name: name, attributes: attributes, timestamp: timestamp)
    }


    // MARK: - SpanExceptionRecorder

    func recordException(_ exception: SpanException) {
        span.recordException(exception)
    }

    func recordException(_ exception: SpanException, timestamp: Date) {
        span.recordException(exception, timestamp: timestamp)
    }

    func recordException(_ exception: SpanException, attributes: [String: AttributeValue]) {
        span.recordException(exception, attributes: attributes)
    }

    func recordException(_ exception: SpanException, attributes: [String: AttributeValue], timestamp: Date) {
        span.recordException(exception, attributes: attributes, timestamp: timestamp)
    }


    // MARK: - Span

    func end() {
        removeActiveContext()
        span.end()
    }

    func end(time: Date) {
        removeActiveContext()
        span.end(time: time)
    }


    // MARK: - Private methods

    /// Removes this span from the active context, if the app made it active.
    ///
    /// It runs before the wrapped span ends, as the SDK span removes itself before it calls the `onEnd`
    /// processors: a span that a processor starts then does not take the ended workflow as its parent. The
    /// context manager matches spans by identity, so the wrapped span's end removes only itself.
    private func removeActiveContext() {
        OpenTelemetry.instance.contextProvider.removeContextForSpan(self)
    }
}
