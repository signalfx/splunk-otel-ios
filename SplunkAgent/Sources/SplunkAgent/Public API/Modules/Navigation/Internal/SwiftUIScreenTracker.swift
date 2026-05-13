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

/// Deduplicate repeated SwiftUI `.onAppear` emissions before forwarding to manual `track()`.
///
/// SwiftUI's `.onAppear` fires on redraws, tab switches, and navigation stack changes.
/// Unlike explicit `navigation.track(screen:attributes:)` calls — which represent
/// deliberate user intent and always emit — SwiftUI appearance tracking is lifecycle-driven
/// and should suppress exact duplicate emissions.
///
/// Two appearances are considered duplicates when both the screen name and the
/// converted telemetry attributes are identical. Unsupported attribute values are
/// ignored by the conversion, matching the telemetry attribute contract.
final class SwiftUIScreenTracker: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var lastKey: ScreenKey?

    private struct ScreenKey: Equatable {
        let screenName: String
        let attributes: MutableAttributes

        init(screenName: String, attributes: [String: Any]?) {
            self.screenName = screenName
            self.attributes = MutableAttributes(from: attributes ?? [:])
        }
    }


    // MARK: - Tracking

    /// Emit a screen-name change for a SwiftUI appearance if it differs from the last emission.
    ///
    /// - Parameters:
    ///   - screenName: The screen name to track.
    ///   - attributes: User-provided attributes for this appearance.
    ///   - emit: Called only when the appearance is not a duplicate of the last call.
    func trackIfChanged(screenName: String, attributes: [String: Any]?, emit: () -> Void) {
        let key = ScreenKey(screenName: screenName, attributes: attributes)

        let isDuplicate = lock.withLock {
            if lastKey == key {
                return true
            }
            lastKey = key
            return false
        }

        if !isDuplicate {
            emit()
        }
    }
}
