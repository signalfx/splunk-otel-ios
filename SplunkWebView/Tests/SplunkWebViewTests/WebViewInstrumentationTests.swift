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

import SplunkCommon
import WebKit
import XCTest

@testable import SplunkWebView

final class WebViewInstrumentationTests: XCTestCase {

    // MARK: - Private

    private var webViewInstrumentation: WebViewInstrumentation?
    private var mockWebView: MockWKWebView?
    private var mockAgentSharedState: MockAgentSharedState?
    private var mockLogAgent: MockLogAgent?


    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockLogAgent = MockLogAgent()
        mockAgentSharedState = MockAgentSharedState(sessionId: "testing-session-id")
        mockWebView = MockWKWebView()

        let logAgent = try XCTUnwrap(mockLogAgent)
        let sharedState = try XCTUnwrap(mockAgentSharedState)
        webViewInstrumentation = WebViewInstrumentation(logger: logAgent, sharedState: sharedState)
    }

    override func tearDownWithError() throws {
        webViewInstrumentation = nil
        mockWebView = nil
        mockAgentSharedState = nil
        mockLogAgent = nil
        try super.tearDownWithError()
    }


    // MARK: - Injection Tests

    func testInjectSessionId_addsUserScriptAndMessageHandler() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockContentController = mockWebView.configuration.userContentController as? MockWKUserContentController

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        XCTAssertNotNil(mockContentController)
        XCTAssertTrue(mockContentController?.addUserScriptCalled ?? false)
        if #available(iOS 14.0, *) {
            XCTAssertTrue(mockContentController?.addScriptMessageHandlerCalled ?? false)
        }
        else {
            XCTAssertTrue(mockContentController?.addLegacyScriptMessageHandlerCalled ?? false)
        }
        XCTAssertEqual(mockContentController?.lastAddedMessageHandlerName, "SplunkRumNativeUpdate")
    }

    func testInjectSessionId_evaluatesJavaScript() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        // The new implementation calls evaluateJavaScript once for the immediate injection
        XCTAssertEqual(mockWebView.evaluateJavaScriptCallCount, 1)
        XCTAssertNotNil(mockWebView.lastEvaluatedJavaScript)
    }

    func testInjectSessionId_whenSharedStateIsNil_logsWarningAndAborts() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockLogAgent = try XCTUnwrap(mockLogAgent)
        // This tests the case where the entire sharedState object is missing.
        webViewInstrumentation?.sharedState = nil

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        XCTAssertEqual(mockWebView.evaluateJavaScriptCallCount, 0, "Should not evaluate JS if sharedState is nil")

        let messages = mockLogAgent.logMessages
        let warningFound = messages.contains { $0.level == .warn && $0.message.contains("Native Session ID not available") }
        XCTAssertTrue(warningFound, "A warning should be logged when sharedState is not available")
    }


    // MARK: - Usage Warning Tests

    func testInjectSessionId_whenWebViewIsAlreadyLoading_logsWarning() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockLogAgent = try XCTUnwrap(mockLogAgent)
        mockWebView.isLoading = true

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let warningFound = mockLogAgent.logMessages.contains { $0.level == .warn && $0.message.contains("has already started loading content") }
        XCTAssertTrue(warningFound, "A warning should be logged for a webview that is already loading.")
    }

    func testInjectSessionId_whenWebViewHasAlreadyLoadedURL_logsWarning() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockLogAgent = try XCTUnwrap(mockLogAgent)
        let url = try XCTUnwrap(URL(string: "https://www.splunk.com"))

        mockWebView.url = url

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let warningFound = mockLogAgent.logMessages.contains { $0.level == .warn && $0.message.contains("has already started loading content") }
        XCTAssertTrue(warningFound, "A warning should be logged for a webview that has a non-blank URL.")
    }

    func testInjectSessionId_whenWebViewIsNew_doesNotLogWarning() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockLogAgent = try XCTUnwrap(mockLogAgent)
        // A fresh mockWebView has isLoading = false and url = nil

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let warningFound = mockLogAgent.logMessages.contains { $0.level == .warn && $0.message.contains("has already started loading content") }
        XCTAssertFalse(warningFound, "A new webview should not trigger a usage warning.")
    }


    // MARK: - State Integrity Tests

    func testInjectSessionId_isIdempotent() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockContentController = mockWebView.configuration.userContentController as? MockWKUserContentController

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        XCTAssertNotNil(mockContentController)
        XCTAssertTrue(mockContentController?.removeScriptMessageHandlerCalled ?? false)
        XCTAssertTrue(mockContentController?.addScriptMessageHandlerCalled ?? false)
        XCTAssertEqual(mockWebView.evaluateJavaScriptCallCount, 1)

        // Call inject second time
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        // Then: The native side safely re-establishes the bridge.
        // The JS itself has an internal guard, so it won't re-initialize.
        // The evaluateJavaScript call will run again but the script will bail early.
        XCTAssertEqual(mockWebView.evaluateJavaScriptCallCount, 2)
    }

    func testInjectSessionId_addsUserScriptOnlyOnce_whenCalledMultipleTimes() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockContentController = mockWebView.configuration.userContentController as? MockWKUserContentController
        XCTAssertNotNil(mockContentController)

        // First injection adds the user script.
        webViewInstrumentation?.injectSessionId(into: mockWebView)
        // Second injection should not add the user script again.
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        XCTAssertEqual(mockContentController?.addUserScriptCallCount, 1, "User script should be added only once per webview.")
    }

    func testMessageHandler_whenSessionIdChanges_repliesWithNewSessionId() throws {
        guard #available(iOS 14.0, *) else {
            throw XCTSkip("WKScriptMessageHandlerWithReply requires iOS 14+")
        }
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockAgentSharedState = try XCTUnwrap(mockAgentSharedState)
        let webViewInstrumentation = try XCTUnwrap(webViewInstrumentation)

        let initialSessionId = "session-1"
        let updatedSessionId = "session-2"
        mockAgentSharedState.updateSessionId(initialSessionId)
        let mockMessage = MockWKScriptMessage(name: "SplunkRumNativeUpdate", body: [:])

        // First call
        let expectation1 = XCTestExpectation(description: "Reply handler should be called with initial session ID")
        let replyHandler1: @MainActor @Sendable (Any?, String?) -> Void = { reply, _ in
            let sessionId = (reply as? [String: String])?["sessionId"]
            XCTAssertEqual(sessionId, initialSessionId)
            expectation1.fulfill()
        }
        webViewInstrumentation.userContentController(mockWebView.configuration.userContentController, didReceive: mockMessage, replyHandler: replyHandler1)
        wait(for: [expectation1], timeout: 1.0)

        // Session ID changes and handler is called again
        mockAgentSharedState.updateSessionId(updatedSessionId)
        let expectation2 = XCTestExpectation(description: "Reply handler should be called with updated session ID")
        let replyHandler2: @MainActor @Sendable (Any?, String?) -> Void = { reply, _ in
            let sessionId = (reply as? [String: String])?["sessionId"]
            XCTAssertEqual(sessionId, updatedSessionId)
            expectation2.fulfill()
        }
        webViewInstrumentation.userContentController(mockWebView.configuration.userContentController, didReceive: mockMessage, replyHandler: replyHandler2)
        wait(for: [expectation2], timeout: 1.0)
    }


    // MARK: - JavaScript Content Tests

    func testJavascriptContent_containsSessionId() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockAgentSharedState = try XCTUnwrap(mockAgentSharedState)
        let expectedSessionId = "my-special-session-id"
        mockAgentSharedState.updateSessionId(expectedSessionId)

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let script = mockWebView.lastEvaluatedJavaScript ?? ""
        XCTAssertTrue(script.contains("cachedSessionId: '\(expectedSessionId)'"), "The injected script must contain the session ID")
    }

    func testJavascriptContent_hasCorrectApiFunctions() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let script = mockWebView.lastEvaluatedJavaScript ?? ""
        XCTAssertTrue(script.contains("getNativeSessionId: function()"), "JS should contain getNativeSessionId")
        XCTAssertTrue(script.contains("getNativeSessionIdAsync: async function()"), "JS should contain getNativeSessionIdAsync")
        XCTAssertTrue(script.contains("onNativeSessionIdChanged: null"), "JS should contain onNativeSessionIdChanged")
        XCTAssertTrue(script.contains("window.SplunkRumNative"), "JS should define window.SplunkRumNative")
    }

    func testJavascriptContent_includesPostMessagePromiseGuards() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let script = mockWebView.lastEvaluatedJavaScript ?? ""
        XCTAssertTrue(script.contains("postMessage handler is unavailable"), "JS should guard missing handler")
        XCTAssertTrue(script.contains("postMessage did not return a Promise"), "JS should guard non-promise return")
    }

    func testJavascriptContent_avoidsOptionalChainingForLegacyIOS() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        webViewInstrumentation?.injectSessionId(into: mockWebView)

        let script = mockWebView.lastEvaluatedJavaScript ?? ""
        XCTAssertFalse(script.contains("?."), "JS should avoid optional chaining for iOS 13.0")
        XCTAssertTrue(script.contains("window.webkit &&"), "JS should use explicit guards for WebKit access")
    }


    // MARK: - Message Handler Tests

    func testMessageHandler_whenSessionIdIsValid_repliesWithSessionId() throws {
        guard #available(iOS 14.0, *) else {
            throw XCTSkip("WKScriptMessageHandlerWithReply requires iOS 14+")
        }
        let mockWebView = try XCTUnwrap(mockWebView)
        let mockAgentSharedState = try XCTUnwrap(mockAgentSharedState)
        let webViewInstrumentation = try XCTUnwrap(webViewInstrumentation)
        let expectedSessionId = "valid-session-id-for-reply"
        mockAgentSharedState.updateSessionId(expectedSessionId)
        let mockMessage = MockWKScriptMessage(name: "SplunkRumNativeUpdate", body: [:])
        let expectation = XCTestExpectation(description: "Reply handler should be called with session ID")

        let replyHandler: @MainActor @Sendable (Any?, String?) -> Void = { reply, error in
            XCTAssertNil(error)
            XCTAssertNotNil(reply)
            guard let replyDict = reply as? [String: String] else {
                XCTFail("Reply should be a dictionary")
                return
            }

            XCTAssertEqual(replyDict["sessionId"], expectedSessionId)
            expectation.fulfill()
        }

        webViewInstrumentation.userContentController(mockWebView.configuration.userContentController, didReceive: mockMessage, replyHandler: replyHandler)

        wait(for: [expectation], timeout: 1.0)
    }

    func testMessageHandler_whenSharedStateIsNil_repliesWithError() throws {
        guard #available(iOS 14.0, *) else {
            throw XCTSkip("WKScriptMessageHandlerWithReply requires iOS 14+")
        }
        let mockWebView = try XCTUnwrap(mockWebView)
        let webViewInstrumentation = try XCTUnwrap(webViewInstrumentation)
        webViewInstrumentation.sharedState = nil
        let mockMessage = MockWKScriptMessage(name: "SplunkRumNativeUpdate", body: [:])
        let expectation = XCTestExpectation(description: "Reply handler should be called with an error")

        let replyHandler: @MainActor @Sendable (Any?, String?) -> Void = { reply, error in
            XCTAssertNil(reply)
            XCTAssertNotNil(error)
            XCTAssertEqual(error, "Native Session ID not available")
            expectation.fulfill()
        }

        webViewInstrumentation.userContentController(mockWebView.configuration.userContentController, didReceive: mockMessage, replyHandler: replyHandler)

        wait(for: [expectation], timeout: 1.0)
    }
}
