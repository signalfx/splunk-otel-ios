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

import OpenTelemetryApi
import SplunkCommon

extension CustomTrackingInternal {


    // MARK: - Internal Tracking Methods


    // MARK: - Custom Event Tracking

    public func track(_ event: SplunkTrackableEvent) {
        // OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")

        guard isEnabled else {
            return
        }

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata and data for the event
        let metadata = CustomTrackingMetadata()

        let data = CustomTrackingData(
            name: event.eventName,
            component: "custom-event",
            attributes: event.toAttributesDictionary()
        )

        // Publish the event using the block
        onPublishBlock(metadata, data)
    }


    // MARK: - Custom Error Tracking

    public func track(_ issue: SplunkTrackableIssue, _ attributes: [String: EventAttributeValue]) {
        // OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")
        publishIssue(issue, spanName: "error", attributes)
    }

    /// Tracks an explicitly-supplied error/exception, naming the span after the
    /// issue's `exceptionType` (falling back to `"error"` when it is empty).
    ///
    /// This is the emission path for the explicit-stacktrace `trackError` API used
    /// by the hybrid agents. Unlike ``track(_:_:)``, which always names the span
    /// `"error"`, it surfaces the error under its own type name and emits the
    /// supplied stacktrace verbatim, matching the Android explicit-stack behavior.
    ///
    /// - Parameters:
    ///   - issue: The explicitly-supplied issue to emit (see `SplunkExplicitIssue`).
    ///   - attributes: Caller-provided attributes merged into the error span. The
    ///     issue's own `exception.*` attributes take precedence on key conflicts.
    public func trackError(_ issue: SplunkTrackableIssue, _ attributes: [String: EventAttributeValue]) {
        let spanName = issue.exceptionType.isEmpty ? "error" : issue.exceptionType
        publishIssue(issue, spanName: spanName, attributes)
    }

    /// Builds the `component=error` tracking data for an issue and publishes it.
    ///
    /// Shared by ``track(_:_:)`` and ``trackError(_:_:)``; the only difference
    /// between the two paths is the resolved span `name`.
    private func publishIssue(_ issue: SplunkTrackableIssue, spanName: String, _ attributes: [String: EventAttributeValue]) {
        guard isEnabled else {
            return
        }

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata for the issue
        let metadata = CustomTrackingMetadata()

        let diagnosticsIssue: SplunkIssue?
        if let splunkIssue = issue as? SplunkIssue, splunkIssue.stacktrace != nil {
            diagnosticsIssue = splunkIssue
        }
        else {
            diagnosticsIssue = nil
        }

        // Combine the provided attributes with attributes from the issue
        // Our toAttributesDictionary() also injects the issue.exceptionType
        let attributesToInject = ["error": EventAttributeValue.string("true")]
        let augmented = attributes.merging(attributesToInject) { $1 }
        var combinedAttributes = augmented.merging(
            issue.toAttributesDictionary(includingExceptionThreads: diagnosticsIssue == nil)
        ) { $1 }

        let publish = { (attributes: [String: EventAttributeValue]) in
            // Create the tracking data
            let data = CustomTrackingData(
                name: spanName,
                component: "error",
                attributes: attributes
            )

            // Publish the issue using the block
            onPublishBlock(metadata, data)
        }

        guard let diagnosticsIssue else {
            publish(combinedAttributes)
            return
        }

        let diagnostics = diagnosticEnricher.diagnostics(for: diagnosticsIssue)
        diagnostics.apply(to: &combinedAttributes)
        publish(combinedAttributes)
    }

    public func track(_ workflowName: String) -> Span {
        guard isEnabled else {
            let span = DefaultTracer.instance.spanBuilder(spanName: workflowName).startSpan()
            span.end()
            return span
        }

        // Ensure the tracer provider is properly configured
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-custom-tracking",
                instrumentationVersion: sharedState?.agentVersion ?? "unknown"
            )

        // Start a span for the workflow
        return tracer.spanBuilder(spanName: workflowName)
            .setAttribute(key: "workflow.name", value: workflowName)
            .setAttribute(key: "component", value: "custom-workflow")
            .startSpan()

        // Return the span object
    }
}
