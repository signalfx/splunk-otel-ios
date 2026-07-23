//
/*
Copyright 2026 Splunk Inc.

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
@testable import SplunkCustomTracking

/// Tests for the explicit-stacktrace error tracking path used by the hybrid
/// agents (React Native, Flutter), where the type, message, and stacktrace are
/// supplied by the caller rather than derived from the native runtime.
final class CustomErrorTrackingExplicitTests: XCTestCase {
    private var module: CustomTrackingInternal?
    private var capturedData: CustomTrackingData?
    private var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()

        module = CustomTrackingInternal()
        expectation = XCTestExpectation(description: "onPublishBlock for error was called")

        module?.onPublishBlock = { [weak self] _, data in
            self?.capturedData = data
            self?.expectation?.fulfill()
        }
    }

    override func tearDown() {
        module = nil
        capturedData = nil
        expectation = nil

        super.tearDown()
    }

    func testTrackError_explicit_setsTypeMessageAndVerbatimStacktrace() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        let stacktrace = """
            TypeError: x is not a function
                at f (index.bundle:1:537284)
                at g (index.bundle:1:537300)
            """
        let issue = SplunkExplicitIssue(typeName: "TypeError", message: "x is not a function", stacktrace: stacktrace)
        let attributes: [String: EventAttributeValue] = ["screen.name": .string("Cart")]

        module.trackError(issue, attributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)

        // The explicit path names the span after the exception type, not "error".
        XCTAssertEqual(data.name, "TypeError")
        XCTAssertEqual(data.component, "error")
        XCTAssertEqual(getStringValue(for: "error", in: data), "true")
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "TypeError")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), "x is not a function")

        // The supplied stack is emitted verbatim - no native frames are derived or appended.
        XCTAssertEqual(getStringValue(for: "exception.stacktrace", in: data), stacktrace)
        XCTAssertEqual(getStringValue(for: "screen.name", in: data), "Cart")
    }

    func testTrackError_explicit_withNilStacktrace_omitsStacktrace() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        let issue = SplunkExplicitIssue(typeName: "Error", message: "Something failed", stacktrace: nil)
        module.trackError(issue, [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertEqual(data.name, "Error")
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "Error")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), "Something failed")
        XCTAssertNil(data.attributes["exception.stacktrace"])
    }

    func testTrackError_explicit_withEmptyType_fallsBackToErrorSpanName() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        let issue = SplunkExplicitIssue(typeName: "", message: "msg", stacktrace: nil)
        module.trackError(issue, [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertEqual(data.name, "error")
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "")
    }

    func testTrackError_explicit_internalAttributesTakePrecedence() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        let issue = SplunkExplicitIssue(typeName: "TypeError", message: "real message", stacktrace: nil)
        let conflicting: [String: EventAttributeValue] = [
            "exception.type": .string("Spoofed"),
            "exception.message": .string("Spoofed"),
            "error": .string("false"),
            "error.source": .string("custom"),
            "exception.escaped": .string("false")
        ]
        module.trackError(issue, conflicting)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)

        // Internal exception attributes win over caller-supplied conflicts.
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "TypeError")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), "real message")
        XCTAssertEqual(getStringValue(for: "error", in: data), "true")

        // Caller-only attributes (e.g. those the hybrid layer adds) still pass through.
        XCTAssertEqual(getStringValue(for: "error.source", in: data), "custom")
        XCTAssertEqual(getStringValue(for: "exception.escaped", in: data), "false")
    }

    func testSplunkExplicitIssue_keepsShortMessageAndStacktraceVerbatim() {
        let issue = SplunkExplicitIssue(typeName: "TypeError", message: "short", stacktrace: "at f (index.bundle:1:1)")

        XCTAssertEqual(issue.exceptionType, "TypeError")
        XCTAssertEqual(issue.message, "short")
        XCTAssertEqual(issue.stacktrace?.formatted, "at f (index.bundle:1:1)")
    }

    func testSplunkExplicitIssue_truncatesOversizeMessage() {
        let longMessage = String(repeating: "a", count: SplunkExplicitIssue.messageCharacterLimit + 100)
        let issue = SplunkExplicitIssue(typeName: "TypeError", message: longMessage, stacktrace: nil)

        // Oversized messages are truncated to the limit plus a single ellipsis marker.
        XCTAssertEqual(issue.message.count, SplunkExplicitIssue.messageCharacterLimit + 1)
        XCTAssertTrue(issue.message.hasSuffix("…"))
    }
}
