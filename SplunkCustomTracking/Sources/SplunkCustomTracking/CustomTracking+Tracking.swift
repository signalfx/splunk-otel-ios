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

import SplunkCommon

public extension CustomTracking {


    // MARK: - Internal Tracking Methods


    // MARK: - Custom Event Tracking

    func track(event: SplunkTrackableEvent) {
        // OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata and data for the event
        let metadata = InternalCustomTrackingMetadata()

        // Pass `MutableAttributes` directly into `InternalCustomTrackingData`
        let data = InternalCustomTrackingData(name: event.typeName, attributes: event.toMutableAttributes())

        // Publish the event using the block
        onPublishBlock(metadata, data)
    }


    // MARK: - Custom Error Tracking

    func track(issue: SplunkTrackableIssue, attributes: MutableAttributes) {
        // OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")

        // Ensure the `onPublishBlock` is set
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        // Metadata for the issue
        let metadata = InternalCustomTrackingMetadata()

        // Combine the provided attributes with attributes from the issue
        let combinedAttributes = MutableAttributes()
        combinedAttributes.addDictionary(attributes.getAll())
        combinedAttributes.addDictionary(issue.toMutableAttributes().getAll())

        // Create the tracking data
        let data = InternalCustomTrackingData(name: issue.typeName, attributes: combinedAttributes)

        // Publish the issue using the block
        onPublishBlock(metadata, data)
    }
}
