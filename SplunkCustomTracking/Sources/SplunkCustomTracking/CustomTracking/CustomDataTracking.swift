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


// MARK: - CustomTracking implementation

class CustomDataTracking: CustomTracking {

    public unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "CustomDataTracking"))

    func track(data: SplunkTrackableData) {

        var constrainedAttributes = ConstrainedAttributes<EventAttributeValue>()

        // TODO: - Determine the correct use of this property versus the serviceName in publishData()
        data.typeName = "data"

        // Convert SplunkTrackableData to attributes and set them with length validation
        for (key, value) in data.toEventAttributes() {
            if !constrainedAttributes.setAttribute(for: key, value: value) {
                print("Failed to set attribute due to length constraints: \(key)")
                return
            }
        }


        // TODO: we're not even using the attributes we got off the data;
        // we're just using the data directly. Need to figure out what to do here.


        // Publish the data if all attributes are valid
        publishData(data: data, serviceName: "customDataTracking")
    }
}
