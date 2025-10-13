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

@testable import SplunkCommon

final class DefaultPersistentCacheTests: XCTestCase {

    // MARK: - Private

    private var defaultCache: DefaultPersistentCache<Int>?

    private let firstKey = PersistentCacheContent.firstKey
    private let secondKey = PersistentCacheContent.secondKey
    private let thirdKey = PersistentCacheContent.thirdKey


    // MARK: - Tests lifecycle

    override func setUp() async throws {
        try await super.setUp()

        // Create a cache and feed them with sample data
        let cacheName = UUID().uuidString + ".defaultCache"
        let cacheContent = PersistentCacheContent.integers

        defaultCache = DefaultPersistentCacheTestBuilder.build(named: cacheName)
        await defaultCache?.model.restore(to: cacheContent)
    }

    override func tearDown() async throws {
        defaultCache = nil

        try await super.tearDown()
    }


    // MARK: - Basic logic

    func testInitialization() async throws {
        let countersName = UUID().uuidString + ".countersCache"
        let customDataName = UUID().uuidString + ".customDataCache"

        let capacity = 100
        let lifetime: TimeInterval = 30 * 60


        // Cache initialized with minimal parameters
        let countersCache = DefaultPersistentCache<Int>(uniqueCacheName: countersName)
        let countersCacheCount = await countersCache.keys.count

        // Cache initialization with all available parameters
        let customDataCache = DefaultPersistentCache<CustomDataItem>(
            uniqueCacheName: customDataName,
            maximumCapacity: capacity,
            maximumLifetime: lifetime
        )
        let customDataCacheCount = await customDataCache.keys.count


        // Caches should be empty
        XCTAssertNotNil(countersCache)
        XCTAssertEqual(countersCacheCount, 0)

        XCTAssertNotNil(customDataCache)
        XCTAssertEqual(customDataCacheCount, 0)

        // Caches should be configured with default settings or specified parameters
        XCTAssertEqual(countersCache.uniqueCacheName, countersName)
        XCTAssertEqual(countersCache.maximumCapacity, .max)
        XCTAssertNil(countersCache.maximumLifetime)

        XCTAssertEqual(customDataCache.uniqueCacheName, customDataName)
        XCTAssertEqual(customDataCache.maximumCapacity, capacity)
        XCTAssertEqual(customDataCache.maximumLifetime, lifetime)
    }

    func testProperties() async throws {
        let expectedKeys: Set<String> = [
            PersistentCacheContent.firstKey,
            PersistentCacheContent.secondKey,
            PersistentCacheContent.thirdKey
        ]
        let expectedValues: [Int] = [1, 2, 3]


        let defaultCache = try XCTUnwrap(defaultCache)
        let cacheKeys = await defaultCache.keys
        let cacheValues = await defaultCache.values

        XCTAssertEqual(cacheKeys.count, expectedKeys.count)
        XCTAssertTrue(cacheKeys.allSatisfy { expectedKeys.contains($0) })

        XCTAssertEqual(cacheValues.count, expectedValues.count)
        XCTAssertTrue(cacheValues.allSatisfy { expectedValues.contains($0) })
    }


    // MARK: - Custom filtering

    func testElementsFromTo() async throws {
        let afterThreeMinutes = Date() + 3 * 60
        let afterSevenMinutes = Date() + 7 * 60

        let content = PersistentCacheContent.integers


        // Obtain different subsets of items based on their modification date.
        let defaultCache = try XCTUnwrap(defaultCache)
        let elementsTo = await defaultCache.elements(to: afterSevenMinutes)
        let elementsFrom = await defaultCache.elements(from: afterSevenMinutes)
        let elementsInRange = await defaultCache.elements(from: afterThreeMinutes, to: afterSevenMinutes)


        XCTAssertEqual(elementsTo.count, 2)
        XCTAssertEqual(elementsTo[firstKey], content[firstKey]?.value)
        XCTAssertEqual(elementsTo[secondKey], content[secondKey]?.value)

        XCTAssertEqual(elementsFrom.count, 1)
        XCTAssertEqual(elementsFrom[thirdKey], content[thirdKey]?.value)

        XCTAssertEqual(elementsInRange.count, 1)
        XCTAssertEqual(elementsInRange[secondKey], content[secondKey]?.value)
    }


    // MARK: - CRUD operations

    func testValueForKey() async throws {
        let defaultCache = try XCTUnwrap(defaultCache)
        let firstValue = try await defaultCache.value(forKey: firstKey)
        let thirdValue = try await defaultCache.value(forKey: thirdKey)

        XCTAssertEqual(firstValue, 1)
        XCTAssertEqual(thirdValue, 3)
    }

    func testUpdateForKey() async throws {
        let testName = "persistentCacheUpdate"

        let cache = DefaultPersistentCacheTestBuilder.build(named: testName)
        await cache.model.restore(to: PersistentCacheContent.integers)

        try await cache.update(0, forKey: firstKey)
        try await cache.update(5, forKey: secondKey)

        let itemsCount = await cache.model.items().count
        let firstValue = try await cache.value(forKey: firstKey)
        let secondValue = try await cache.value(forKey: secondKey)

        XCTAssertEqual(itemsCount, 3)
        XCTAssertEqual(firstValue, 0)
        XCTAssertEqual(secondValue, 5)
    }

    func testRemoveForKey() async throws {
        let testName = "persistentCacheRemove"

        let cache = DefaultPersistentCacheTestBuilder.build(named: testName)
        await cache.model.restore(to: PersistentCacheContent.integers)

        try await cache.sync()

        try await cache.remove(forKey: firstKey)
        try await cache.remove(forKey: thirdKey)

        let itemsCount = await cache.model.items().count
        let secondValue = try await cache.value(forKey: secondKey)

        XCTAssertEqual(itemsCount, 1)
        XCTAssertEqual(secondValue, 2)
    }


    // MARK: - Maintenance methods

    func testPurge() async throws {
        let testName = "persistentCachePurge"

        var items: [String: Int] = [:]
        let thirtyMinutes: TimeInterval = 30 * 60

        for value in 0 ... 9 {
            items["\(value)"] = value
        }

        let content = PersistentCacheContent.generateContainers(
            from: items,
            startDate: Date() - (5 * 10)
        )


        // Let's create a cache and fill it with some items with updates in the past
        let cache = DefaultPersistentCacheTestBuilder.build(
            named: testName,
            maximumCapacity: 5,
            maximumLifetime: thirtyMinutes
        )
        await cache.model.restore(to: content)

        // Purge the cache content
        await cache.purge()


        // After the Purge there should be 8 items:
        //
        // - Three items are older than a configured lifetime
        // - Two items are over capacity
        let keys = await cache.keys.sorted()
        let values = await cache.values.sorted()
        let expected = Array(5 ... 9)

        XCTAssertEqual(keys.count, 5)
        XCTAssertEqual(keys, expected.map(\.description))
        XCTAssertEqual(values, expected)
    }
}
