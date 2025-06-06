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

    func track(_ event: SplunkTrackableEvent) {
        // OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata and data for the event
        let metadata = CustomTrackingMetadata()

        let data = CustomTrackingData(name: event.typeName, attributes: event.toAttributesDictionary())

        // Publish the event using the block
        onPublishBlock(metadata, data)
    }


    // MARK: - Custom Error Tracking

    func track(_ issue: SplunkTrackableIssue, _ attributes: [String: AttributeValue]) {
        // OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata for the issue
        let metadata = CustomTrackingMetadata()

        // Combine the provided attributes with attributes from the issue
        let combinedAttributes = attributes.merging(issue.toAttributesDictionary()) { $1 }

        // Create the tracking data
        let data = CustomTrackingData(name: issue.typeName, attributes: combinedAttributes)

        // Publish the issue using the block
        onPublishBlock(metadata, data)
    }

    func track(_ workflowName: String) -> Span {
        // Ensure the tracer provider is properly configured
            let tracer = OpenTelemetry.instance
                .tracerProvider
                .get(
                    instrumentationName: "splunk-custom-tracking",
                    instrumentationVersion: sharedState?.agentVersion
                )

            // Start a span for the workflow
        let span = tracer.spanBuilder(spanName: workflowName)
                .setAttribute(key: "workflow.name", value: workflowName)
                .startSpan()

            // Return the span object
            return span
    }
}
