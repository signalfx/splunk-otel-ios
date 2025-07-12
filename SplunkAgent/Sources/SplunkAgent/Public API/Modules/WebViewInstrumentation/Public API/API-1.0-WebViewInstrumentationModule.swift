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

/// An interface for integrating the native RUM agent with browser RUM running in a `WKWebView`.
///
/// This integration allows the browser RUM agent to access the native session ID,
/// linking user sessions across both the native and web portions of your application.
///
/// ### Example ###
/// ```
/// let myWebView = WKWebView()
/// SplunkRum.shared.webView.integrateWithBrowserRum(myWebView)
/// ```
public protocol WebViewInstrumentationModule {
    /// Integrates the native RUM agent with a browser RUM agent running in a given `WKWebView`.
    ///
    /// This method injects a JavaScript bridge into the web view, which exposes a `getNativeSessionId()`
    /// function to the web content. The browser RUM agent can then use this function to retrieve
    /// the native session ID.
    ///
    /// - Parameter view: The ``WKWebView`` instance to integrate with.
    func integrateWithBrowserRum(_ view: WKWebView)
}