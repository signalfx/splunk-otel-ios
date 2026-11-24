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

/// Runs the bridge in a real web view next to customer user scripts, and checks that session
/// updates leave the page and its scripts alone.
@MainActor
final class WebViewBridgeUserScriptTests: XCTestCase {

    func testSessionUpdateLeavesOpenPageAlone() async throws {
        let sharedState = MockAgentSharedState(sessionId: "first-session")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let page = try await loadPageWithCustomerScripts(instrumentation: instrumentation)
        _ = try await page.webView.evaluateJavaScript("window.pageState = 'kept'; 0;")
        let loadToken = try await page.webView.evaluateJavaScript("window.loadToken") as? String
        let scriptsBefore = page.webView.configuration.userContentController.userScripts

        for round in 1 ... 3 {
            sharedState.updateSessionId("session-\(round)")
            instrumentation.nativeSessionDidChange()
            instrumentation.injectSessionId(into: page.webView)
        }

        let synchronous = try await synchronousSessionId(in: page.webView)
        XCTAssertEqual(synchronous, "session-3")
        let pageState = try await page.webView.evaluateJavaScript("window.pageState") as? String
        XCTAssertEqual(pageState, "kept")
        let tokenAfter = try await page.webView.evaluateJavaScript("window.loadToken") as? String
        XCTAssertEqual(tokenAfter, loadToken)
        let runs = try await customerScriptRuns(in: page.webView)
        XCTAssertEqual(runs, ["before": 1, "after": 1, "world": 1])
        let scriptsAfter = page.webView.configuration.userContentController.userScripts
        XCTAssertEqual(scriptsAfter.count, scriptsBefore.count)
        XCTAssertTrue(zip(scriptsAfter, scriptsBefore).allSatisfy { $0 === $1 })
    }

    func testReloadRunsUserScriptsOnceInOrder() async throws {
        let sharedState = MockAgentSharedState(sessionId: "first-session")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let page = try await loadPageWithCustomerScripts(instrumentation: instrumentation)
        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        try await page.navigation.reload(page.webView)

        let order = try await page.webView.evaluateJavaScript("JSON.stringify(window.scriptOrder)") as? String
        XCTAssertEqual(order, "[\"before:undefined\",\"after:object\"]")
        let runs = try await customerScriptRuns(in: page.webView)
        XCTAssertEqual(runs, ["before": 1, "after": 1, "world": 1])
        let synchronous = try await waitForValue("second-session") { try await self.synchronousSessionId(in: page.webView) }
        XCTAssertEqual(synchronous, "second-session")
    }

    func testChangeCallbackFiresOncePerChange() async throws {
        let sharedState = MockAgentSharedState(sessionId: "first-session")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation
        instrumentation.injectSessionId(into: webView)
        try await navigation.load("<html><body>bridge</body></html>", in: webView)
        _ = try await webView.evaluateJavaScript(
            "window.changes = []; window.SplunkRumNative.onNativeSessionIdChanged = function(e) { "
                + "window.changes.push(e.previousId + '>' + e.currentId); }; 0;"
        )

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()
        instrumentation.injectSessionId(into: webView)
        instrumentation.nativeSessionDidChange()

        let changes = try await webView.evaluateJavaScript("JSON.stringify(window.changes)") as? String
        XCTAssertEqual(changes, "[\"first-session>second-session\"]")
    }


    // MARK: - Helpers

    private struct CustomerScriptPage {
        let webView: WKWebView
        let navigation: NavigationWaiter
    }

    private let customerWorld = WKContentWorld.world(name: "customer")

    /// Loads a page with customer scripts around the bridge: one before it, one in its own content world, and one after it.
    private func loadPageWithCustomerScripts(instrumentation: WebViewInstrumentation) async throws -> CustomerScriptPage {
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation
        let controller = webView.configuration.userContentController
        controller.addUserScript(
            WKUserScript(
                source: "window.scriptOrder = (window.scriptOrder || []); "
                    + "window.scriptOrder.push('before:' + typeof window.SplunkRumNative); "
                    + "window.beforeRuns = (window.beforeRuns || 0) + 1; "
                    + "window.loadToken = window.loadToken || String(Math.random());",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        controller.addUserScript(
            WKUserScript(
                source: "window.worldRuns = (window.worldRuns || 0) + 1;",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: customerWorld
            )
        )
        instrumentation.injectSessionId(into: webView)
        controller.addUserScript(
            WKUserScript(
                source: "window.scriptOrder = (window.scriptOrder || []); "
                    + "window.scriptOrder.push('after:' + typeof window.SplunkRumNative); "
                    + "window.afterRuns = (window.afterRuns || 0) + 1;",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        try await navigation.load("<html><body>customer scripts</body></html>", in: webView)
        return CustomerScriptPage(webView: webView, navigation: navigation)
    }

    private func customerScriptRuns(in webView: WKWebView) async throws -> [String: Int] {
        let before = try await webView.evaluateJavaScript("window.beforeRuns") as? Int
        let after = try await webView.evaluateJavaScript("window.afterRuns") as? Int
        let world = try await webView.callAsyncJavaScript(
            "return window.worldRuns;",
            arguments: [:],
            in: nil,
            contentWorld: customerWorld
        )
        return ["before": before ?? 0, "after": after ?? 0, "world": world as? Int ?? 0]
    }
}
