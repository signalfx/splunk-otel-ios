//
/*
Copyright 2024 Splunk Inc.

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
import SplunkSharedProtocols


struct LogDataEmitter {

    public func setupLogEmitter() {
        onPublish { metadata: CustomTrackingEventMetadata, eventData: CustomTrackingEventData in

            let start = Time.now()

            var attributes = eventData.getAttributes()
            attributes["component"] = "customtracking"
            attributes["screen.name"] = "unknown"
            attributes["session.id"] = sharedState?.sessionId ?? "unknown"

            internalLogger.log(level: .info) {
                "Sending custom data: \(attributes?.debugDescription ?? "none")"
            }
        }
    }
}
