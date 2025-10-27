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

import Foundation
import SplunkAgent

#if canImport(WebKit)
    import WebKit
#endif

/// The class implements a public API for the WebView Instrumentation module.
@objc(SPLKWebViewInstrumentationModule)
public final class WebViewModuleObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Public API

    #if canImport(WebKit)

        /// Injects the necessary JavaScript bridge into a given `WKWebView` to enable
        /// communication between the web content and the native RUM agent.
        @objc(integrateWithBrowserRumView:)
        public func integrateWithBrowserRum(view: WKWebView) {
            owner.agent.webViewNativeBridge.integrateWithBrowserRum(view)
        }

    #endif


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
