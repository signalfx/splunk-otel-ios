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
import SplunkSharedProtocols

/// Creates and sends an OpenTelemetry span from supplied app start data.
struct OTelDestination: SplunkInteractionsDestination {

    // MARK: - Sending

    func send(event: InteractionEvent) {

        guard let interactionType = interactionType(from: event) else {

            return
        }

        let logProvider = OpenTelemetry.instance
            .loggerProvider
            .get(
                instrumentationScopeName: "splunk-interaction"
            )

        var attributes: [String: AttributeValue] = [:]

        attributes["action.name"] = .string(interactionType)

        if let elementId = targetElement(from: event) {
            attributes["target.type"] = .string(elementId)
        }

        let logRecordBuilder = logProvider
            .logRecordBuilder()
            .setTimestamp(event.time)
            .setAttributes(attributes)

        // Send event
        logRecordBuilder.emit()
    }


    // MARK: - Private helper functions

    private func targetElement(from event: InteractionEvent) -> String? {
        var identifier: ObjectIdentifier?

        if let targetElementId = event.gestureTap?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.gestureLongPress?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.gestureDoubleTap?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.gestureRageTap?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.gesturePinch?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.gestureRotation?.targetElementId {
            identifier = targetElementId
        }
        else if let targetElementId = event.focus?.targetElementId {
            identifier = targetElementId
        }

        guard let identifier else {

            return nil
        }

        return String(UInt(bitPattern: identifier))
    }

    private func interactionType(from event: InteractionEvent) -> String? {

        switch event.type {

        case .gestureTap:
            "tap"

        case .gestureLongPress:
            "long_press"

        case .gestureDoubleTap:
            "double_tap"

        case .gestureRageTap:
            "rage_tap"

        case .gesturePinch:
            "pinch"

        case .gestureRotation:
            "rotation"

        case .focus:
            "focus"

        case .softKeyboard:
            "soft_keyboard"

        default:
            nil
        }
    }
}
