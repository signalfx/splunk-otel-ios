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

    typealias BridgeScriptGenerator = (String, String?, String) -> String?

    // MARK: - Static constants

    private static let handlerName = "SplunkRumNativeUpdate"


    // MARK: - Private

    private let logger: LogAgent
    private let bridgeScriptGenerator: BridgeScriptGenerator

    #if canImport(WebKit)
        /// The web views that have the bridge user script, held weakly and matched by identity.
        ///
        /// Identity matching keeps a `WKWebView` subclass that overrides `isEqual:` from sharing
        /// an entry with another view. Read and written on the main thread only.
        private let instrumentedWebViews = NSHashTable<WKWebView>(options: [.weakMemory, .objectPointerPersonality])

        /// The content controllers that have the bridge message handler, held weakly and matched by identity.
        ///
        /// Read and written on the main thread only.
        private let controllersWithHandler = NSHashTable<WKUserContentController>(options: [.weakMemory, .objectPointerPersonality])
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
        bridgeScriptGenerator = { sessionId, sessionMetadata, handlerName in
            WebViewBridgeScript.generate(sessionId: sessionId, sessionMetadata: sessionMetadata, handlerName: handlerName)
        }
    }

    /// Initializes the `WebViewInstrumentation` module for testing purposes.
    ///
    /// - Parameters:
    ///   - logger: A `LogAgent` for logging messages.
    ///   - sharedState: An `AgentSharedState` for accessing the session ID.
    ///   - bridgeScriptGenerator: A closure that creates the JavaScript bridge script.
    init(
        logger: LogAgent,
        sharedState: AgentSharedState? = nil,
        bridgeScriptGenerator: @escaping BridgeScriptGenerator = { sessionId, sessionMetadata, handlerName in
            WebViewBridgeScript.generate(sessionId: sessionId, sessionMetadata: sessionMetadata, handlerName: handlerName)
        }
    ) {
        self.logger = logger
        self.sharedState = sharedState
        self.bridgeScriptGenerator = bridgeScriptGenerator
    }


    // MARK: - Public Methods

    #if canImport(WebKit)
        /// Internal implementation of WebView bridge injection.
        ///
        /// Registers the message handler once per content controller and adds the bridge user script
        /// once per web view. User scripts are never removed or replaced. Every call also evaluates an
        /// update statement, so an open page that already has the bridge gets the current session.
        ///
        /// If the app removes the message handler after the first call, a later call does not add it back.
        ///
        /// - Parameter webView: The `WKWebView` instance to instrument.
        public func injectSessionId(into webView: WKWebView) {
            // Ensure this method is called on the main thread as WKWebView APIs are UI-bound.
            guard Thread.isMainThread else {
                logger.log(level: .warn, isPrivate: false) {
                    "SplunkWebView: `injectSessionId` called from a background thread. Dispatching to main thread."
                }
                Task { @MainActor [weak self] in
                    self?.injectSessionId(into: webView)
                }
                return
            }

            // A webview is considered "already in use" if it is actively loading
            // or has already finished loading a URL other than the default empty page.
            if webView.isLoading || (webView.url != nil && webView.url?.absoluteString != "about:blank") {
                logger.log(level: .warn, isPrivate: false) {
                    "SplunkWebView: `injectSessionId` was called on a WKWebView that has already started loading content. "
                        + "To ensure proper correlation with Browser RUM, this method should be called before `loadHTMLString`, `load`, or similar methods."
                }
            }

            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation injecting JavaScript APIs for fetching native Session ID."
            }

            guard let currentState = sharedState else {
                logger.log(level: .warn, isPrivate: false) {
                    "Native Session ID not available for webview injection. Check that sharedState is set before use."
                }
                return
            }

            let sessionId = currentState.sessionId
            let sessionMetadata = currentState.sessionMetadata

            guard let javaScript = bridgeScriptGenerator(sessionId, sessionMetadata, Self.handlerName) else {
                logger.log(level: .error, isPrivate: false) {
                    "WebView bridge script is unavailable; skipping JavaScript injection."
                }
                return
            }

            let controller = webView.configuration.userContentController
            registerMessageHandler(in: controller)

            // Add the user script only once per web view to avoid duplication.
            if !instrumentedWebViews.contains(webView) {
                controller.addUserScript(
                    WKUserScript(
                        source: javaScript,
                        injectionTime: .atDocumentStart, // expected by legacy BRUM
                        forMainFrameOnly: false // expected by legacy BRUM
                    )
                )
                instrumentedWebViews.add(webView)
            }

            // Needed at first load only; user script will persist across reloads and navigation.
            // Re-evaluating is safe and idempotent due to the JS guard.
            webView.evaluateJavaScript(javaScript)

            // A page that already has the bridge skips the full script, so it keeps its old session.
            // The update reaches that page; it does nothing in a page without a bridge.
            webView.evaluateJavaScript(WebViewBridgeScript.update(sessionId: sessionId, sessionMetadata: sessionMetadata))
        }
    #endif


    // MARK: - Session changes

    /// Pushes the current native session into the main frame of every instrumented web view.
    ///
    /// The push changes only the open page's bridge state. It does not touch user scripts, so it
    /// cannot affect a page that is loading. A page that loads later asks native for the current
    /// session as soon as its bridge is set up, and so does a page that returns from the back-forward
    /// cache. The push does not reach iframes; an iframe's bridge gets the new ID when it next asks
    /// native: the async getter asks at once, and the sync getter starts a refresh when its value is
    /// more than 5 seconds old.
    ///
    /// Off the main thread the method hops to the main thread and returns before the push is done.
    /// It does nothing when no web view is instrumented or when there is no shared state.
    @_spi(SplunkInternal)
    public func nativeSessionDidChange() {
        #if canImport(WebKit)
            guard Thread.isMainThread else {
                Task { @MainActor [weak self] in
                    self?.nativeSessionDidChange()
                }
                return
            }

            // Most apps have no web view: skip the state reads.
            let webViews = instrumentedWebViews.allObjects
            guard !webViews.isEmpty, let currentState = sharedState else {
                return
            }

            let update = WebViewBridgeScript.update(sessionId: currentState.sessionId, sessionMetadata: currentState.sessionMetadata)

            for webView in webViews {
                webView.evaluateJavaScript(update)
            }
        #endif
    }


    // MARK: - Private Methods

    #if canImport(WebKit)
        /// Registers the bridge message handler in the content controller, once per controller.
        ///
        /// Removing and adding the handler again on every call would leave a moment in which a page has
        /// no handler, so a session request from the page would fail.
        private func registerMessageHandler(in contentController: WKUserContentController) {
            guard !controllersWithHandler.contains(contentController) else {
                return
            }

            // Adding a handler under a name that is already registered raises an exception,
            // and another instance may have registered one.
            contentController.removeScriptMessageHandler(forName: Self.handlerName)

            if #available(iOS 14.0, *) {
                contentController.addScriptMessageHandler(self, contentWorld: .page, name: Self.handlerName)
            }
            else {
                // Fallback on earlier versions
                contentController.add(self, name: Self.handlerName)
            }

            controllersWithHandler.add(contentController)
        }

    #endif // canImport(WebKit)
}

#if canImport(WebKit)
    @available(iOS 14.0, *)
    extension WebViewInstrumentation: WKScriptMessageHandlerWithReply {

        // MARK: - WKScriptMessageHandlerWithReply

        /// Handles JavaScript messages with a reply handler for asynchronous communication.
        ///
        /// This method is called when the web content calls `window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage()`.
        /// It retrieves the current native session ID and session metadata, then sends them back to the JavaScript context.
        ///
        /// - Parameters:
        ///
        /// - replyHandler: A block to be called with the reply data (containing `sessionId` and `sessionMetadata`) or an error string.
        public func userContentController(
            _: WKUserContentController,
            didReceive _: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            // hint: parse message.body["action"] here if you need to add features
            guard let currentState = sharedState else {
                replyHandler(nil, "Native Session ID not available")
                return
            }

            let reply: [String: Any] = [
                "sessionId": currentState.sessionId,
                "sessionMetadata": currentState.sessionMetadata ?? NSNull()
            ]
            replyHandler(reply, nil)
        }
    }
#endif

#if canImport(WebKit)
    /// Fallback for platforms limited to `WKScriptMessageHandler` (iOS 13 and other runtimes without reply support).
    /// - iOS 13 behavior:
    ///   - `postMessage` returns void; the injected JS detects the missing Promise, causing `_fetchSessionId` to reject and leaving the cached ID untouched.
    ///   - `getNativeSessionId()` still returns the cached value immediately; `getNativeSessionIdAsync()` resolves to `undefined`.
    /// - iOS 14+ behavior:
    ///   - `postMessage` returns a Promise backed by the native `replyHandler`; async calls resolve with `sessionId` when native responds.
    /// - Callers should wrap `getNativeSessionIdAsync()` with their own timeout if they require bounded waits, and fall back to the synchronous API.
    /// - Injection occurs only when `sharedState` is set; otherwise `SplunkRumNative` is not injected.
    /// - With no session, the bridge returns an empty string.
    extension WebViewInstrumentation: WKScriptMessageHandler {
        public func userContentController(_: WKUserContentController, didReceive _: WKScriptMessage) {
            // No-op: iOS 13 cannot reply, so JS sees the rejected Promise described above.
        }
    }
#endif
