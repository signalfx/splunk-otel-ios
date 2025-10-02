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
import SplunkCommon

extension LogRecordBuilder {

    /// Builds LogRecordBuilder from supplied AgentEvent and initial LogRecordBuilder.
    ///
    /// - Parameter event: An event with which the LogRecordBuilder is built from.
    ///
    /// - Returns: New instance of `LogRecordBuilder`.
    func build(with event: any AgentEvent) -> LogRecordBuilder {

        // Initialize attribute dictionary
        var otelAttributes: [String: AttributeValue] = [:]

        // Attributes - session ID
        if let sessionId = event.sessionId {
            otelAttributes["session.id"] = AttributeValue(sessionId)
        }

        // Attributes - event.domain
        otelAttributes["event.domain"] = AttributeValue(event.domain)

        // Attributes - event.name
        otelAttributes["event.name"] = AttributeValue(event.name)

        // Attributes - component
        otelAttributes["component"] = AttributeValue(event.component)

        // Merge with provided attributes
        if let providedAttributes = event.attributes {
            for (attributeName, attributeValue) in providedAttributes {
                otelAttributes[attributeName] = AttributeValue(attributeValue)
            }
        }

        // Start building the builder
        let resultingBuilder = self

        // Add attributes
        if !otelAttributes.isEmpty {
            _ = resultingBuilder.setAttributes(otelAttributes)
        }

        // Add body
        if let body = event.body {
            _ = resultingBuilder.setBody(AttributeValue(body))
        }

        // Add timestamp
        if let timestamp = event.timestamp {
            _ = resultingBuilder.setTimestamp(timestamp)
        }

        return resultingBuilder
    }
}
