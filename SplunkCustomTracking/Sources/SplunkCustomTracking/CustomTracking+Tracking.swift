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
        OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")
        /*
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }
        let metadata = InternalCustomTrackingMetadata()
        let data = InternalCustomTrackingData(name: event.typeName, attributes: event.toEventAttributes())
        onPublishBlock(metadata, data)
         */
    }


    // MARK: - Custom Error Tracking

    func track<T: SplunkTrackableIssue>(issue: T, attributes: MutableAttributes) {
        OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")
        /*
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }
        let metadata = InternalCustomTrackingMetadata()
        // Convert public-facing attributes to internal EventAttributeValue
        let convertedAttributes = attributes.mapValues { EventAttributeValue.convert(from: $0) }
        var allAttributes = convertedAttributes
        for (key, value) in issue.toEventAttributes() {
            allAttributes[key] = value
        }
        let data = InternalCustomTrackingData(name: issue.typeName, attributes: allAttributes)
        onPublishBlock(metadata, data)
        */
    }
}
