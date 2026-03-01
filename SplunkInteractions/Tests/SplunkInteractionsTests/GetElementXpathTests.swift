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
import XCTest

@testable import SplunkInteractions

final class GetElementXpathTests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var interactions: Interactions!

    override func setUp() {
        super.setUp()
        interactions = Interactions(destination: TestInteractionDestination())
    }

    override func tearDown() {
        interactions = nil
        super.tearDown()
    }


    // MARK: - Nil input

    func testReturnsNilForNilNode() async {
        let result = await interactions.getElementXpath(from: nil)
        XCTAssertNil(result)
    }


    // MARK: - Single node

    func testSingleNodeWithoutIndexPath() async {
        let obj = NSObject()
        let node = MockViewNode(
            viewTypeName: "UIButton",
            viewId: ObjectIdentifier(obj)
        )

        let result = await interactions.getElementXpath(from: node)

        let expectedId = UInt(bitPattern: ObjectIdentifier(obj))
        XCTAssertEqual(result, "//UIButton[@id=\(expectedId)]")
    }

    func testSingleNodeWithIndexPath() async {
        let obj = NSObject()
        let node = MockViewNode(
            viewTypeName: "UITableViewCell",
            viewId: ObjectIdentifier(obj),
            indexPath: IndexPath(item: 3, section: 1)
        )

        let result = await interactions.getElementXpath(from: node)

        let expectedId = UInt(bitPattern: ObjectIdentifier(obj))
        XCTAssertEqual(result, "//UITableViewCell[@col=1,@row=3,@id=\(expectedId)]")
    }


    // MARK: - Node hierarchy

    func testTwoNodeHierarchy() async {
        let parentObj = NSObject()
        let childObj = NSObject()

        let parent = MockViewNode(
            viewTypeName: "UIView",
            viewId: ObjectIdentifier(parentObj)
        )
        let child = MockViewNode(
            viewTypeName: "UIButton",
            viewId: ObjectIdentifier(childObj),
            superNode: parent
        )

        let result = await interactions.getElementXpath(from: child)

        let expectedId = UInt(bitPattern: ObjectIdentifier(childObj))
        XCTAssertEqual(result, "//UIView/UIButton[@id=\(expectedId)]")
    }

    func testThreeNodeHierarchy() async {
        let obj1 = NSObject()
        let obj2 = NSObject()
        let obj3 = NSObject()

        let root = MockViewNode(
            viewTypeName: "UIWindow",
            viewId: ObjectIdentifier(obj1)
        )
        let middle = MockViewNode(
            viewTypeName: "UIView",
            viewId: ObjectIdentifier(obj2),
            superNode: root
        )
        let leaf = MockViewNode(
            viewTypeName: "UILabel",
            viewId: ObjectIdentifier(obj3),
            superNode: middle
        )

        let result = await interactions.getElementXpath(from: leaf)

        let expectedId = UInt(bitPattern: ObjectIdentifier(obj3))
        XCTAssertEqual(result, "//UIWindow/UIView/UILabel[@id=\(expectedId)]")
    }

    func testOnlyLeafNodeGetsDefaultId() async throws {
        let parentObj = NSObject()
        let childObj = NSObject()

        let parent = MockViewNode(
            viewTypeName: "UIView",
            viewId: ObjectIdentifier(parentObj)
        )
        let child = MockViewNode(
            viewTypeName: "UIButton",
            viewId: ObjectIdentifier(childObj),
            superNode: parent
        )

        let result = await interactions.getElementXpath(from: child)

        let xpath = try XCTUnwrap(result)
        // Parent should not have @id predicate (no custom id, not the leaf)
        XCTAssertTrue(xpath.hasPrefix("//UIView/"))
        XCTAssertFalse(xpath.contains("UIView["))
    }


    // MARK: - IndexPath in hierarchy

    func testIndexPathInHierarchyNode() async {
        let parentObj = NSObject()
        let cellObj = NSObject()

        let parent = MockViewNode(
            viewTypeName: "UITableView",
            viewId: ObjectIdentifier(parentObj)
        )
        let cell = MockViewNode(
            viewTypeName: "UITableViewCell",
            viewId: ObjectIdentifier(cellObj),
            indexPath: IndexPath(item: 2, section: 0),
            superNode: parent
        )

        let result = await interactions.getElementXpath(from: cell)

        let expectedId = UInt(bitPattern: ObjectIdentifier(cellObj))
        XCTAssertEqual(result, "//UITableView/UITableViewCell[@col=0,@row=2,@id=\(expectedId)]")
    }

    func testMiddleNodeWithIndexPath() async {
        let rootObj = NSObject()
        let middleObj = NSObject()
        let leafObj = NSObject()

        let root = MockViewNode(
            viewTypeName: "UITableView",
            viewId: ObjectIdentifier(rootObj)
        )
        let middle = MockViewNode(
            viewTypeName: "UITableViewCell",
            viewId: ObjectIdentifier(middleObj),
            indexPath: IndexPath(item: 5, section: 2),
            superNode: root
        )
        let leaf = MockViewNode(
            viewTypeName: "UILabel",
            viewId: ObjectIdentifier(leafObj),
            superNode: middle
        )

        let result = await interactions.getElementXpath(from: leaf)

        let expectedId = UInt(bitPattern: ObjectIdentifier(leafObj))
        XCTAssertEqual(result, "//UITableView/UITableViewCell[@col=2,@row=5]/UILabel[@id=\(expectedId)]")
    }


    // MARK: - Custom identifiers

    func testCustomIdOnLeafNode() async {
        let obj = NSObject()
        let node = MockViewNode(
            viewTypeName: "UIButton",
            viewId: ObjectIdentifier(obj)
        )

        interactions.register(customId: "submitButton", for: ObjectIdentifier(obj))
        try? await Task.sleep(nanoseconds: 200_000_000)

        let result = await interactions.getElementXpath(from: node)

        XCTAssertEqual(result, "//UIButton[@id='submitButton']")
    }

    func testCustomIdWithSingleQuoteIsEscaped() async {
        let obj = NSObject()
        let node = MockViewNode(
            viewTypeName: "UIButton",
            viewId: ObjectIdentifier(obj)
        )

        interactions.register(customId: "it's a button", for: ObjectIdentifier(obj))
        try? await Task.sleep(nanoseconds: 200_000_000)

        let result = await interactions.getElementXpath(from: node)

        XCTAssertEqual(result, "//UIButton[@id='it\\'s a button']")
    }
}
