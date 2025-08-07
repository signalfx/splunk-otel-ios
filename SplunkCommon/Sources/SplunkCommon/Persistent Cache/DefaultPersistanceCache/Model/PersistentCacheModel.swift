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

// Model actor for data used in persistent cache
actor PersistentCacheModel<Container: PersistedItemContainer> {

    // MARK: - Public

    private(set) var containers: [String: Container] = [:]

    private(set) var isRestored: Bool = false


    // MARK: - Items management

    func items(from start: Date? = nil, to end: Date? = nil) async -> [String: Container.Item] {
        var matchingContainers: [String: Container]

        // Filter containers by updated timestamp ...
        if start != nil || end != nil {
            let fromDate = start ?? .init(timeIntervalSince1970: 0)
            let toDate = end ?? .distantFuture

            matchingContainers = containers.filter {
                $0.value.updated >= fromDate && $0.value.updated <= toDate
            }

        } else {
            matchingContainers = containers
        }

        // ... and map them to items
        return matchingContainers
            .mapValues { container in
                container.value
            }
    }

    func item(forKey key: String) -> Container.Item? {
        containers[key]?.value
    }

    func add(_ item: Container.Item, forKey key: String) {
        containers[key] = Container(value: item, updated: .now)
    }

    func remove(key: String) {
        containers[key] = nil
    }

    func removeAll() {
        containers.removeAll()
        isRestored = false
    }

    func restore(to content: [String: Container]) {
        containers = content
        isRestored = true
    }


    // MARK: - Restore state management

    func update(isRestored restored: Bool) {
        isRestored = restored
    }
}
