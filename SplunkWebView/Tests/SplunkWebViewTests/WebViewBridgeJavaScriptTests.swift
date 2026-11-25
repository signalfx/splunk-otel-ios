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

import UIKit
import WebKit
import XCTest

@_spi(SplunkInternal) @testable import SplunkWebView

/// Runs the bridge script in a real web view.
@MainActor
final class WebViewBridgeJavaScriptTests: XCTestCase {

    func testBridgeGettersFollowNativeChanges() async throws {
        let sharedState = MockAgentSharedState(sessionId: "")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation

        instrumentation.injectSessionId(into: webView)
        try await navigation.load("<html><body>bridge</body></html>", in: webView)

        let noSessionSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(noSessionSync, "")
        let noSessionAsync = try await asynchronousSessionId(in: webView)
        XCTAssertEqual(noSessionAsync, "")

        sharedState.updateSessionId("foreground-session-id")
        instrumentation.nativeSessionDidChange()

        let pushedSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(pushedSync, "foreground-session-id")

        try await navigation.reload(webView)

        // The reloaded page starts from the ID baked into the bridge script and asks native at once.
        // Stay under the getter's 5 s refresh, so only the request at page load can satisfy the wait.
        let reloadedSync = try await waitForValue("foreground-session-id", timeout: 2) { try await self.synchronousSessionId(in: webView) }
        XCTAssertEqual(reloadedSync, "foreground-session-id")
        let reloadedAsync = try await asynchronousSessionId(in: webView)
        XCTAssertEqual(reloadedAsync, "foreground-session-id")

        sharedState.updateSessionId("")
        instrumentation.nativeSessionDidChange()

        let endedSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(endedSync, "")
        let endedAsync = try await asynchronousSessionId(in: webView)
        XCTAssertEqual(endedAsync, "")
    }

    func testPushedMetadataBase64ReadableInPage() async throws {
        let sharedState = MockAgentSharedState(sessionId: "first-session")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation
        let metadata = "eyJ1c2VyIjoiYWJj+/Zm9vYmFy/+8=="

        instrumentation.injectSessionId(into: webView)
        try await navigation.load("<html><body>bridge</body></html>", in: webView)
        let initialMetadata = try await pageMetadata(in: webView)
        XCTAssertNil(initialMetadata)

        sharedState.updateSessionId("second-session")
        sharedState.updateSessionMetadata(metadata)
        instrumentation.nativeSessionDidChange()

        let pushedSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(pushedSync, "second-session")
        let pushedMetadata = try await pageMetadata(in: webView)
        XCTAssertEqual(pushedMetadata, metadata)

        try await navigation.reload(webView)

        let reloadedMetadata = try await waitForValue(metadata) { try await self.pageMetadata(in: webView) }
        XCTAssertEqual(reloadedMetadata, metadata)
    }

    func testRepeatedInjectionUpdatesOpenPage() async throws {
        let sharedState = MockAgentSharedState(sessionId: "first-session")
        let instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)
        let webView = makeWindowedWebView()
        let navigation = NavigationWaiter()
        webView.navigationDelegate = navigation

        instrumentation.injectSessionId(into: webView)
        try await navigation.load("<html><body>bridge</body></html>", in: webView)
        let firstSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(firstSync, "first-session")

        sharedState.updateSessionId("second-session")
        sharedState.updateSessionMetadata("bWV0YQ==")
        instrumentation.injectSessionId(into: webView)

        let repeatedSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(repeatedSync, "second-session")
        let repeatedMetadata = try await pageMetadata(in: webView)
        XCTAssertEqual(repeatedMetadata, "bWV0YQ==")
    }

    func testNavigationWaiterGivesUpWithNoFinish() async {
        let navigation = NavigationWaiter(timeout: 0.2)
        navigation.reportsFailures = false

        do {
            try await navigation.wait {}
            XCTFail("The waiter must not finish without a navigation.")
        }
        catch {
            XCTAssertEqual(error as? NavigationWaiter.Failure, .timedOut)
        }
    }
}
