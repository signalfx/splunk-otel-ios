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

final class PersistentCacheModelTests: XCTestCase {

    // MARK: - Inline types

    private typealias ElementContainer = DefaultItemContainer<Int>


    // MARK: - Constants

    private let firstKey = PersistentCacheContent.firstKey
    private let secondKey = PersistentCacheContent.secondKey
    private let thirdKey = PersistentCacheContent.thirdKey


    // MARK: - Private

    private var model: PersistentCacheModel<ElementContainer>?


    // MARK: - Tests lifecycle

    override func setUp() async throws {
        try await super.setUp()

        // Fill model with some sample data
        model = PersistentCacheModel()
        await model?.add(1, forKey: firstKey)
        await model?.add(2, forKey: secondKey)
    }

    override func tearDown() {
        model = nil

        super.tearDown()
    }


    // MARK: - Basic logic

    func testInitialization() {
        let stringCacheModel = PersistentCacheModel<DefaultItemContainer<String>>()
        XCTAssertNotNil(stringCacheModel)

        let dataCacheModel = PersistentCacheModel<DefaultItemContainer<CustomDataItem>>()
        XCTAssertNotNil(dataCacheModel)
    }


    // MARK: - Items filtering

    func testItemsForRange() async {
        let afterThreeMinutes = Date() + 3 * 60
        let afterSevenMinutes = Date() + 7 * 60

        let customCacheModel = PersistentCacheModel<DefaultItemContainer<CustomDataItem>>()

        let content = PersistentCacheContent.customData
        let firstItem = content[firstKey]?.value
        let secondItem = content[secondKey]?.value
        let thirdItem = content[thirdKey]?.value

        await customCacheModel.restore(to: content)


        // Get different subsets of items by their modification date
        let itemsTo = await customCacheModel.items(to: afterSevenMinutes)
        let itemsFrom = await customCacheModel.items(from: afterSevenMinutes)
        let itemsInRange = await customCacheModel.items(from: afterThreeMinutes, to: afterSevenMinutes)


        XCTAssertEqual(itemsTo.count, 2)
        XCTAssertEqual(itemsTo[firstKey], firstItem)
        XCTAssertEqual(itemsTo[secondKey], secondItem)

        XCTAssertEqual(itemsFrom.count, 1)
        XCTAssertEqual(itemsFrom[thirdKey], thirdItem)

        XCTAssertEqual(itemsInRange.count, 1)
        XCTAssertEqual(itemsInRange[secondKey], secondItem)
    }


    // MARK: - Model management

    func testItems() async throws {
        let model = try XCTUnwrap(model)
        let items = await model.items()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[firstKey], 1)
        XCTAssertEqual(items[secondKey], 2)
    }

    func testItemForKey() async throws {
        let model = try XCTUnwrap(model)
        let firstValue = await model.item(forKey: firstKey)
        let unmanagedValue = await model.item(forKey: "unknown")

        XCTAssertEqual(firstValue, 1)
        XCTAssertNil(unmanagedValue)
    }

    func testAdd() async throws {
        let model = try XCTUnwrap(model)
        await model.add(3, forKey: thirdKey)

        let items = await model.items()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[firstKey], 1)
        XCTAssertEqual(items[secondKey], 2)
        XCTAssertEqual(items[thirdKey], 3)
    }

    func testRemove() async throws {
        let model = try XCTUnwrap(model)
        let initialCount = await model.items().count

        await model.remove(key: firstKey)
        let finalCount = await model.items().count

        XCTAssertEqual(initialCount, 2)
        XCTAssertEqual(finalCount, 1)

        let secondValue = await model.item(forKey: secondKey)
        XCTAssertEqual(secondValue, 2)
    }

    func testRemoveAll() async throws {
        let model = try XCTUnwrap(model)
        let initialCount = await model.items().count

        await model.removeAll()
        let finalCount = await model.items().count

        XCTAssertEqual(initialCount, 2)
        XCTAssertEqual(finalCount, 0)
    }

    func testRestore() async {
        let customCacheModel = PersistentCacheModel<DefaultItemContainer<CustomDataItem>>()
        let content = PersistentCacheContent.customData

        await customCacheModel.restore(to: content)

        let items = await customCacheModel.items()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[firstKey]?.text, "Hello")
        XCTAssertEqual(items[secondKey]?.text, "World")
        XCTAssertEqual(items[thirdKey]?.text, "!")
    }
}
