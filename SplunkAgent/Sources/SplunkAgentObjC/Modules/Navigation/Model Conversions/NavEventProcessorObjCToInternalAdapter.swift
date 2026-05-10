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

internal import SplunkNavigation

/// Adapts an Objective-C ``NavigationEventProcessorObjC`` to the
/// ``NavigationEventProcessor`` protocol used by the navigation engine.
///
/// - Note: We mark this class `@unchecked Sendable` because it is immutable after
///   init; the single stored property is a private let and is never mutated.
final class NavEventProcessorObjCToInternalAdapter: NavigationEventProcessor, @unchecked Sendable {

    // MARK: - Private

    private let objcProcessor: any NavigationEventProcessorObjC


    // MARK: - Initialization

    init(wrapping objcProcessor: any NavigationEventProcessorObjC) {
        self.objcProcessor = objcProcessor
    }


    // MARK: - NavigationEventProcessor

    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {

        guard let objcEvent = objcProcessor.onViewController(typeName: typeName, controllerIdentity: controllerIdentity) else {
            return nil
        }

        let attributes: [String: Any]? = objcEvent.attributes.flatMap { dict in
            let filtered = dict.compactMap { key, value -> (String, Any)? in
                guard let stringKey = key as? String else {
                    return nil
                }

                return (stringKey, value)
            }

            return filtered.isEmpty ? nil : Dictionary(uniqueKeysWithValues: filtered)
        }

        return NavigationEvent(
            name: objcEvent.name,
            attributes: attributes
        )
    }
}
