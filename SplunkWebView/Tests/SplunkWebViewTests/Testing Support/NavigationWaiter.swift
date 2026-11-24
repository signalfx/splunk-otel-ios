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
