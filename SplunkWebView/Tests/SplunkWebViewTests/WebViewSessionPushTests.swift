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

import WebKit
import XCTest

@_spi(SplunkInternal) @testable import SplunkWebView

/// Covers how a native session change reaches instrumented web views.
@MainActor
final class WebViewSessionPushTests: XCTestCase {

    private let sharedState = MockAgentSharedState(sessionId: "first-session")
    private lazy var instrumentation = WebViewInstrumentation(logger: MockLogAgent(), sharedState: sharedState)

    func testSessionChangeOneUpdatePerView() {
        let first = MockWKWebView()
        let second = MockWKWebView()
        instrumentation.injectSessionId(into: first)
        instrumentation.injectSessionId(into: second)

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        for webView in [first, second] {
            let updates = webView.evaluatedJavaScripts.filter { $0.contains("_setNativeSession('second-session'") }
            XCTAssertEqual(updates.count, 1)
            // The full script and the update of the injection, then the push.
            XCTAssertEqual(webView.evaluatedJavaScripts.count, 3)
        }
    }

    func testSessionChangeLeavesUserScripts() throws {
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)
        let before = makeCustomerScript("before")
        let after = makeCustomerScript("after")
        controller.addUserScript(before)
        instrumentation.injectSessionId(into: webView)
        controller.addUserScript(after)
        let scriptsBefore = controller.userScripts

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()
        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 0)
        XCTAssertEqual(controller.userScripts.count, 3)
        XCTAssertTrue(zip(controller.userScripts, scriptsBefore).allSatisfy { $0 === $1 })
    }

    func testRepeatedInjectionRegistersHandlerOnce() throws {
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)

        instrumentation.injectSessionId(into: webView)
        instrumentation.injectSessionId(into: webView)
        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(controller.removeScriptMessageHandlerCallCount, 1)
        XCTAssertEqual(controller.addScriptMessageHandlerCallCount, 1)
    }

    func testSharedControllerRegistersHandlerOnceAndPushesEachView() throws {
        let configuration = MockWKWebViewConfiguration()
        let first = MockWKWebView(frame: .zero, configuration: configuration)
        let second = MockWKWebView(frame: .zero, configuration: configuration)
        let controller = try XCTUnwrap(configuration.userContentController as? MockWKUserContentController)
        instrumentation.injectSessionId(into: first)
        instrumentation.injectSessionId(into: second)

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        XCTAssertEqual(controller.addScriptMessageHandlerCallCount, 1)
        // One bridge script per web view, as before; the page's guard runs only the first.
        XCTAssertEqual(controller.userScripts.count, 2)
        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 0)
        for webView in [first, second] {
            let updates = webView.evaluatedJavaScripts.filter { $0.contains("_setNativeSession('second-session'") }
            XCTAssertEqual(updates.count, 1)
        }
    }

    func testDeallocatedWebViewIsSkipped() {
        let configuration = MockWKWebViewConfiguration()
        let liveWebView = MockWKWebView()
        weak var releasedWebView: MockWKWebView?
        // Inject both views inside the pool. Reading the weak table can autorelease the
        // released view, and outside a pool that keeps it alive until the test ends.
        autoreleasepool {
            let webView = MockWKWebView(frame: .zero, configuration: configuration)
            instrumentation.injectSessionId(into: webView)
            instrumentation.injectSessionId(into: liveWebView)
            releasedWebView = webView
        }

        // WebKit can release a web view on a later run loop turn, later still under load.
        let released = waitUntil(timeout: 30) { releasedWebView == nil }
        XCTAssertTrue(released, "WebKit did not release the web view.")

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        // The full script and the update of the injection, then the push.
        XCTAssertEqual(liveWebView.evaluatedJavaScripts.count, 3)
    }

    func testInstrumentationDoesNotRetainWebView() {
        weak var releasedWebView: WKWebView?
        weak var releasedController: WKUserContentController?
        autoreleasepool {
            let webView = WKWebView()
            instrumentation.injectSessionId(into: webView)
            let controller = webView.configuration.userContentController
            // WebKit keeps a content controller alive while it has a script message handler,
            // so remove the handlers as an app does at teardown.
            controller.removeAllScriptMessageHandlers()
            releasedWebView = webView
            releasedController = controller
        }

        let released = waitUntil(timeout: 30) { releasedWebView == nil && releasedController == nil }
        XCTAssertTrue(released, "The instrumentation kept the web view or its content controller alive.")

        // A push with only released views does nothing and does not crash.
        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()
    }

    func testSessionEndPushesEmptySessionId() {
        let webView = MockWKWebView()
        instrumentation.injectSessionId(into: webView)

        sharedState.updateSessionId("")
        instrumentation.nativeSessionDidChange()

        XCTAssertEqual(
            webView.lastEvaluatedJavaScript,
            WebViewBridgeScript.update(sessionId: "", sessionMetadata: nil)
        )
    }

    func testRepeatedInjectionAlsoUpdatesOpenPage() {
        let webView = MockWKWebView()
        instrumentation.injectSessionId(into: webView)

        sharedState.updateSessionId("second-session")
        sharedState.updateSessionMetadata("bWV0YQ==")
        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(
            webView.lastEvaluatedJavaScript,
            WebViewBridgeScript.update(sessionId: "second-session", sessionMetadata: "bWV0YQ==")
        )
    }

    func testSessionChangeFromBackgroundHopsToMain() async throws {
        let webView = MockWKWebView()
        instrumentation.injectSessionId(into: webView)
        let evaluatedBefore = webView.evaluatedJavaScripts.count
        sharedState.updateSessionId("second-session")

        // Block the main thread until the background call returns, so the hop cannot have run yet.
        let instrumentation = instrumentation
        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global()
            .async {
                instrumentation.nativeSessionDidChange()
                returned.signal()
            }
        XCTAssertEqual(returned.wait(timeout: .now() + 10), .success)

        XCTAssertEqual(webView.evaluatedJavaScripts.count, evaluatedBefore, "Nothing may be evaluated before the hop.")

        let deadline = Date().addingTimeInterval(30)
        while webView.evaluatedJavaScripts.count == evaluatedBefore, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let updates = webView.evaluatedJavaScripts.filter { $0.contains("_setNativeSession('second-session'") }
        XCTAssertEqual(updates.count, 1)
    }

    func testSessionChangeBuildsNoBridgeScript() {
        var generatorCalls = 0
        let counting = WebViewInstrumentation(
            logger: MockLogAgent(),
            sharedState: sharedState,
            bridgeScriptGenerator: { sessionId, sessionMetadata, handlerName in
                generatorCalls += 1
                return WebViewBridgeScript.generate(sessionId: sessionId, sessionMetadata: sessionMetadata, handlerName: handlerName)
            }
        )

        counting.nativeSessionDidChange()
        XCTAssertEqual(generatorCalls, 0)

        // The counter works: one build for the injection, none for the push.
        let webView = MockWKWebView()
        counting.injectSessionId(into: webView)
        counting.nativeSessionDidChange()
        XCTAssertEqual(generatorCalls, 1)
    }

    func testUninstrumentedWebViewGetsNoPush() {
        let unavailable = WebViewInstrumentation(
            logger: MockLogAgent(),
            sharedState: sharedState,
            bridgeScriptGenerator: { _, _, _ in nil }
        )
        let webView = MockWKWebView()
        unavailable.injectSessionId(into: webView)

        sharedState.updateSessionId("second-session")
        unavailable.nativeSessionDidChange()

        XCTAssertTrue(webView.evaluatedJavaScripts.isEmpty)
    }

    func testWebViewsMatchedByIdentityNotEquality() {
        let first = EqualWebView()
        let second = EqualWebView()
        XCTAssertEqual(first, second)
        instrumentation.injectSessionId(into: first)
        instrumentation.injectSessionId(into: second)

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        for webView in [first, second] {
            let updates = webView.evaluatedJavaScripts.filter { $0.contains("_setNativeSession('second-session'") }
            XCTAssertEqual(updates.count, 1)
        }
    }


    // MARK: - Helpers

    private func makeCustomerScript(_ name: String) -> WKUserScript {
        WKUserScript(
            source: "window.customerScript = '\(name)';",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Runs the main run loop until the condition holds or the timeout passes.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }

            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        return condition()
    }
}


/// A web view that is equal to every other `EqualWebView`, as a subclass that overrides `isEqual:` can be.
private final class EqualWebView: WKWebView {
    var evaluatedJavaScripts: [String] = []

    private let mockConfiguration: WKWebViewConfiguration

    override var configuration: WKWebViewConfiguration {
        mockConfiguration
    }

    override var hash: Int {
        1
    }

    convenience init() {
        self.init(frame: .zero, configuration: MockWKWebViewConfiguration())
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        mockConfiguration = configuration
        super.init(frame: frame, configuration: configuration)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func isEqual(_ object: Any?) -> Bool {
        object is EqualWebView
    }

    @MainActor
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, Error?) -> Void)? = nil) {
        evaluatedJavaScripts.append(javaScriptString)
        completionHandler?(nil, nil)
    }
}
