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

        let publishIssue = { attributes in
            // Create the tracking data
            let data = CustomTrackingData(
                name: "error",
                component: "error",
                attributes: attributes
            )

            // Publish the issue using the block
            onPublishBlock(metadata, data)
        }

        guard let diagnosticsIssue else {
            publishIssue(combinedAttributes)
            return
        }

        let diagnostics = diagnosticEnricher.diagnostics(for: diagnosticsIssue)
        diagnostics.apply(to: &combinedAttributes)
        publishIssue(combinedAttributes)
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
