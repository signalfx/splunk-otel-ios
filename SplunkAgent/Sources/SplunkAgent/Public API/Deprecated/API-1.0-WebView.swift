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

import WebKit

public extension SplunkRum {

    // MARK: - WebView

    /// Injects JavaScript `getNativeSessionId()` function into `WKWebView`. Legacy mapping.
    ///
    /// - Parameter webView: The `WKWebView` instance into which the JavaScript `getNativeSessionId()` and `getNativeSessionIdAsync()` APIs will be injected.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.webView.integrateWithBrowserRum(_:)",
        message: "This method will be removed in a later version."
    )
    static func integrateWithBrowserRum(_ webView: WKWebView) {
        shared.webViewNativeBridge.integrateWithBrowserRum(webView)
    }
}
