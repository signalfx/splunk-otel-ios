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

@testable import SplunkNetwork

final class IgnoreURLsTests: XCTestCase {

    // MARK: - Initialization Tests

    func testEmptyInitializer() {
        let ignoreURLs = IgnoreURLs()
        XCTAssertEqual(ignoreURLs.count(), 0)
        XCTAssertEqual(ignoreURLs.getAllPatterns().count, 0)
    }

    func testInitializerWithValidPatterns() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)
        XCTAssertEqual(ignoreURLs.count(), 2)
        XCTAssertEqual(Set(ignoreURLs.getAllPatterns()), patterns)
    }

    func testInitializerWithInvalidPatterns() {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            "[A-Z", // Invalid pattern - missing closing bracket
            ".*/api/.*"
        ])

        XCTAssertThrowsError(try IgnoreURLs(patterns: patterns))
    }

    // MARK: - Pattern Management Tests

    func testAddPatterns() throws {
        let ignoreURLs = IgnoreURLs()
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let addedCount = try ignoreURLs.addPatterns(patterns)
        XCTAssertEqual(addedCount, 2)
        XCTAssertEqual(ignoreURLs.count(), 2)
        XCTAssertEqual(Set(ignoreURLs.getAllPatterns()), patterns)
    }

    func testAddDuplicatePatterns() throws {
        let initialPatterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: initialPatterns)

        // Try to add the same patterns again
        let addedCount = try ignoreURLs.addPatterns(initialPatterns)
        XCTAssertEqual(addedCount, 0) // No new patterns added
        XCTAssertEqual(ignoreURLs.count(), 2) // Count remains the same
        XCTAssertEqual(Set(ignoreURLs.getAllPatterns()), initialPatterns)
    }

    func testAddInvalidPatterns() throws {
        let ignoreURLs = IgnoreURLs()
        let validPatterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        // First add valid patterns
        _ = try ignoreURLs.addPatterns(validPatterns)
        XCTAssertEqual(ignoreURLs.count(), 2)

        // Then try to add invalid patterns
        let invalidPatterns = Set([
            ".*\\.(pdf|doc)$",
            "[A-Z", // Invalid pattern
            ".*/downloads/.*"
        ])

        XCTAssertThrowsError(try ignoreURLs.addPatterns(invalidPatterns))

        // Verify that the original patterns are still intact
        XCTAssertEqual(ignoreURLs.count(), 2)
        XCTAssertEqual(Set(ignoreURLs.getAllPatterns()), validPatterns)
    }

    func testClearPatterns() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)
        XCTAssertEqual(ignoreURLs.count(), 2)

        let clearedCount = ignoreURLs.clearPatterns()
        XCTAssertEqual(clearedCount, 2)
        XCTAssertEqual(ignoreURLs.count(), 0)
        XCTAssertEqual(ignoreURLs.getAllPatterns().count, 0)
    }

    // MARK: - URL Matching Tests

    func testMatchesWithStringURLs() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)

        // Test matching URLs
        XCTAssertTrue(ignoreURLs.matches("https://example.com/image.jpg"))
        XCTAssertTrue(ignoreURLs.matches("https://api.example.com/users"))

        // Test non-matching URLs
        XCTAssertFalse(ignoreURLs.matches("https://example.com/page.html"))
        XCTAssertFalse(ignoreURLs.matches("https://example.com/document.pdf"))
    }

    func testMatchesWithURLObjects() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)

        // Test matching URLs
        XCTAssertTrue(ignoreURLs.matches(url: URL(string: "https://example.com/image.jpg")!))
        XCTAssertTrue(ignoreURLs.matches(url: URL(string: "https://api.example.com/users")!))

        // Test non-matching URLs
        XCTAssertFalse(ignoreURLs.matches(url: URL(string: "https://example.com/page.html")!))
        XCTAssertFalse(ignoreURLs.matches(url: URL(string: "https://example.com/document.pdf")!))
    }

    func testMatchesWithEmptyPatterns() {
        let ignoreURLs = IgnoreURLs()

        // No patterns should mean no matches
        XCTAssertFalse(ignoreURLs.matches("https://example.com/image.jpg"))
    }

    // MARK: - Edge Cases

    func testMatchesWithEmptyURLs() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)
        XCTAssertFalse(ignoreURLs.matches(""))
    }

    func testMatchesWithInvalidURLs() throws {
        let patterns = Set([
            ".*\\.(jpg|jpeg|png|gif)$",
            ".*/api/.*"
        ])

        let ignoreURLs = try IgnoreURLs(patterns: patterns)
        XCTAssertFalse(ignoreURLs.matches("not a url"))
    }
}
