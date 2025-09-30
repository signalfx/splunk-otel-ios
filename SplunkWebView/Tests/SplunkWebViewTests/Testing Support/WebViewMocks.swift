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

// MARK: - Mock WKWebView

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

// MARK: - Mock WKWebViewConfiguration

/// A mock `WKWebViewConfiguration` that provides a `MockWKUserContentController`.
final class MockWKWebViewConfiguration: WKWebViewConfiguration {
    /// Hold a private instance of our mock to ensure it's the one being used.
    private let mockUCC = MockWKUserContentController()

    /// Override as a mutable computed property to match the superclass.
    override var userContentController: WKUserContentController {
        get {
            mockUCC
        }
        set {
            // The setter is required to match the superclass property, but we can ignore it
            // since we always want to return our specific mock instance.
        }
    }
}

// MARK: - Mock WKUserContentController

/// A mock `WKUserContentController` to track calls to `addUserScript`, `addScriptMessageHandler`, and `removeScriptMessageHandler`.
final class MockWKUserContentController: WKUserContentController {
    var addUserScriptCalled = false
    var addUserScriptCallCount = 0
    var addScriptMessageHandlerCalled = false
    var removeScriptMessageHandlerCalled = false
    var lastAddedMessageHandlerName: String?

    override func addUserScript(_: WKUserScript) {
        addUserScriptCalled = true
        addUserScriptCallCount += 1
    }

    override func addScriptMessageHandler(_: WKScriptMessageHandlerWithReply, contentWorld _: WKContentWorld, name: String) {
        addScriptMessageHandlerCalled = true
        lastAddedMessageHandlerName = name
    }

    /// Override in the mock to prevent spurious calls to the
    /// real framework implementation.
    override func removeScriptMessageHandler(forName _: String) {
        removeScriptMessageHandlerCalled = true
    }
}

// MARK: - Mock WKScriptMessage

/// A mock `WKScriptMessage` to simulate messages sent from JavaScript to the native message handler.
final class MockWKScriptMessage: WKScriptMessage {
    private let mockName: String
    private let mockBody: Any

    override var name: String {
        mockName
    }

    override var body: Any {
        mockBody
    }

    init(name: String, body: Any) {
        mockName = name
        mockBody = body
        super.init()
    }
}
