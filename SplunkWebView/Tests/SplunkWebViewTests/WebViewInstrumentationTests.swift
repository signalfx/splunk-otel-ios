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
    private var mockWebView: MockWebView?
    private var mockAgentSharedState: MockAgentSharedState?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()
        webViewInstrumentation = WebViewInstrumentation()
        mockWebView = MockWebView()
        // strong instance for testing
        mockAgentSharedState = MockAgentSharedState()
        webViewInstrumentation?.sharedState = mockAgentSharedState
    }

    override func tearDown() {
        webViewInstrumentation = nil
        mockWebView = nil
        mockAgentSharedState = nil
        super.tearDown()
    }


    // MARK: - Business logic

    func testInjectSessionId() throws {
        let mockWebView = try XCTUnwrap(mockWebView)
        let expectation = XCTestExpectation(description: "JavaScript injected")

        mockWebView.evaluateJavaScriptHandler = { script, completionHandler in
            XCTAssertTrue(script.contains("window.SplunkRumNative"))
            XCTAssertTrue(script.contains("getNativeSessionId"))
            expectation.fulfill()
            completionHandler(nil, nil) // Simulate success
        }

        webViewInstrumentation?.injectSessionId(into: mockWebView)

        // TODO: [DEMRUM-2125] Fix test
        //        wait(for: [expectation], timeout: 5.0)
    }
}

/// Mock `WKWebView` for testing.
final class MockWebView: WKWebView {
    var evaluateJavaScriptHandler: ((String, @escaping (Any?, Error?) -> Void) -> Void)?

    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        if Thread.isMainThread {
            evaluateJavaScriptHandler?(javaScriptString, completionHandler ?? { _, _ in })
        }
        else {
            DispatchQueue.main.async {
                self.evaluateJavaScriptHandler?(javaScriptString, completionHandler ?? { _, _ in })
            }
        }
    }
}

final class MockAgentSharedState: AgentSharedState {
    let sessionId: String = "testing-session-id"
    let agentVersion: String = "testing-agent-version"

    func applicationState(for _: Date) -> String? {
        "testing"
    }
}
