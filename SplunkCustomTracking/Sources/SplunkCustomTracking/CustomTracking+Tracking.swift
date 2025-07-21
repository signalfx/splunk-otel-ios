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

public extension CustomTrackingInternal {


    // MARK: - Internal Tracking Methods


    // MARK: - Custom Event Tracking

    /// Tracks a custom event.
    ///
    /// This method packages a `SplunkTrackableEvent` into `CustomTrackingData` and publishes it
    /// via the `onPublishBlock`.
    ///
    /// - Parameter event: The `SplunkTrackableEvent` to be tracked.
    func track(_ event: SplunkTrackableEvent) {
        // OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata and data for the event
        let metadata = CustomTrackingMetadata()

        let data = CustomTrackingData(name: event.eventName,
                                      component: "event",
                                      attributes: event.toAttributesDictionary())

        // Publish the event using the block
        onPublishBlock(metadata, data)
    }


    // MARK: - Custom Error Tracking

    /// Tracks a custom issue or error.
    ///
    /// This method takes a `SplunkTrackableIssue`, combines its attributes with any additional provided attributes,
    /// and marks it as an error by adding the `"error": "true"` attribute. The resulting data is then published.
    ///
    /// - Parameters:
    ///   - issue: The `SplunkTrackableIssue` representing the error to be tracked.
    ///   - attributes: A dictionary of additional attributes to associate with the error.
    func track(_ issue: SplunkTrackableIssue, _ attributes: [String: EventAttributeValue]) {
        // OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata for the issue
        let metadata = CustomTrackingMetadata()

        // Combine the provided attributes with attributes from the issue
        // Our toAttributesDictionary() also injects the issue.exceptionType
        let attributesToInject = ["error": EventAttributeValue.string("true")]
        let augmented = attributes.merging(attributesToInject) { $1 }
        let combinedAttributes = augmented.merging(issue.toAttributesDictionary()) { $1 }

        // Create the tracking data
        let data = CustomTrackingData(name: "error",
                                      component: "error",
                                      attributes: combinedAttributes)

        // Publish the issue using the block
        onPublishBlock(metadata, data)
    }

    /// Starts a new OpenTelemetry `Span` to trace a named workflow.
    ///
    /// This method is used to manually instrument a workflow or a multi-step operation. It creates and returns a `Span`
    /// that the caller is responsible for ending. The span is automatically configured with a `workflow.name` attribute.
    ///
    /// - Note: The caller must call `end()` on the returned `Span` to complete the trace.
    ///
    /// ```swift
    /// // Start a span for a user login workflow
    /// let loginWorkflow = CustomTrackingInternal.instance.track("user-login")
    ///
    /// // ... perform login operations ...
    ///
    /// // End the span to record the duration
    /// loginWorkflow.end()
    /// ```
    ///
    /// - Parameter workflowName: The name of the workflow to be tracked. This will be used as the span name.
    /// - Returns: An OpenTelemetry `Span` that has been started.
    func track(_ workflowName: String) -> Span {
        // Ensure the tracer provider is properly configured
            let tracer = OpenTelemetry.instance
                .tracerProvider
                .get(
                    instrumentationName: "splunk-custom-tracking",
                    instrumentationVersion: sharedState?.agentVersion ?? "unknown"
                )

        // Start a span for the workflow
        let span = tracer.spanBuilder(spanName: workflowName)
                .setAttribute(key: "workflow.name", value: workflowName)
                .startSpan()

        // Return the span object
        return span
    }
}
