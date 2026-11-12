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

    func testSessionChangeReplacesBridgeKeepsScripts() throws {
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)
        let before = makeCustomerScript("before")
        let after = makeCustomerScript("after")
        controller.addUserScript(before)
        instrumentation.injectSessionId(into: webView)
        controller.addUserScript(after)
        let originalBridge = controller.userScripts[1]

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        XCTAssertEqual(controller.userScripts.count, 3)
        XCTAssertTrue(controller.userScripts[0] === before)
        XCTAssertTrue(controller.userScripts[2] === after)
        XCTAssertFalse(controller.userScripts[1] === originalBridge)
        XCTAssertTrue(controller.userScripts[1].source.contains("cachedSessionId: 'second-session'"))
    }

    func testRepeatedInjectionReplacesBridgeScript() throws {
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)
        instrumentation.injectSessionId(into: webView)

        sharedState.updateSessionId("second")
        instrumentation.injectSessionId(into: webView)

        XCTAssertEqual(controller.userScripts.count, 1)
        let script = try XCTUnwrap(controller.userScripts.first)
        XCTAssertTrue(script.source.contains("cachedSessionId: 'second'"))
    }

    func testSharedContentControllerRewrittenOnce() throws {
        let configuration = MockWKWebViewConfiguration()
        let first = MockWKWebView(frame: .zero, configuration: configuration)
        let second = MockWKWebView(frame: .zero, configuration: configuration)
        let controller = try XCTUnwrap(configuration.userContentController as? MockWKUserContentController)
        instrumentation.injectSessionId(into: first)
        instrumentation.injectSessionId(into: second)
        XCTAssertEqual(controller.userScripts.count, 2)

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 1)
        XCTAssertEqual(controller.userScripts.count, 2)
        XCTAssertTrue(controller.userScripts.allSatisfy { $0.source.contains("cachedSessionId: 'second-session'") })
    }

    func testDeallocatedWebViewIsSkipped() throws {
        let configuration = MockWKWebViewConfiguration()
        let controller = try XCTUnwrap(configuration.userContentController as? MockWKUserContentController)
        let liveWebView = MockWKWebView()
        weak var releasedWebView: MockWKWebView?
        // Inject both views inside the pool. Reading the weak-keyed table can autorelease the
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

        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 0)
        // The full script and the update of the injection, then the push.
        XCTAssertEqual(liveWebView.evaluatedJavaScripts.count, 3)
    }

    func testSessionChangeReleasesWebViewScript() {
        let releasedScript = releaseInstrumentedWebView()

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        XCTAssertNil(releasedScript())
    }

    func testInjectionReleasesScriptOfReleasedView() {
        let liveWebView = MockWKWebView()
        instrumentation.injectSessionId(into: liveWebView)
        let releasedScript = releaseInstrumentedWebView()

        instrumentation.injectSessionId(into: liveWebView)

        XCTAssertNil(releasedScript())
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

    func testSessionChangeSwapsScriptsFirst() throws {
        let first = MockWKWebView()
        let second = MockWKWebView()
        let controllers = try [first, second]
            .map {
                try XCTUnwrap($0.configuration.userContentController as? MockWKUserContentController)
            }
        instrumentation.injectSessionId(into: first)
        instrumentation.injectSessionId(into: second)

        var scriptsWereSwappedAtEachUpdate: [Bool] = []
        for webView in [first, second] {
            webView.onEvaluateJavaScript = { script in
                guard script.contains("_setNativeSession('second-session'") else {
                    return
                }

                let swapped = controllers.allSatisfy { controller in
                    controller.userScripts.allSatisfy { $0.source.contains("cachedSessionId: 'second-session'") }
                }
                scriptsWereSwappedAtEachUpdate.append(swapped)
            }
        }

        sharedState.updateSessionId("second-session")
        instrumentation.nativeSessionDidChange()

        XCTAssertEqual(scriptsWereSwappedAtEachUpdate, [true, true])
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
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)
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
        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 0)

        let deadline = Date().addingTimeInterval(30)
        while webView.evaluatedJavaScripts.count == evaluatedBefore, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let updates = webView.evaluatedJavaScripts.filter { $0.contains("_setNativeSession('second-session'") }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 1)
    }

    func testSessionChangeNoWebViewsBuildsNoScript() {
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

        // The counter works: one build for the injection, one for the push.
        let webView = MockWKWebView()
        counting.injectSessionId(into: webView)
        counting.nativeSessionDidChange()
        XCTAssertEqual(generatorCalls, 2)
    }

    func testSessionChangeNoBridgeScriptNoOp() throws {
        var scriptIsAvailable = true
        let unavailable = WebViewInstrumentation(
            logger: MockLogAgent(),
            sharedState: sharedState,
            bridgeScriptGenerator: { sessionId, sessionMetadata, handlerName in
                scriptIsAvailable
                    ? WebViewBridgeScript.generate(sessionId: sessionId, sessionMetadata: sessionMetadata, handlerName: handlerName)
                    : nil
            }
        )
        let webView = MockWKWebView()
        let controller = try XCTUnwrap(webView.configuration.userContentController as? MockWKUserContentController)
        unavailable.injectSessionId(into: webView)
        let installedScript = try XCTUnwrap(controller.userScripts.first)
        let evaluatedBefore = webView.evaluatedJavaScripts.count

        scriptIsAvailable = false
        sharedState.updateSessionId("second-session")
        unavailable.nativeSessionDidChange()

        XCTAssertEqual(webView.evaluatedJavaScripts.count, evaluatedBefore)
        XCTAssertEqual(controller.removeAllUserScriptsCallCount, 0)
        XCTAssertTrue(controller.userScripts.first === installedScript)
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

    /// Instruments a real web view, removes its message handlers as an app does at teardown, and releases it.
    ///
    /// WebKit keeps a content controller alive while it has a script message handler.
    ///
    /// - Returns: A closure that returns the view's bridge script while anything keeps it alive.
    private func releaseInstrumentedWebView() -> () -> WKUserScript? {
        weak var releasedWebView: WKWebView?
        weak var releasedController: WKUserContentController?
        weak var releasedScript: WKUserScript?
        autoreleasepool {
            let webView = WKWebView()
            instrumentation.injectSessionId(into: webView)
            let controller = webView.configuration.userContentController
            XCTAssertEqual(controller.userScripts.count, 1)
            controller.removeAllScriptMessageHandlers()
            releasedWebView = webView
            releasedController = controller
            releasedScript = controller.userScripts.first
        }

        let released = waitUntil(timeout: 30) { releasedWebView == nil && releasedController == nil }
        XCTAssertTrue(released, "WebKit did not release the web view.")

        return { releasedScript }
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
