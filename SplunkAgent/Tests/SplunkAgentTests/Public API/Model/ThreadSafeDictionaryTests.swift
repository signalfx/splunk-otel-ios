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

import XCTest

@testable import SplunkAgent

final class ThreadSafeDictionaryTests: XCTestCase {

    // MARK: - Basic Functionality Tests

    func testInitialization() {
        // Test empty initialization
        let emptyDict = ThreadSafeDictionary<String, Int>()
        XCTAssertEqual(emptyDict.count(), 0)

        // Test initialization with dictionary
        let initialDict = ["one": 1, "two": 2, "three": 3]
        let dict = ThreadSafeDictionary<String, Int>(dictionary: initialDict)
        XCTAssertEqual(dict.count(), 3)
        XCTAssertEqual(dict["one"], 1)
        XCTAssertEqual(dict["two"], 2)
        XCTAssertEqual(dict["three"], 3)
    }

    func testSubscript() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2
        dict["three"] = 3

        XCTAssertEqual(dict["one"], 1)
        XCTAssertEqual(dict["two"], 2)
        XCTAssertEqual(dict["three"], 3)
        XCTAssertNil(dict["four"])

        // Test removing values
        dict["two"] = nil
        XCTAssertEqual(dict["one"], 1)
        XCTAssertNil(dict["two"])
        XCTAssertEqual(dict["three"], 3)
    }

    func testValueForKey() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2

        XCTAssertEqual(dict.value(forKey: "one"), 1)
        XCTAssertEqual(dict.value(forKey: "two"), 2)
        XCTAssertNil(dict.value(forKey: "three"))
    }

    func testSetValue() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict.setValue(1, forKey: "one")
        dict.setValue(2, forKey: "two")

        XCTAssertEqual(dict["one"], 1)
        XCTAssertEqual(dict["two"], 2)

        // Test setting nil
        dict.setValue(nil, forKey: "one")
        XCTAssertNil(dict["one"])
        XCTAssertEqual(dict["two"], 2)
    }

    func testRemoveValue() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2
        dict["three"] = 3

        let removedValue = dict.removeValue(forKey: "two")
        XCTAssertEqual(removedValue, 2)
        XCTAssertEqual(dict["one"], 1)
        XCTAssertNil(dict["two"])
        XCTAssertEqual(dict["three"], 3)

        // Test removing non-existent key
        let notFound = dict.removeValue(forKey: "four")
        XCTAssertNil(notFound)
    }

    func testContains() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2

        XCTAssertTrue(dict.contains(key: "one"))
        XCTAssertTrue(dict.contains(key: "two"))
        XCTAssertFalse(dict.contains(key: "three"))
    }

    func testAllKeys() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2
        dict["three"] = 3

        let keys = dict.allKeys()
        XCTAssertEqual(keys.count, 3)
        XCTAssertTrue(keys.contains("one"))
        XCTAssertTrue(keys.contains("two"))
        XCTAssertTrue(keys.contains("three"))
    }

    func testAllValues() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2
        dict["three"] = 3

        let values = dict.allValues()
        XCTAssertEqual(values.count, 3)
        XCTAssertTrue(values.contains(1))
        XCTAssertTrue(values.contains(2))
        XCTAssertTrue(values.contains(3))
    }

    func testCount() {
        let dict = ThreadSafeDictionary<String, Int>()

        XCTAssertEqual(dict.count(), 0)

        dict["one"] = 1
        XCTAssertEqual(dict.count(), 1)

        dict["two"] = 2
        XCTAssertEqual(dict.count(), 2)

        dict["one"] = nil
        XCTAssertEqual(dict.count(), 1)
    }

    func testRemoveAll() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2
        dict["three"] = 3

        XCTAssertEqual(dict.count(), 3)

        dict.removeAll()
        XCTAssertEqual(dict.count(), 0)
        XCTAssertNil(dict["one"])
        XCTAssertNil(dict["two"])
        XCTAssertNil(dict["three"])
    }

    func testDictionary() {
        let initialDict = ["one": 1, "two": 2, "three": 3]
        let dict = ThreadSafeDictionary<String, Int>(dictionary: initialDict)

        let copy = dict.getAll()
        XCTAssertEqual(copy.count, 3)
        XCTAssertEqual(copy["one"], 1)
        XCTAssertEqual(copy["two"], 2)
        XCTAssertEqual(copy["three"], 3)

        // Verify that modifying the copy doesn't affect the original
        var mutableCopy = copy
        mutableCopy["four"] = 4
        XCTAssertEqual(dict.count(), 3)
        XCTAssertNil(dict["four"])
    }

    func testUpdate() {
        let dict = ThreadSafeDictionary<String, Int>()

        dict["one"] = 1
        dict["two"] = 2

        let newValues = ["three": 3, "four": 4, "five": 5]
        let updatedCount = dict.update(with: newValues)
        XCTAssertEqual(updatedCount, 3)

        XCTAssertEqual(dict["one"], 1)
        XCTAssertEqual(dict["two"], 2)
        XCTAssertEqual(dict["three"], 3)
        XCTAssertEqual(dict["four"], 4)
        XCTAssertEqual(dict["five"], 5)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentReads() {
        let dict = ThreadSafeDictionary<String, Int>()
        let expectation = XCTestExpectation(description: "Concurrent reads")
        expectation.expectedFulfillmentCount = 100

        // Initialize with some values
        for index in 0 ..< 10 {
            dict["key\(index)"] = index
        }

        // Perform concurrent reads
        for _ in 0 ..< 100 {
            DispatchQueue.global()
                .async {
                    _ = dict["key\(Int.random(in: 0 ..< 10))"]
                    expectation.fulfill()
                }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentWrites() {
        let dict = ThreadSafeDictionary<String, Int>()
        let expectation = XCTestExpectation(description: "Concurrent writes")
        expectation.expectedFulfillmentCount = 100

        // Perform concurrent writes
        for index in 0 ..< 100 {
            Task.detached {
                dict["key\(index)"] = index
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)

        // Verify all values were written
        XCTAssertEqual(dict.count(), 100)
        for index in 0 ..< 100 {
            XCTAssertEqual(dict["key\(index)"], index)
        }
    }

    func testConcurrentReadsAndWrites() {
        let dict = ThreadSafeDictionary<String, Int>()
        let readExpectation = XCTestExpectation(description: "Concurrent reads")
        let writeExpectation = XCTestExpectation(description: "Concurrent writes")
        readExpectation.expectedFulfillmentCount = 100
        writeExpectation.expectedFulfillmentCount = 100

        for index in 0 ..< 10 {
            dict["key\(index)"] = index
        }

        // Perform concurrent reads
        for _ in 0 ..< 100 {
            DispatchQueue.global()
                .async {
                    _ = dict["key\(Int.random(in: 0 ..< 10))"]
                    readExpectation.fulfill()
                }
        }

        // Perform concurrent writes
        for index in 0 ..< 100 {
            DispatchQueue.global()
                .async {
                    dict["key\(index + 10)"] = index + 10
                    writeExpectation.fulfill()
                }
        }

        wait(for: [readExpectation, writeExpectation], timeout: 5.0)

        // Verify all values were written
        XCTAssertEqual(dict.count(), 110)
        for index in 0 ..< 110 {
            XCTAssertEqual(dict["key\(index)"], index)
        }
    }
}
