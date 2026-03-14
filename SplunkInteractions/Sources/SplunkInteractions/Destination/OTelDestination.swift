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

import CiscoInteractions
import Foundation
import OpenTelemetryApi
import SplunkCommon

/// Creates and sends an OpenTelemetry span from supplied app start data.
struct OTelDestination: SplunkInteractionsDestination {

    // MARK: - Sending

    func sendInteraction(actionName: String, elementId: String?, xpath: String?, time: Date) {

        let logProvider = OpenTelemetry.instance
            .loggerProvider
            .get(
                instrumentationScopeName: "splunk-interaction"
            )

        var attributes: [String: AttributeValue] = [:]
        attributes["event.name"] = .string("action")
        attributes["component"] = .string("ui")
        attributes["action.name"] = .string(actionName)

        if let xpath {
            attributes["target_xpath"] = .string(xpath)
        }

        if let elementId {
            attributes["target.type"] = .string(elementId)
        }

        let logRecordBuilder =
            logProvider
            .logRecordBuilder()
            .setTimestamp(time)
            .setAttributes(attributes)

        // Send event
        logRecordBuilder.emit()
    }

    func sendFrustration(xpath: String?, time: Date) {

        let logProvider = OpenTelemetry.instance
            .loggerProvider
            .get(
                instrumentationScopeName: "splunk-interaction"
            )

        var attributes: [String: AttributeValue] = [:]
        attributes["event.name"] = .string("frustration")
        attributes["component"] = .string("user-interaction")
        attributes["frustration_type"] = .string("rage")
        attributes["interaction_type"] = .string("tap")

        if let xpath {
            attributes["target_xpath"] = .string(xpath)
        }

        let logRecordBuilder =
            logProvider
            .logRecordBuilder()
            .setTimestamp(time)
            .setAttributes(attributes)

        // Send event
        logRecordBuilder.emit()
    }
}
