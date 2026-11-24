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

@_spi(SplunkInternal) @testable import SplunkWebView

/// Runs the bridge in a real web view whose session requests go to a handler that holds the replies.
@MainActor
final class WebViewBridgeRequestTests: XCTestCase {

    func testNewPageAsksNativeAtOnce() async throws {
        let page = try await loadPageWithHeldReplies()

        let requests = await waitForRequests(1, from: page.handler)
        XCTAssertEqual(requests, 1)
        page.handler.reply(0, sessionId: "native-session")

        let synchronous = try await waitForValue("native-session") { try await self.synchronousSessionId(in: page.webView) }
        XCTAssertEqual(synchronous, "native-session")
    }

    func testReplyOlderThanPushIsIgnored() async throws {
        let page = try await loadPageWithHeldReplies()
        _ = await waitForRequests(1, from: page.handler)

        try await push("pushed", into: page.webView)
        page.handler.reply(0, sessionId: "older")
        try await settle()
        let afterSyncReply = try await synchronousSessionId(in: page.webView)
        XCTAssertEqual(afterSyncReply, "pushed")

        _ = try await page.webView.evaluateJavaScript(
            "window.asyncResult = null; window.SplunkRumNative.getNativeSessionIdAsync()"
                + ".then(function(id) { window.asyncResult = id; }); 0;"
        )
        _ = await waitForRequests(2, from: page.handler)
        try await push("pushed-again", into: page.webView)
        page.handler.reply(1, sessionId: "older-again")

        let asyncResult = try await waitForValue("pushed-again") {
            try await page.webView.evaluateJavaScript("window.asyncResult") as? String
        }
        XCTAssertEqual(asyncResult, "pushed-again")
        let afterAsyncReply = try await synchronousSessionId(in: page.webView)
        XCTAssertEqual(afterAsyncReply, "pushed-again")
    }

    func testPageFromBackForwardCacheAsksNative() async throws {
        let page = try await loadPageWithHeldReplies()
        _ = await waitForRequests(1, from: page.handler)
        page.handler.reply(0, sessionId: "first-session")

        _ = try await page.webView.evaluateJavaScript(
            "window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: false })); 0;"
        )
        try await settle()
        XCTAssertEqual(page.handler.pendingReplies.count, 1, "A fresh page show must not ask again.")

        _ = try await page.webView.evaluateJavaScript(
            "window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })); 0;"
        )
        let requests = await waitForRequests(2, from: page.handler)
        XCTAssertEqual(requests, 2)
    }

    func testUnsettledRequestBlocksRefreshForAtMostFiveSeconds() async throws {
        let page = try await loadPageWithHeldReplies()
        _ = await waitForRequests(1, from: page.handler)

        // The first request never gets a reply. Make it look older than the 5 s window.
        _ = try await page.webView.evaluateJavaScript(
            "window.SplunkRumNative._lastCheckTime -= 6000; window.SplunkRumNative.getNativeSessionId(); 0;"
        )

        let requests = await waitForRequests(2, from: page.handler)
        XCTAssertEqual(requests, 2)
    }


    // MARK: - Helpers

    private struct HeldReplyPage {
        let webView: WKWebView
        let handler: HeldReplyHandler
    }

    /// Loads a page whose bridge sends its requests to a handler that holds the replies.
    private func loadPageWithHeldReplies() async throws -> HeldReplyPage {
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation
        let handler = HeldReplyHandler()
        let controller = webView.configuration.userContentController
        controller.addScriptMessageHandler(handler, contentWorld: .page, name: HeldReplyHandler.name)
        addTeardownBlock { @MainActor in
            controller.removeAllScriptMessageHandlers()
        }
        let source = try XCTUnwrap(
            WebViewBridgeScript.generate(sessionId: "baked-session", sessionMetadata: nil, handlerName: HeldReplyHandler.name)
        )
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        try await navigation.load("<html><body>held replies</body></html>", in: webView)
        return HeldReplyPage(webView: webView, handler: handler)
    }

    /// Waits until the handler has received the number of requests, and returns the number it has.
    private func waitForRequests(_ count: Int, from handler: HeldReplyHandler, timeout: TimeInterval = 5) async -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        while handler.pendingReplies.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return handler.pendingReplies.count
    }
}


/// A message handler that keeps each request's reply handler until the test replies.
@MainActor
private final class HeldReplyHandler: NSObject, WKScriptMessageHandlerWithReply {

    static let name = "HeldReplyHandler"

    private(set) var pendingReplies: [@MainActor @Sendable (Any?, String?) -> Void] = []

    func userContentController(
        _: WKUserContentController,
        didReceive _: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        pendingReplies.append(replyHandler)
    }

    /// Replies to the request at the index with a session ID and no metadata.
    func reply(_ index: Int, sessionId: String) {
        pendingReplies[index](["sessionId": sessionId, "sessionMetadata": NSNull()], nil)
    }
}
