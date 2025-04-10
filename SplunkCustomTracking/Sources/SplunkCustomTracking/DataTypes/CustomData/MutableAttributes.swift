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
import SplunkSharedProtocols


// MARK: - MutableAttributes idea stolen from Frank's WIP ideas on Mutable Attributes

class MutableAttributes {
    private var attributes: [String: EventAttributeValue] = [:]

    func get(key: String) -> EventAttributeValue? {
        return attributes[key]
    }

    func getAll() -> [String: EventAttributeValue] {
        return attributes
    }

    func set(key: String, value: EventAttributeValue) {
        attributes[key] = value
    }

    func remove(key: String) {
        attributes.removeValue(forKey: key)
    }

    func removeAll() {
        attributes.removeAll()
    }

    func setAll(newAttributes: [String: EventAttributeValue]) {
        attributes.merge(newAttributes) { (_, new) in new }
    }

    func update(_ updateBlock: (inout [String: EventAttributeValue]) -> Void) {
        updateBlock(&attributes)
    }
}
