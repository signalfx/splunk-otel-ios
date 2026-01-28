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
@testable import SplunkCommon

final class PersistentCacheContent {

    // MARK: - Constants

    static let firstKey = "first"
    static let secondKey = "second"
    static let thirdKey = "third"


    // MARK: - Content

    static var integers: [String: DefaultItemContainer<Int>] {
        let items: [String: Int] = [
            firstKey: 1,
            secondKey: 2,
            thirdKey: 3
        ]

        return generateContainers(from: items)
    }

    static var customData: [String: DefaultItemContainer<CustomDataItem>] {
        let items: [String: CustomDataItem] = [
            firstKey: .init(id: 1, text: "Hello"),
            secondKey: .init(id: 2, text: "World"),
            thirdKey: .init(id: 3, text: "!")
        ]

        return generateContainers(from: items)
    }


    // MARK: - Containers generator

    static func generateContainers<T>(from items: [String: T], startDate: Date = Date()) -> [String: DefaultItemContainer<T>] {
        var nextDate = startDate
        let fiveMinutes: TimeInterval = 5 * 60

        let sortedKeys = items.keys.sorted { first, second in
            first < second
        }

        var content: [String: DefaultItemContainer<T>] = [:]

        // Encapsulate dictionary values into item containers
        for key in sortedKeys {
            if let value = items[key] {
                content[key] = .init(value: value, updated: nextDate)
            }

            nextDate += fiveMinutes
        }

        return content
    }
}
