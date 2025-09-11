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

final class MockWKWebView: WKWebView {
    var evaluateJavaScriptCallCount = 0
    var lastEvaluatedJavaScript: String?

    // Add properties to control the mock's state for testing the warning logic.
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
        return mockConfiguration
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        mockConfiguration = configuration
        super.init(frame: frame, configuration: configuration)
    }

    convenience init() {
        let mockConfig = MockWKWebViewConfiguration()
        self.init(frame: .zero, configuration: mockConfig)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The method override must be on the MainActor, and the completion handler
    // must also be explicitly annotated as `@MainActor` to match the true
    // signature of the underlying API.
    @MainActor
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, Error?) -> Void)? = nil) {
        evaluateJavaScriptCallCount += 1
        lastEvaluatedJavaScript = javaScriptString
        completionHandler?(nil, nil) // Simulate success
    }
}

// MARK: - Mock WKWebViewConfiguration

final class MockWKWebViewConfiguration: WKWebViewConfiguration {
    // Hold a private instance of our mock to ensure it's the one being used.
    private let mockUCC = MockWKUserContentController()

    // Override as a mutable computed property to match the superclass.
    override var userContentController: WKUserContentController {
        get {
            return mockUCC
        }
        set {
            // The setter is required to match the superclass property, but we can ignore it
            // since we always want to return our specific mock instance.
        }
    }
}

// MARK: - Mock WKUserContentController

final class MockWKUserContentController: WKUserContentController {
    var addUserScriptCalled = false
    var addScriptMessageHandlerCalled = false
    var removeScriptMessageHandlerCalled = false
    var lastAddedMessageHandlerName: String?

    override func addUserScript(_ userScript: WKUserScript) {
        addUserScriptCalled = true
    }

    override func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) {
        addScriptMessageHandlerCalled = true
        lastAddedMessageHandlerName = name
    }

    override func add(_ scriptMessageHandler: WKScriptMessageHandler, contentWorld world: WKContentWorld, name: String) {
        addScriptMessageHandlerCalled = true
        lastAddedMessageHandlerName = name
    }

    // This override was missing, which caused calls to leak to the real
    // framework implementation and created unpredictable behavior.
    override func removeScriptMessageHandler(forName name: String) {
        removeScriptMessageHandlerCalled = true
        // In a real scenario, we might remove a handler, but for this mock,
        // simply recording the call is sufficient to prevent the leak.
    }
}

// MARK: - Mock WKScriptMessage

final class MockWKScriptMessage: WKScriptMessage {
    private let mockName: String
    private let mockBody: Any

    override var name: String {
        return mockName
    }

    override var body: Any {
        return mockBody
    }

    init(name: String, body: Any) {
        mockName = name
        mockBody = body
        super.init()
    }
}
