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

internal import CiscoLogger
import Foundation
import SplunkCommon
#if canImport(WebKit)
    import WebKit
#endif


/// Provides the ability to inject a JavaScript bridge into `WKWebView` instances for Browser RUM correlation.
public final class WebViewInstrumentation: NSObject {

    // MARK: - Static constants

    private static let handlerName = "SplunkRumNativeUpdate"

    // MARK: - Private

    private let logger: LogAgent

    #if canImport(WebKit)
        /// Tracks which web views have had the user script installed to prevent duplication.
        private let instrumentedWebViews = NSHashTable<WKWebView>.weakObjects()
    #endif

    // MARK: - Public

    /// The shared state provider, used to access the current native session ID.
    public weak var sharedState: AgentSharedState?


    // MARK: - Initialization

    /// Initializes the `WebViewInstrumentation` module.
    ///
    /// This is the default public initializer.
    override public init() {
        logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")
    }

    /// Initializes the `WebViewInstrumentation` module for testing purposes.
    ///
    /// - Parameters:
    ///   - logger: A `LogAgent` for logging messages.
    ///   - sharedState: An `AgentSharedState` for accessing the session ID.
    init(logger: LogAgent, sharedState: AgentSharedState? = nil) {
        self.logger = logger
        self.sharedState = sharedState
    }

    // MARK: - Public Methods

    #if canImport(WebKit)
        /// This method sets up a message handler and injects JavaScript that provides
        /// `window.SplunkRumNative.getNativeSessionId()` and `getNativeSessionIdAsync()` functions
        /// for the web content to use.
        ///
        /// - Note: To ensure proper correlation, this method should be called before the `WKWebView`
        ///   starts loading any content (e.g., before `load`, `loadHTMLString`, etc.).
        ///
        /// - Parameter webView: The `WKWebView` instance to be instrumented.
        public func injectSessionId(into webView: WKWebView) {
            // Ensure this method is called on the main thread as WKWebView APIs are UI-bound.
            guard Thread.isMainThread else {
                logger.log(level: .warn, isPrivate: false) {
                    "SplunkWebView: `injectSessionId` called from a background thread. Dispatching to main thread."
                }
                DispatchQueue.main.async { [weak self] in
                    self?.injectSessionId(into: webView)
                }
                return
            }

            // A webview is considered "already in use" if it is actively loading
            // or has already finished loading a URL other than the default empty page.
            if webView.isLoading || (webView.url != nil && webView.url?.absoluteString != "about:blank") {
                logger.log(level: .warn, isPrivate: false) {
                    "SplunkWebView: `injectSessionId` was called on a WKWebView that has already started loading content. " +
                    "To ensure proper correlation with Browser RUM, this method should be called before `loadHTMLString`, `load`, or similar methods."
                }
            }

            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation injecting JavaScript APIs for fetching native Session ID."
            }

            guard let sessionId = sharedState?.sessionId else {
                logger.log(level: .warn, isPrivate: false) {
                    "Native Session ID not available for webview injection. Check that sharedState is set before use."
                }
                return
            }

            let javaScript = WebViewBridgeScript.generate(
                sessionId: sessionId,
                handlerName: Self.handlerName
            )

            let userScript = WKUserScript(
                source: javaScript,
                injectionTime: .atDocumentStart, // expected by legacy BRUM
                forMainFrameOnly: false // expected by legacy BRUM
            )

            let controller = contentController(
                forName: Self.handlerName,
                forWebView: webView
            )

            // Add the user script only once per web view to avoid duplication.
            if instrumentedWebViews.allObjects.contains(where: { $0 === webView }) == false {
                controller.addUserScript(userScript)
                instrumentedWebViews.add(webView)
            }

            // Needed at first load only; user script will persist across reloads and navigation.
            // Re-evaluating is safe and idempotent due to the JS guard.
            webView.evaluateJavaScript(javaScript)
        }
        // swiftlint:enable function_body_length
    #endif // canImport(WebKit)

    // MARK: - Private Methods

    #if canImport(WebKit)
        private func contentController(forName name: String, forWebView webView: WKWebView) -> WKUserContentController {
            let contentController = webView.configuration.userContentController
            contentController.removeScriptMessageHandler(forName: name)
            contentController.addScriptMessageHandler(self, contentWorld: .page, name: name)
            return contentController
        }
    #endif
}

#if canImport(WebKit)
    extension WebViewInstrumentation: WKScriptMessageHandlerWithReply {

        // MARK: - WKScriptMessageHandlerWithReply

        /// Handles JavaScript messages with a reply handler for asynchronous communication.
        ///
        /// This method is called when the web content calls `window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage()`.
        /// It retrieves the current native session ID and sends it back to the JavaScript context.
        ///
        /// - Parameters:
        ///   - userContentController: The controller that received the script message.
        ///   - message: The script message received from the web content.
        ///   - replyHandler: A block to be called with the reply data or an error string.
        public func userContentController(
            _: WKUserContentController,
            didReceive _: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            // hint: parse message.body["action"] here if you need to add features
            // Ensure the replyHandler is called on the main thread, as it may interact with UI.
            guard Thread.isMainThread else {
                logger.log(level: .warn, isPrivate: false) {
                    "SplunkWebView: `WKScriptMessageHandlerWithReply` reply handler invoked on background thread. Dispatching to main thread."
                }
                DispatchQueue.main.async {
                    if let sessionId = self.sharedState?.sessionId {
                        replyHandler(["sessionId": sessionId], nil)
                    }
                    else {
                        replyHandler(nil, "Native Session ID not available")
                    }
                }
                return
            }

            if let sessionId = sharedState?.sessionId {
                replyHandler(["sessionId": sessionId], nil)
            }
            else {
                replyHandler(nil, "Native Session ID not available")
            }
        }
    }
#endif
