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

@testable import SplunkAgent
import XCTest

final class SessionReplayEventIndexerTests: XCTestCase {

    // MARK: - Basic logic
    // TODO: [DEMRUM-2782] Fix tests
//    func testInitialization() throws {
//        let indexerName = "testDefault"
//        let indexer = SessionReplayEventIndexer(named: indexerName)
//
//        XCTAssertNotNil(indexer)
//        XCTAssertEqual(indexer.name, indexerName)
//    }


    // MARK: - Indexer methods

    func testIndexer() async throws {
        var indexer: EventIndexer?
        let indexerName = "testReplay"

        let firstId = "12345"
        let secondId = "67890"


        // Initialize a new indexer
        indexer = SessionReplayIndexerTestBuilder.build(named: indexerName)

        // We will ask for the creation of a set of indexes
        let firstOneDate = Date() - 10
        let firstOne = try await indexer?.prepareIndex(sessionId: firstId, eventTimestamp: firstOneDate)

        let firstTwoDate = Date() - 5
        let firstTwo = try await indexer?.prepareIndex(sessionId: firstId, eventTimestamp: firstTwoDate)

        let secondOneDate = Date() - 7
        let secondOne = try await indexer?.prepareIndex(sessionId: secondId, eventTimestamp: secondOneDate)

        // Simulate recovery after restart
        indexer = nil
        sleep(1)


        indexer = SessionReplayIndexerTestBuilder.build(named: indexerName)
        sleep(1)

        // Ask for another set after recovery
        let firstThreeDate = Date()
        let firstThree = try await indexer?.prepareIndex(sessionId: firstId, eventTimestamp: firstThreeDate)

        let secondTwoDate = Date() - 2
        let secondTwo = try await indexer?.prepareIndex(sessionId: secondId, eventTimestamp: secondTwoDate)


        // Clean corresponding storage
        try SessionReplayIndexerTestBuilder.removeStorage(named: indexerName)

        // Indexes should be aligned properly within their respective sessions
        XCTAssertEqual(firstOne, 1)
        XCTAssertEqual(firstTwo, 2)
        XCTAssertEqual(firstThree, 3)

        XCTAssertEqual(secondOne, 1)
        XCTAssertEqual(secondTwo, 2)
    }

    // TODO: [DEMRUM-2782] Fix tests
//    func testRemoveIndex() async throws {
//        let indexerName = "testRemoveIndex"
//        let indexer = SessionReplayIndexerTestBuilder.build(named: indexerName)
//
//        let sessionId = "12321"
//
//        // We will ask for the creation of a set of indexes
//        let firstDate = Date() - 10
//        let firstIndex = try await indexer.prepareIndex(sessionId: sessionId, eventTimestamp: firstDate)
//
//        let secondDate = Date() - 5
//        let secondIndex = try await indexer.prepareIndex(sessionId: sessionId, eventTimestamp: secondDate)
//
//
//        // Remove processed indexes
//        try await indexer.removeIndex(sessionId: sessionId, eventTimestamp: firstDate)
//        try await indexer.removeIndex(sessionId: sessionId, eventTimestamp: secondDate)
//
//
//        // Get a new index for the same session
//        let thirdDate = Date()
//        let thirdIndex = try await indexer.prepareIndex(sessionId: sessionId, eventTimestamp: thirdDate)
//
//        // Clean corresponding storage
//        try SessionReplayIndexerTestBuilder.removeStorage(named: indexerName)
//
//
//        // Indexes should correspond to the expected series
//        XCTAssertEqual(firstIndex, 1)
//        XCTAssertEqual(secondIndex, 2)
//        XCTAssertEqual(thirdIndex, 3)
//    }
}
