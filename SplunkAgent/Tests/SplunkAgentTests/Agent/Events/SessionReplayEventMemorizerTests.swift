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

final class SessionReplayEventMemorizerTests: XCTestCase {

    // MARK: - Basic logic

    func testInitialization() throws {
        let memorizerName = "testDefault"
        let memorizer = SessionReplayEventMemorizer(named: memorizerName)

        XCTAssertNotNil(memorizer)
        XCTAssertEqual(memorizer.name, memorizerName)
    }


    // MARK: - Memorizer methods

    func testMemorizer() async throws {
        var memorizer: SessionReplayEventMemorizer?
        let memorizerName = "testReplay"

        let firstKey = "item-1"
        let secondKey = "item-2"

        // Initialize a new memorizer
        memorizer = try await SessionReplayMemorizerTestBuilder.build(named: memorizerName)
        try await wait(for: memorizer)

        let initialFirstMemorized = try await memorizer?.isMemorized(eventKey: firstKey)
        let initialSecondMemorized = try await memorizer?.isMemorized(eventKey: secondKey)

        // Mark first as memorized
        try await memorizer?.markAsMemorized(eventKey: firstKey)

        let firstMemorized = try await memorizer?.isMemorized(eventKey: firstKey)
        let secondMemorized = try await memorizer?.isMemorized(eventKey: secondKey)

        // Simulate recovery after restart
        memorizer = nil
        try await Task.sleep(nanoseconds: 1_000_000_000)


        memorizer = try await SessionReplayMemorizerTestBuilder.build(named: memorizerName)
        try await wait(for: memorizer)


        // Now should persist memorized status
        let isStillFirstMemorized = try await memorizer?.isMemorized(eventKey: firstKey)
        let isStillSecondMemorized = try await memorizer?.isMemorized(eventKey: secondKey)


        // Clean corresponding storage
        try SessionReplayMemorizerTestBuilder.removeStorage(named: memorizerName)

        // Initially, nothing is memorized
        XCTAssertFalse(try XCTUnwrap(initialFirstMemorized))
        XCTAssertFalse(try XCTUnwrap(initialSecondMemorized))

        // Changes are saved
        XCTAssertTrue(try XCTUnwrap(firstMemorized))
        XCTAssertFalse(try XCTUnwrap(secondMemorized))

        // Changes are restored
        XCTAssertTrue(try XCTUnwrap(isStillFirstMemorized))
        XCTAssertFalse(try XCTUnwrap(isStillSecondMemorized))
    }


    // MARK: - Private methods

    private func wait(for memorizer: EventMemorizer?) async throws {
        // Wait for the memorizer until it is fully operational
        while await memorizer?.isReady == false {
            // Sleep for another 100 ms
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
