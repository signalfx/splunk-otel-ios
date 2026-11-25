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

#if canImport(WebKit)

    import WebKit

    /// A `WKWebView` that records the JavaScript it is asked to evaluate instead of running it.
    final class MockWKWebView: WKWebView {

        /// The JavaScript sources passed to `evaluateJavaScript`, in order.
        private(set) var evaluatedJavaScripts: [String] = []

        @MainActor
        override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, (any Error)?) -> Void)? = nil) {
            evaluatedJavaScripts.append(javaScriptString)
            completionHandler?(nil, nil)
        }
    }

#endif
