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

import CiscoInteractions
import CiscoLogger
import CiscoRuntimeCache
import CiscoSwizzling
import Foundation
import SplunkCommon

/// Handles interaction events and send them into destination.
public final class Interactions: SplunkInteractionsModule {

    // MARK: - Private properties

    private let destination: SplunkInteractionsDestination
    private var interactionsTask: Task<Void, Never>?

    private let internalLogger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "SplunkInteractions"
    )

    private var customIdentifiers = RuntimeCache<String>(
        name: "SplunkInteractionsCustomIds",
        poolName: PackageIdentifier.instance(),
        garbageCollectionCount: 1000
    )


    // MARK: - Internal properties

    var interactionsDetector: InteractionsDetector<DefaultSwizzling>?


    // MARK: - Initialization

    /// Initializes the `Interactions` module.
    ///
    /// This initializer sets up the default `OTelDestination`
    /// to handle and export interaction events.
    public required init() {
        destination = OTelDestination()
    }

    init(destination: SplunkInteractionsDestination) {
        self.destination = destination
    }


    // MARK: - Instrumentation

    /// Start detecting interaction events.
    func startInteractionsDetection() {
        guard interactionsDetector == nil else {
            internalLogger.log(level: .error) {
                "Interactions detection is already running."
            }

            return
        }

        interactionsTask = Task {
            do {
                interactionsDetector = try await InteractionsDetector<DefaultSwizzling>()

                guard let eventsStream = interactionsDetector?.eventsStream else {

                    internalLogger.log(level: .error) {
                        "Cannot handle interactions event stream."
                    }

                    return
                }

                for await event in eventsStream {

                    await handleEvent(event)
                }
            } catch {

                internalLogger.log(level: .error) {
                    "Could not initialize InteractionsDetector: \(error)."
                }
            }
        }
    }

    func handleEvent(_ event: InteractionEvent) async {
        if let interactionType = interactionType(from: event.type) {

            let targetElement = await targetElement(from: event)

            destination.send(
                actionName: interactionType,
                elementId: targetElement,
                time: event.time
            )
        }
    }


    // MARK: - Custom view identifiers

    public func register(customId: String?, for viewId: ObjectIdentifier) {
        Task {
            await customIdentifiers.append(value: customId, for: self, with: viewId)
        }
    }


    // MARK: - Private helper functions

    func targetElement(from event: InteractionEvent) async -> String? {
        guard let identifier = targetElementIdentifier(from: event) else {
            return nil
        }

        let customId = await customIdentifiers.value(for: identifier)

        return customId ?? String(UInt(bitPattern: identifier))
    }

    func targetElementIdentifier(from event: InteractionEvent) -> ObjectIdentifier? {
        if let targetElementId = event.gestureTap?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.gestureLongPress?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.gestureDoubleTap?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.gestureRageTap?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.gesturePinch?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.gestureRotation?.targetElementId {
            return targetElementId
        }

        if let targetElementId = event.focus?.targetElementId {
            return targetElementId
        }

        return nil
    }

    func interactionType(from eventType: CiscoInteractions.InteractionType) -> String? {

        switch eventType {
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
