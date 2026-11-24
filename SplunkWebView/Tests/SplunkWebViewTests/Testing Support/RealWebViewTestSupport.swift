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

/// Helpers for tests that run the bridge script in a real web view.
@MainActor
extension XCTestCase {

    /// Returns a web view in a visible window, which stays alive until the test ends.
    ///
    /// On iOS 26 the first page load of the test process does not start in a web view that has no
    /// window, so the tests host their web views in one.
    func makeWindowedWebView() -> WKWebView {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let webView = WKWebView(frame: window.bounds)
        window.addSubview(webView)
        window.isHidden = false

        addTeardownBlock { @MainActor in
            window.isHidden = true
        }

        return webView
    }

    func synchronousSessionId(in webView: WKWebView) async throws -> String? {
        try await webView.evaluateJavaScript("window.SplunkRumNative.getNativeSessionId()") as? String
    }

    func pageMetadata(in webView: WKWebView) async throws -> String? {
        try await webView.evaluateJavaScript("window.SplunkRumNative.nativeSessionMetadata") as? String
    }

    func asynchronousSessionId(in webView: WKWebView) async throws -> String? {
        try await webView.callAsyncJavaScript(
            "return await window.SplunkRumNative.getNativeSessionIdAsync();",
            arguments: [:],
            in: nil,
            contentWorld: .page
        ) as? String
    }

    /// Reads a value until it equals the expected one or the timeout passes, and returns the last value read.
    func waitForValue(
        _ expected: String?,
        timeout: TimeInterval = 5,
        _ read: () async throws -> String?
    ) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        var value = try await read()
        while value != expected, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
            value = try await read()
        }
        return value
    }

    /// Pushes a session into the page the way the SDK does.
    func push(_ sessionId: String, into webView: WKWebView) async throws {
        // The update statement evaluates to `undefined`; end with a value the async API can return.
        _ = try await webView.evaluateJavaScript(WebViewBridgeScript.update(sessionId: sessionId, sessionMetadata: nil) + " 0;")
    }

    /// Gives the page time to handle replies and events that are already on their way.
    func settle() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}


/// Waits for a web view navigation to finish, fails when it takes too long, and fails when the web content process ends.
@MainActor
final class NavigationWaiter: NSObject, WKNavigationDelegate {

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
