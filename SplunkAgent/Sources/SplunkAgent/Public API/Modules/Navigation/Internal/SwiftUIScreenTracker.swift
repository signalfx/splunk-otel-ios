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
/// normalized attributes string are identical. Attributes are normalized by sorting
/// keys deterministically so key-ordering differences do not create false distinctions.
final class SwiftUIScreenTracker: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var lastKey: String?


    // MARK: - Tracking

    /// Emit a screen-name change for a SwiftUI appearance if it differs from the last emission.
    ///
    /// - Parameters:
    ///   - screenName: The screen name to track.
    ///   - attributes: User-provided attributes for this appearance.
    ///   - emit: Called only when the appearance is not a duplicate of the last call.
    func trackIfChanged(screenName: String, attributes: [String: Any]?, emit: () -> Void) {
        let key = makeKey(screenName: screenName, attributes: attributes)

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


    // MARK: - Private helpers

    private func makeKey(screenName: String, attributes: [String: Any]?) -> String {
        let attrs = attributes ?? [:]

        guard !attrs.isEmpty else {
            return screenName
        }

        let normalized = attrs.keys
            .sorted()
            .map { key -> String in
                guard let attrValue = attrs[key] else {
                    return "\(key)="
                }
                return "\(key)=\(normalizeValue(attrValue))"
            }
            .joined(separator: ",")

        return "\(screenName)|\(normalized)"
    }

    private func normalizeValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            return "s:\(str)"

        case let bool as Bool:
            return "b:\(bool)"

        case let int as Int:
            return "i:\(int)"

        case let double as Double:
            return "d:\(double)"

        case let strings as [String]:
            return "sa:[\(strings.joined(separator: ","))]"

        case let bools as [Bool]:
            return "ba:[\(bools.map { String($0) }.joined(separator: ","))]"

        case let ints as [Int]:
            return "ia:[\(ints.map { String($0) }.joined(separator: ","))]"

        case let doubles as [Double]:
            return "da:[\(doubles.map { String($0) }.joined(separator: ","))]"

        case let anyArray as [Any]:
            return "aa:[\(anyArray.map { normalizeValue($0) }.joined(separator: ","))]"

        default:
            return "x:\(String(describing: value))"
        }
    }
}
