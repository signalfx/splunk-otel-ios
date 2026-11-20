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

import WebKit
import XCTest

@testable import SplunkWebView

/// Covers the bridge while the agent has no session.
@MainActor
final class WebViewNoSessionTests: XCTestCase {

    func testInjectWithoutSessionEmptyId() throws {
        let sharedState = MockAgentSharedState(sessionId: "")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)

        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(controller.userScripts.count, 1)
        let script = try XCTUnwrap(webView.evaluatedJavaScripts.first)
        XCTAssertTrue(script.contains("cachedSessionId: ''"))
        XCTAssertFalse(script.contains("cachedSessionId: undefined"))
    }

    func testMessageHandlerRepliesEmptyThenCurrentId() async {
        let sharedState = MockAgentSharedState(sessionId: "")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = MockWKWebView()
        let message = MockWKScriptMessage(name: "SplunkRumNativeUpdate", body: [:])

        let noSessionReply = await bridgeReply(from: instrumentation, webView: webView, message: message)
        XCTAssertEqual(noSessionReply["sessionId"] as? String, "")

        sharedState.updateSessionId("foreground-session-id")

        let foregroundReply = await bridgeReply(from: instrumentation, webView: webView, message: message)
        XCTAssertEqual(foregroundReply["sessionId"] as? String, "foreground-session-id")
    }


    // MARK: - Helpers

    private func bridgeReply(
        from instrumentation: WebViewInstrumentation,
        webView: WKWebView,
        message: WKScriptMessage
    ) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            let replyHandler: @MainActor @Sendable (Any?, String?) -> Void = { reply, error in
                XCTAssertNil(error)
                continuation.resume(returning: reply as? [String: Any] ?? [:])
            }
            instrumentation.userContentController(
                webView.configuration.userContentController,
                didReceive: message,
                replyHandler: replyHandler
            )
        }
    }
}
