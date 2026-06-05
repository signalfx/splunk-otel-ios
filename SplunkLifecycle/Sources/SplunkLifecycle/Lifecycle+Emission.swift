//
/*
Copyright 2026 Splunk Inc.

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

import CiscoSwizzling
import Foundation
import OpenTelemetryApi
import SplunkUIKitInstrumentation

extension Lifecycle {

    // MARK: - Static constants

    private static let component = "ui"
    private static let componentKey = "component"
    private static let elementIdKey = "element.id"
    private static let elementNameKey = "element.name"
    private static let elementType = "UIViewController"
    private static let elementTypeKey = "element.type"
    private static let eventName = "app.ui.lifecycle"
    private static let eventNameKey = "event.name"
    private static let instrumentationScopeName = "splunk-lifecycle"
    private static let lifecycleActionKey = "lifecycle.action"


    // MARK: - Detection

    func startDetection() {
        Task(priority: .userInitiated) {
            await runNavigationDetectionLoop()
        }
    }

    private func runNavigationDetectionLoop() async {
        do {
            let stream = try await lifecycleEventStreamProvider.navigationStream()

            for await event in stream {
                guard let lifecycleEvent = lifecycleEvent(from: event) else {
                    continue
                }

                send(lifecycleEvent: lifecycleEvent)
            }
        }
        catch {
            // Stream initialization failures are intentionally non-fatal.
        }
    }

    private func lifecycleEvent(from event: any NavigationActionEvent) -> LifecycleEvent? {
        guard
            let action = lifecycleAction(for: event.type),
            configuration.allowedEvents.contains(action),
            !ControllerNameFiltering.shouldIgnore(controllerTypeName: event.controllerTypeName)
        else {
            return nil
        }

        return LifecycleEvent(
            timestamp: event.timestamp,
            action: action,
            elementType: Self.elementType,
            elementName: ClassNameSanitization.sanitize(
                typeName: event.controllerTypeName,
                bundleName: applicationBundleName
            ),
            elementId: event.controllerTypeName
        )
    }

    private func lifecycleAction(for navigationEventType: NavigationActionEventType) -> LifecycleAction? {
        switch navigationEventType {
        case .viewDidLoad:
            return .viewCreated

        case .viewDidAppear:
            return .resumed

        case .viewDidDisappear:
            return .stopped

        case .didTransitionToTraitCollection,
            .navigationControllerDidShow,
            .navigationControllerWillShow,
            .viewDidTransition,
            .viewWillTransition,
            .willTransitionToTraitCollection:
            return nil

        @unknown default:
            return nil
        }
    }


    // MARK: - Emission

    func send(lifecycleEvent: LifecycleEvent) {
        let logger = OpenTelemetry.instance
            .loggerProvider
            .get(instrumentationScopeName: Self.instrumentationScopeName)

        logger
            .logRecordBuilder()
            .setTimestamp(lifecycleEvent.timestamp)
            .setAttributes(
                [
                    Self.eventNameKey: .string(Self.eventName),
                    Self.componentKey: .string(Self.component),
                    Self.elementTypeKey: .string(lifecycleEvent.elementType),
                    Self.elementNameKey: .string(lifecycleEvent.elementName),
                    Self.elementIdKey: .string(lifecycleEvent.elementId),
                    Self.lifecycleActionKey: .string(lifecycleEvent.action.rawValue)
                ]
            )
            .emit()
    }
}
