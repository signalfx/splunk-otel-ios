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
@testable import SplunkCustomTracking

final class CustomErrorTrackingTests: XCTestCase {
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

    func testTrackError_withString() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        let errorMessage = "Failed to load resource from network."
        let attributes: [String: EventAttributeValue] = ["resource_url": .string("http://example.com/data.json")]
        let issue = SplunkIssue(from: errorMessage)

        module.track(issue, attributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        assertCommonErrorAttributes(in: data)
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "String")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), errorMessage)
        XCTAssertNil(data.attributes["exception.stacktrace"])
        XCTAssertNil(data.attributes["exception.images"])
        XCTAssertEqual(getStringValue(for: "resource_url", in: data), "http://example.com/data.json")
    }

    func testTrackError_withSwiftError() throws {
        struct FileError: Error, LocalizedError {
            let path: String
            var errorDescription: String? {
                "File not found at \(path)"
            }
        }

        let error = FileError(path: "/tmp/file.txt")
        let attributes: [String: EventAttributeValue] = ["file_permissions": .string("read-only")]
        let issue = SplunkIssue(from: error)

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.track(issue, attributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        assertCommonErrorAttributes(in: data)
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "FileError")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), "File not found at /tmp/file.txt")
        XCTAssertNotNil(getStringValue(for: "exception.stacktrace", in: data))
        XCTAssertNotNil(getStringValue(for: "exception.threads", in: data))
        XCTAssertEqual(getStringValue(for: "file_permissions", in: data), "read-only")
    }

    func testTrackError_withNSError() throws {
        let domain = "com.splunk.test"
        let code = 404
        let userInfo = [NSLocalizedDescriptionKey: "The requested item was not found."]
        let nsError = NSError(domain: domain, code: code, userInfo: userInfo)
        let attributes: [String: EventAttributeValue] = ["request_id": .string("uuid-1234")]
        let issue = SplunkIssue(from: nsError)

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.track(issue, attributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        assertCommonErrorAttributes(in: data)
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "NSError")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), userInfo[NSLocalizedDescriptionKey])
        XCTAssertNotNil(getStringValue(for: "exception.stacktrace", in: data))
        XCTAssertNotNil(getStringValue(for: "exception.threads", in: data))
        XCTAssertEqual(getIntValue(for: "code", in: data), code)
        XCTAssertEqual(getStringValue(for: "domain", in: data), domain)
        XCTAssertEqual(getStringValue(for: "request_id", in: data), "uuid-1234")
    }

    func testTrackException_withNSException() throws {
        let exceptionName = NSExceptionName("TestException")
        let reason = "A test exception was thrown."
        let nsException = NSException(name: exceptionName, reason: reason, userInfo: nil)
        let attributes: [String: EventAttributeValue] = ["context": .string("testing_exception_handler")]
        let issue = SplunkIssue(from: nsException)

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.track(issue, attributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        assertCommonErrorAttributes(in: data)
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), exceptionName.rawValue)
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), reason)
        XCTAssertNotNil(getStringValue(for: "exception.stacktrace", in: data))
        XCTAssertNotNil(getStringValue(for: "exception.threads", in: data))
        XCTAssertEqual(getStringValue(for: "context", in: data), "testing_exception_handler")
    }

    func testAttributeMergingLogic_internalTakesPrecedence() throws {
        let errorMessage = "Conflict test"
        let conflictingAttributes: [String: EventAttributeValue] = [
            "exception.type": .string("UserProvidedType"),
            "exception.message": .string("UserProvidedMessage"),
            "error": .string("false")
        ]
        let issue = SplunkIssue(from: errorMessage)

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.track(issue, conflictingAttributes)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        assertCommonErrorAttributes(in: data)
        XCTAssertEqual(getStringValue(for: "exception.type", in: data), "String")
        XCTAssertEqual(getStringValue(for: "exception.message", in: data), errorMessage)
    }

    func testSplunkIssue_from_String() {
        let message = "A simple string error."
        let issue = SplunkIssue(from: message)
        let attributes = issue.toAttributesDictionary()

        XCTAssertEqual(issue.message, message)
        XCTAssertEqual(issue.exceptionType, "String")
        XCTAssertNil(issue.stacktrace)
        XCTAssertEqual(getStringValue(for: "exception.type", in: attributes), "String")
        XCTAssertEqual(getStringValue(for: "exception.message", in: attributes), message)
        XCTAssertNil(attributes["exception.stacktrace"])
    }

    func testSplunkIssue_from_Error() {

        struct MyTestError: Error, LocalizedError {
            var errorDescription: String? {
                "This is a test error."
            }
        }

        let error = MyTestError()
        let issue = SplunkIssue(from: error)
        let attributes = issue.toAttributesDictionary()

        XCTAssertEqual(issue.message, "This is a test error.")
        XCTAssertEqual(issue.exceptionType, "MyTestError")
        XCTAssertNotNil(issue.stacktrace)
        XCTAssertEqual(getStringValue(for: "exception.type", in: attributes), "MyTestError")
        XCTAssertEqual(getStringValue(for: "exception.message", in: attributes), "This is a test error.")
        XCTAssertNotNil(attributes["exception.stacktrace"])
        XCTAssertNotNil(attributes["exception.threads"])
    }

    func testSplunkIssue_from_NSError() {
        let nsError = NSError(domain: "test.domain", code: 123, userInfo: [NSLocalizedDescriptionKey: "An NSError occurred."])
        let issue = SplunkIssue(from: nsError)
        let attributes = issue.toAttributesDictionary()

        XCTAssertEqual(issue.message, "An NSError occurred.")
        XCTAssertEqual(issue.exceptionType, "NSError")
        XCTAssertNotNil(issue.stacktrace)
        XCTAssertEqual(issue.exceptionCode, .int(123))
        XCTAssertEqual(issue.codeNamespace, "test.domain")
        XCTAssertEqual(getIntValue(for: "code", in: attributes), 123)
        XCTAssertEqual(getStringValue(for: "domain", in: attributes), "test.domain")
        XCTAssertNotNil(attributes["exception.stacktrace"])
        XCTAssertNotNil(attributes["exception.threads"])
    }

    func testSplunkIssue_from_NSException() {
        let exception = NSException(name: .internalInconsistencyException, reason: "Inconsistent state.", userInfo: nil)
        let issue = SplunkIssue(from: exception)
        let attributes = issue.toAttributesDictionary()

        XCTAssertEqual(issue.message, "Inconsistent state.")
        XCTAssertEqual(issue.exceptionType, "NSInternalInconsistencyException")
        XCTAssertNotNil(issue.stacktrace)
        XCTAssertEqual(getStringValue(for: "exception.type", in: attributes), "NSInternalInconsistencyException")
        XCTAssertEqual(getStringValue(for: "exception.message", in: attributes), "Inconsistent state.")
        XCTAssertNotNil(attributes["exception.stacktrace"])
        XCTAssertNotNil(attributes["exception.threads"])
    }

    func testTrackError_withSwiftError_attachesImagesWhenEnabled() throws {
        struct FileError: Error, LocalizedError {
            var errorDescription: String? {
                "File not found"
            }
        }

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.install(
            with: CustomTrackingConfiguration(includeBinaryImagesOnErrors: true),
            remoteConfiguration: nil
        )

        let issue = SplunkIssue(from: FileError())
        module.track(issue, [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        let imagesJSON = try XCTUnwrap(getStringValue(for: "exception.images", in: data))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [Any])

        XCTAssertFalse(parsed.isEmpty)
        try assertImagesMatchEmittedThreads(in: data)
        try assertThreadsContainResolvedImagePath(in: data)
    }

    func testTrackError_withSwiftError_omitsImagesWhenDisabled() throws {
        struct FileError: Error, LocalizedError {
            var errorDescription: String? {
                "File not found"
            }
        }

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.install(
            with: CustomTrackingConfiguration(includeBinaryImagesOnErrors: false),
            remoteConfiguration: nil
        )

        let issue = SplunkIssue(from: FileError())
        module.track(issue, [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertNil(data.attributes["exception.images"])
    }

    func testTrackException_attachesImages() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.install(
            with: CustomTrackingConfiguration(includeBinaryImagesOnErrors: true),
            remoteConfiguration: nil
        )

        let nsException = NSException(name: NSExceptionName("TestException"), reason: "reason", userInfo: nil)
        let issue = SplunkIssue(from: nsException)
        module.track(issue, [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        let imagesJSON = try XCTUnwrap(getStringValue(for: "exception.images", in: data))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [Any])

        XCTAssertFalse(parsed.isEmpty)
        try assertImagesMatchEmittedThreads(in: data)
        try assertThreadsContainResolvedImagePath(in: data)
    }

    // MARK: - Explicit stacktrace error tracking

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

    private func assertCommonErrorAttributes(in data: CustomTrackingData, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(data.name, "error", file: file, line: line)
        XCTAssertEqual(data.component, "error", file: file, line: line)
        XCTAssertEqual(getStringValue(for: "error", in: data), "true", file: file, line: line)
    }
}

private func assertImagesMatchEmittedThreads(
    in data: CustomTrackingData,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let threadsJSON = try XCTUnwrap(stringValue(for: "exception.threads", in: data), file: file, line: line)
    let imagesJSON = try XCTUnwrap(stringValue(for: "exception.images", in: data), file: file, line: line)

    let threads = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]],
        file: file,
        line: line
    )
    let images = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [[String: Any]],
        file: file,
        line: line
    )

    var emittedImageNames: Set<String> = []

    for thread in threads {
        let stackFrames = thread["stackFrames"] as? [[String: Any]] ?? []

        for stackFrame in stackFrames {
            guard let imageName = stackFrame["imageName"] as? String else {
                continue
            }

            emittedImageNames.formUnion(normalizedImageNames(imageName))
        }
    }

    XCTAssertFalse(emittedImageNames.isEmpty, file: file, line: line)

    for image in images {
        let imagePath = try XCTUnwrap(image["imagePath"] as? String, file: file, line: line)
        XCTAssertFalse(
            normalizedImageNames(imagePath).isDisjoint(with: emittedImageNames),
            file: file,
            line: line
        )
    }
}

private func assertThreadsContainResolvedImagePath(
    in data: CustomTrackingData,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let threadsJSON = try XCTUnwrap(stringValue(for: "exception.threads", in: data), file: file, line: line)
    let imagesJSON = try XCTUnwrap(stringValue(for: "exception.images", in: data), file: file, line: line)

    let threads = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]],
        file: file,
        line: line
    )
    let images = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [[String: Any]],
        file: file,
        line: line
    )

    let imagePaths = Set(images.compactMap { $0["imagePath"] as? String })
    var threadImageNames: Set<String> = []

    for thread in threads {
        let stackFrames = thread["stackFrames"] as? [[String: Any]] ?? []

        for stackFrame in stackFrames {
            if let imageName = stackFrame["imageName"] as? String {
                threadImageNames.insert(imageName)
            }
        }
    }

    XCTAssertFalse(imagePaths.isEmpty, file: file, line: line)
    XCTAssertFalse(threadImageNames.isDisjoint(with: imagePaths), file: file, line: line)
}

private func stringValue(for key: String, in data: CustomTrackingData) -> String? {
    if case let .string(value) = data.attributes[key] {
        return value
    }

    return nil
}
