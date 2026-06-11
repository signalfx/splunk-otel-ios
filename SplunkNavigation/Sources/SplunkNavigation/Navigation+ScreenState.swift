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

import Foundation
internal import OpenTelemetryApi
@_spi(SplunkInternal) import SplunkCommon

extension Navigation {

    // MARK: - Static constants

    static let screenStateReservedAttributeKeys: Set<String> = [
        "component",
        "navigation.name",
        "last.screen.name",
        "screen.name"
    ]


    // MARK: - Screen state

    /// Atomically records the current screen state.
    func updateCurrentScreenState(
        screenName: String,
        attributes: [String: Any]?,
        forceEmit: Bool
    ) -> NavigationScreenStateUpdate {
        let state = NavigationScreenState(
            name: screenName,
            attributes: effectiveCustomAttributes(from: attributes)
        )

        return runtimeStateStore.updateScreenState(state, forceEmit: forceEmit)
    }

    func currentScreenState() -> NavigationScreenState? {
        runtimeStateStore.screenState
    }

    /// Resets stored screen state to nil and publishes the resulting fallback name
    /// ("unknown") to observers and the async stream.
    ///
    /// Use this instead of calling `runtimeStateStore.resetScreenState()` and
    /// `publishScreenNameChange` separately, so the reset and its published value
    /// are always kept in sync.
    func resetScreenToNoScreen() {
        runtimeStateStore.resetScreenState()
        publishScreenNameChange(runtimeStateStore.screenName)
    }

    func updateCurrentScreenState(
        _ state: NavigationScreenState,
        forceEmit: Bool
    ) -> NavigationScreenStateUpdate {
        runtimeStateStore.updateScreenState(state, forceEmit: forceEmit)
    }

    func effectiveCustomAttributes(from attributes: [String: Any]?) -> [String: AttributeValue] {
        var convertedAttributes = TelemetryAttributeConverter.attributes(from: attributes)

        for reservedKey in Self.screenStateReservedAttributeKeys {
            convertedAttributes.removeValue(forKey: reservedKey)
        }

        return convertedAttributes
    }
}
