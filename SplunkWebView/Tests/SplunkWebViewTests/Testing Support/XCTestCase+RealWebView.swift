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
