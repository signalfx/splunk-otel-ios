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
@testable import SplunkWebView
import WebKit
import XCTest

final class WebViewInstrumentationInternalTests: XCTestCase {

    var webViewInstrumentation: WebViewInstrumentationInternal!
    var mockWebView: MockWebView!

    override func setUp() {
        super.setUp()
        webViewInstrumentation = WebViewInstrumentationInternal()
        mockWebView = MockWebView()
        webViewInstrumentation.sharedState = MockAgentSharedState()
    }

    override func tearDown() {
        webViewInstrumentation = nil
        mockWebView = nil
        super.tearDown()
    }

    func testInjectSessionId() {
        let expectation = XCTestExpectation(description: "JavaScript injected")

        mockWebView.evaluateJavaScriptHandler = { script, completionHandler in
            // Assert that the script is the expected script
            XCTAssertTrue(script.contains("window.SplunkRumNative"))
            XCTAssertTrue(script.contains("getNativeSessionId"))
            XCTAssertTrue(script.contains("cachedSessionId"))
            expectation.fulfill()
            completionHandler(nil, nil) // Simulate success
        }

        webViewInstrumentation.injectSessionId(into: mockWebView)

        wait(for: [expectation], timeout: 1.0)
    }

    // Add more tests here to cover error cases, etc.
}

// Mock WKWebView for testing
class MockWebView: WKWebView {
    var evaluateJavaScriptHandler: ((String, @escaping (Any?, Error?) -> Void) -> Void)?

    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        if Thread.isMainThread {
            self.evaluateJavaScriptHandler?(javaScriptString, completionHandler ?? { _, _ in })
        } else {
            DispatchQueue.main.async {
                self.evaluateJavaScriptHandler?(javaScriptString, completionHandler ?? { _, _ in })
            }
        }
    }
}

class MockAgentSharedState: AgentSharedState {
    var sessionId: String = "testing-session-id"
    var agentVersion: String = "testing-agent-version"

    func applicationState(for timestamp: Date) -> String? {
        "testing"
    }
}
