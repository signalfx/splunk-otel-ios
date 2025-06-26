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

internal import SplunkWebView
import WebKit

/// The public-facing proxy class that forwards calls to the internal WebView module.
final class WebView: WebViewInstrumentationModule {

    // This holds the *real* module instance from the SplunkWebView module.
    private let module: SplunkWebView.WebViewInstrumentation

    init(module: SplunkWebView.WebViewInstrumentation) {
        self.module = module
    }

    public func integrateWithBrowserRum(_ view: WKWebView) {
        module.injectSessionId(into: view)
    }
}
