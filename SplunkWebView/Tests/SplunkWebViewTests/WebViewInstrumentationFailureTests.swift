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

import SplunkCommon
import WebKit
import XCTest

@testable import SplunkWebView

@MainActor
final class WebViewInstrumentationFailureTests: XCTestCase {

    func testInjectSessionId_whenBridgeScriptIsUnavailable_logsErrorAndAborts() {
        let webView = MockWKWebView()
        let logger = MockLogAgent()
        let sharedState = MockAgentSharedState(sessionId: "testing-session-id")
        let instrumentation = WebViewInstrumentation(
            logger: logger,
            sharedState: sharedState,
            bridgeScriptGenerator: { _, _, _ in nil }
        )

        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(webView.evaluateJavaScriptCallCount, 0)
        let errorFound = logger.logMessages.contains { $0.level == .error && $0.message.contains("bridge script is unavailable") }
        XCTAssertTrue(errorFound, "An error should be logged when the bridge script is unavailable")
    }
}
