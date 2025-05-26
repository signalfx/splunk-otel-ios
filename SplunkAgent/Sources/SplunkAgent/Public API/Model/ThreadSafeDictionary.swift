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

/// A thread-safe dictionary implementation using DispatchQueue
class ThreadSafeDictionary<Key: Hashable, Value> {
    private var dictionary: [Key: Value]

    private let queue: DispatchQueue

    // MARK: - Initialize

    init() {
        dictionary = [:]
        queue = DispatchQueue(label: "com.splunk.rum.SplunkAgent.MutableAttributes")
    }

    init(dictionary: [Key: Value]) {
        self.dictionary = dictionary
        queue = DispatchQueue(label: "com.splunk.rum.SplunkAgent.MutableAttributes")
    }

    // MARK: - Subscript

    subscript(key: Key) -> Value? {
        get {
            var result: Value?
            queue.sync {
                result = dictionary[key]
            }
            return result
        }
        set {
            queue.async(flags: .barrier) {
                if let newValue = newValue {
                    self.dictionary[key] = newValue
                } else {
                    self.dictionary.removeValue(forKey: key)
                }
            }
        }
    }

    // MARK: - Get and Set

    func value(forKey key: Key) -> Value? {
        return self[key]
    }

    func setValue(_ value: Value?, forKey key: Key) {
        self[key] = value
    }

    // MARK: - Utilities

    @discardableResult
    func removeValue(forKey key: Key) -> Value? {
        var result: Value?
        queue.async(flags: .barrier) {
            result = self.dictionary.removeValue(forKey: key)
        }
        return result
    }

    func contains(key: Key) -> Bool {
        var result = false
        queue.sync {
            result = dictionary.keys.contains(key)
        }
        return result
    }

    func allKeys() -> [Key] {
        var result: [Key] = []
        queue.sync {
            result = Array(dictionary.keys)
        }
        return result
    }

    func allValues() -> [Value] {
        var result: [Value] = []
        queue.sync {
            result = Array(dictionary.values)
        }
        return result
    }

    func count() -> Int {
        var result = 0
        queue.sync {
            result = dictionary.count
        }
        return result
    }

    func removeAll() {
        queue.async(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }

    func getAll() -> [Key: Value] {
        var result: [Key: Value] = [:]
        queue.sync {
            result = self.dictionary
        }
        return result
    }

    @discardableResult
    func update(with other: [Key: Value]) -> Int {
        var count = 0
        queue.async(flags: .barrier) {
            for (key, value) in other {
                self.dictionary[key] = value
                count += 1
            }
        }
        return count
    }
}
