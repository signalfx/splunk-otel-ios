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

        let reloadedSync = try await synchronousSessionId(in: webView)
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

        let reloadedMetadata = try await pageMetadata(in: webView)
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
        instrumentation.injectSessionId(into: webView)

        let repeatedSync = try await synchronousSessionId(in: webView)
        XCTAssertEqual(repeatedSync, "second-session")
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


    // MARK: - Helpers

    /// Returns a web view in a visible window, which stays alive until the test ends.
    ///
    /// On iOS 26 the first page load of the test process does not start in a web view that has no
    /// window, so the tests host their web views in one.
    private func makeWindowedWebView() -> WKWebView {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        window.isHidden = false

        addTeardownBlock { @MainActor in
            window.isHidden = true
        }

        return webView
    }

    private func synchronousSessionId(in webView: WKWebView) async throws -> String? {
        try await webView.evaluateJavaScript("window.SplunkRumNative.getNativeSessionId()") as? String
    }

    private func pageMetadata(in webView: WKWebView) async throws -> String? {
        try await webView.evaluateJavaScript("window.SplunkRumNative.nativeSessionMetadata") as? String
    }

    private func asynchronousSessionId(in webView: WKWebView) async throws -> String? {
        try await webView.callAsyncJavaScript(
            "return await window.SplunkRumNative.getNativeSessionIdAsync();",
            arguments: [:],
            in: nil,
            contentWorld: .page
        ) as? String
    }
}


/// Waits for a web view navigation to finish, fails when it takes too long, and fails when the web content process ends.
@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {

    enum Failure: Error, Equatable {
        case timedOut
        case webContentProcessTerminated
    }

    /// When `true`, a timeout or a terminated web content process also reports an `XCTFail` with a message.
    var reportsFailures = true

    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(timeout: TimeInterval = 120) {
        self.timeout = timeout
        super.init()
    }

    func load(_ html: String, in webView: WKWebView) async throws {
        try await wait { webView.loadHTMLString(html, baseURL: nil) }
    }

    func reload(_ webView: WKWebView) async throws {
        try await wait { webView.reload() }
    }

    /// Runs `start`, then waits for the navigation to finish, to fail, or for the timeout.
    func wait(_ start: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task { [weak self, timeout] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else {
                    return
                }

                self?.finish(throwing: Failure.timedOut, message: "The web view navigation did not finish within \(Int(timeout)) seconds.")
            }
            start()
        }
    }

    func webView(_: WKWebView, didFinish _: WKNavigation?) {
        finish(throwing: nil)
    }

    func webView(_: WKWebView, didFail _: WKNavigation?, withError error: Error) {
        finish(throwing: error)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation?, withError error: Error) {
        finish(throwing: error)
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        finish(throwing: Failure.webContentProcessTerminated, message: "The web content process ended during the navigation.")
    }

    private func finish(throwing error: Error?, message: String? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil

        guard let continuation else {
            return
        }

        self.continuation = nil

        if let error {
            if let message, reportsFailures {
                XCTFail(message)
            }

            continuation.resume(throwing: error)
        }
        else {
            continuation.resume()
        }
    }
}
