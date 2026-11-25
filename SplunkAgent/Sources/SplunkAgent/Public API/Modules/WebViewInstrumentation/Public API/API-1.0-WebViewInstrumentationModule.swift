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

#if canImport(WebKit)
    import WebKit
#endif

/// The public protocol defining the capabilities of the WebView Instrumentation module.
public protocol WebViewInstrumentationModule {

    #if canImport(WebKit)
        /// Injects the necessary JavaScript bridge into a given `WKWebView` to enable
        /// communication between the web content and the native RUM agent.
        ///
        /// When the agent's session changes, the agent pushes the new session ID into the main frame of
        /// every web view bridged this way. An iframe's bridge gets the new ID when it next asks the app.
        ///
        /// - Note: To ensure proper correlation, call this before the `WKWebView`
        ///   starts loading any content (for example, before `load`, `loadHTMLString`, etc.).
        ///
        /// - Parameter view: The `WKWebView` instance to be instrumented.
        func integrateWithBrowserRum(_ view: WKWebView)
    #endif
}
