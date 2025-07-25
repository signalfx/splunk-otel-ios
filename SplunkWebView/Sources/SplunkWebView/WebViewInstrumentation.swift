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

#if canImport(WebKit)
    import WebKit
#else
    import Foundation
#endif

internal import CiscoLogger
import SplunkCommon

/// A class that provides instrumentation for `WKWebView` instances, enabling communication between the native layer and the web content.
///
/// This instrumentation injects a JavaScript bridge into a web view, allowing the web content to access the native
/// agent's session ID. This is crucial for correlating user sessions between the native application and its embedded web views.
public final class WebViewInstrumentation: NSObject {

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")

    /// A weak reference to the agent's shared state, used to access cross-module information like the current session ID.
    public weak var sharedState: AgentSharedState?

    /// NSObject conformance
    /// swiftformat:disable:next modifierOrder
    public override init() {}


    // MARK: - Internal Methods

    #if canImport(WebKit)
        private func contentController(forName name: String, forWebView webView: WKWebView) -> WKUserContentController {
            let contentController = webView.configuration.userContentController
            contentController.removeScriptMessageHandler(forName: name)
            contentController.addScriptMessageHandler(self, contentWorld: .page, name: name)
            return contentController
        }


        // MARK: - Public Methods

        // swiftlint:disable function_body_length
        /// Injects a JavaScript bridge into the specified `WKWebView` to allow web content to access the native session ID.
        ///
        /// This method sets up a `SplunkRumNative` JavaScript object on the `window` of the web view. This object provides
        /// functions (`getNativeSessionId` and `getNativeSessionIdAsync`) for the web content to retrieve the current native session ID.
        /// It also establishes a message handler (`SplunkRumNativeUpdate`) to facilitate asynchronous communication from JavaScript back to the native code.
        ///
        /// - Note: This method should be called for each `WKWebView` instance that requires session ID correlation.
        /// - Warning: The `sharedState` property must be set before calling this method, as it relies on it to fetch the session ID.
        /// - Parameter webView: The `WKWebView` instance to be instrumented.
        public func injectSessionId(into webView: WKWebView) {

            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation injecting JavaScript APIs for fetching native Session ID."
            }

            guard let sessionId = sharedState?.sessionId else {
                logger.log(level: .warn) {
                    "Native Session ID not available for webview injection. Check that sharedState is set before use."
                }
                return
            }

            let javaScript = """
            if (window.SplunkRumNative && window.SplunkRumNative._isInitialized) {
                console.log("[SplunkRumNative] Already initialized; skipping.");
            } else {
                window.SplunkRumNative = (function() {
                    const staleAfterDurationMs = 5000;
                    const self = {
                        cachedSessionId: '\(sessionId)',
                        _isInitialized: false,
                        _lastCheckTime: Date.now(),
                        _updateInProgress: false,
                        onNativeSessionIdChanged: null,

                        _fetchSessionId: function() {
                            return window.webkit.messageHandlers.SplunkRumNativeUpdate
                                .postMessage({})
                                .then((r) => r.sessionId)
                                .catch( function(error) {
                                    console.error("[SplunkRumNative] Failed to fetch native session ID:", error);
                                    throw error;
                                });
                        },
                        _setNativeSessionId: function(newId) {
                            if (newId !== self.cachedSessionId) {
                                const oldId = self.cachedSessionId;
                                self.cachedSessionId = newId;
                                self._notifyChange(oldId, newId);
                            }
                        },
                        _notifyChange: function(oldId, newId) {
                            if (typeof self.onNativeSessionIdChanged === "function") {
                                try {
                                    self.onNativeSessionIdChanged({
                                        currentId: newId,
                                        previousId: oldId,
                                        timestamp: Date.now()
                                    });
                                } catch (error) {
                                    console.error("[SplunkRumNative] Error in application-provided callback for onNativeSessionIdChanged:", error);
                                }
                            }
                        },
                        // This must be synchronous for legacy BRUM compatibility.
                        getNativeSessionId: function() {
                            const now = Date.now();
                            const stale = (now - self._lastCheckTime) > staleAfterDurationMs;
                            if (stale && !self._updateInProgress) {
                                self._updateInProgress = true;
                                self._lastCheckTime = now;
                                self._fetchSessionId()
                                    .then( function(newId) {
                                        if (newId !== self.cachedSessionId) {
                                            const oldId = self.cachedSessionId;
                                            self.cachedSessionId = newId;
                                            self._notifyChange(oldId, newId);
                                        }
                                    })
                                    .catch( function(error) {
                                        console.error("[SplunkRumNative] Failed to fetch session ID from native:", error);
                                    })
                                    .finally( function() {
                                        self._updateInProgress = false;
                                    });
                            }
                            // Here we finish before above promise is fulfilled, and
                            // return cached ID immediately for legacy compatibility.
                            return self.cachedSessionId;
                        },
                        // Recommended for BRUM use in new agents going forward.
                        getNativeSessionIdAsync: async function() {
                            try {
                                const newId = await self._fetchSessionId();
                                if (newId !== self.cachedSessionId) {
                                    const oldId = self.cachedSessionId;
                                    self.cachedSessionId = newId;
                                    self._notifyChange(oldId, newId);
                                }
                                return newId;
                            } catch (error) {
                                console.error("[SplunkRumNative] Failed to fetch native session ID asynchronously:", error);
                            }
                        }
                    };
                    console.log("[SplunkRumNative] Initialized with native session:", self.cachedSessionId)
                    console.log("[SplunkRumNative] Bridge available:", Boolean(window.webkit?.messageHandlers?.SplunkRumNativeUpdate));
                    self._isInitialized = true;
                    return self;
                }());
            }
            """

            let userScript = WKUserScript(
                source: javaScript,
                injectionTime: .atDocumentStart, // expected by legacy BRUM
                forMainFrameOnly: false // expected by legacy BRUM
            )

            contentController(
                forName: "SplunkRumNativeUpdate",
                forWebView: webView
            ).addUserScript(userScript)

            // Needed at first load only; user script will persist across reloads and navigation
            webView.evaluateJavaScript(javaScript)
        } // swiftlint:enable function_body_length
    #endif // canImport(WebKit)
}

// MARK: - WKScriptMessageHandlerWithReply

#if canImport(WebKit)
    extension WebViewInstrumentation: WKScriptMessageHandlerWithReply {

        /// Handles JavaScript messages with a reply handler for asynchronous communication
        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            // hint: parse message.body["action"] here if you need to add features
            if let sessionId = sharedState?.sessionId {
                replyHandler(["sessionId": sessionId], nil)
            } else {
                replyHandler(nil, "Native Session ID not available")
            }
        }
    }
#endif

// Type for conforming to ModuleEventMetadata
/// A structure that provides metadata for events generated by the WebView Instrumentation module.
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

// Type for conforming to ModuleEventData
/// A placeholder type for WebView Instrumentation module event data.
///
/// This empty structure is used to signal events that do not carry a specific payload.
public struct WebViewInstrumentationData: ModuleEventData {}
