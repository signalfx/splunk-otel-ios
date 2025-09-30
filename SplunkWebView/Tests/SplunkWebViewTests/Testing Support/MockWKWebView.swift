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

/// A mock `WKWebView` for testing instrumentation logic, allowing control over properties like `isLoading` and `url`.
final class MockWKWebView: WKWebView {
    var evaluateJavaScriptCallCount = 0
    var lastEvaluatedJavaScript: String?

    /// Add properties to control the mock's state for testing the warning logic.
    override var isLoading: Bool {
        get { _isLoading }
        set { _isLoading = newValue }
    }

    private var _isLoading = false

    override var url: URL? {
        get { _url }
        set { _url = newValue }
    }

    private var _url: URL?

    private let mockConfiguration: WKWebViewConfiguration

    override var configuration: WKWebViewConfiguration {
        mockConfiguration
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        mockConfiguration = configuration
        super.init(frame: frame, configuration: configuration)
    }

    convenience init() {
        let mockConfig = MockWKWebViewConfiguration()
        self.init(frame: .zero, configuration: mockConfig)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, Error?) -> Void)? = nil) {
        evaluateJavaScriptCallCount += 1
        lastEvaluatedJavaScript = javaScriptString
        completionHandler?(nil, nil) // Simulate success
    }
}
