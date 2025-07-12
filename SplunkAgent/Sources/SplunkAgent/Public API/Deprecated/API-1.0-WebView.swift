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

    /// Integrates the native RUM agent with a browser RUM agent running in a `WKWebView`.
    ///
    /// This method injects a JavaScript bridge into the web view, allowing the browser RUM agent
    /// to retrieve the native session ID. This links the user's session across both the native
    /// and web portions of your application.
    ///
    /// - Parameter webView: The `WKWebView` instance to integrate with.
    ///
    /// ### Example ###
    /// ```
    /// let myWebView = WKWebView()
    /// SplunkRum.integrateWithBrowserRum(myWebView)
    /// ```
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