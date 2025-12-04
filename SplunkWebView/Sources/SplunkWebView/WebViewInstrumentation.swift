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
import SplunkCommon

#if canImport(WebKit)
    import WebKit
#else
    import Foundation
#endif


public final class WebViewInstrumentation: NSObject {

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")

    public weak var sharedState: AgentSharedState?


    // MARK: - Initialization

    override public init() {}


    // MARK: - Internal Methods

    #if canImport(WebKit)
        private func contentController(forName name: String, forWebView webView: WKWebView) -> WKUserContentController {
            let contentController = webView.configuration.userContentController
            contentController.removeScriptMessageHandler(forName: name)
            if #available(iOS 14.0, *) {
                contentController.addScriptMessageHandler(self, contentWorld: .page, name: name)
            }
            else {
                // Fallback on earlier versions
                contentController.add(self, name: name)
            }
            return contentController
        }


        // MARK: - Public Methods

        // swiftlint:disable function_body_length
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

            // iOS 14+ exposes WKScriptMessageHandlerWithReply and returns a Promise from postMessage.
            // On iOS 13 postMessage returns void, so the injected script must defensively verify the
            // result before chaining .then() to avoid TypeError in the legacy BRUM bridge.
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
                                const handler = window.webkit?.messageHandlers?.SplunkRumNativeUpdate;
                                if (!handler || typeof handler.postMessage !== "function") {
                                    const error = new Error(
                                        "[SplunkRumNative] postMessage handler is unavailable; " +
                                        "native replies may be unsupported on this platform."
                                    );
                                    console.warn(error.message);
                                    return Promise.reject(error);
                                }

                                let result;
                                try {
                                    result = handler.postMessage({});
                                } catch (error) {
                                    console.error("[SplunkRumNative] postMessage threw an error:", error);
                                    return Promise.reject(error);
                                }

                                if (!result || typeof result.then !== "function") {
                                    const error = new Error(
                                        "[SplunkRumNative] postMessage did not return a Promise; " +
                                        "native replies may be unsupported on this platform."
                                    );
                                    console.warn(error.message);
                                    return Promise.reject(error);
                                }

                                return result
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
            )
            .addUserScript(userScript)

            // Needed at first load only; user script will persist across reloads and navigation
            webView.evaluateJavaScript(javaScript)
        } // swiftlint:enable function_body_length
    #endif // canImport(WebKit)
}

// MARK: - WKScriptMessageHandlerWithReply

#if canImport(WebKit)
    @available(iOS 14.0, *)
    extension WebViewInstrumentation: WKScriptMessageHandlerWithReply {

        /// Handles JavaScript messages with a reply handler for asynchronous communication.
        public func userContentController(
            _: WKUserContentController,
            didReceive _: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            // hint: parse message.body["action"] here if you need to add features
            if let sessionId = sharedState?.sessionId {
                replyHandler(["sessionId": sessionId], nil)
            }
            else {
                replyHandler(nil, "Native Session ID not available")
            }
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
    /// - Injection occurs only when a native session ID is available (`sharedState?.sessionId` non-nil); otherwise `SplunkRumNative` is not injected.
    extension WebViewInstrumentation: WKScriptMessageHandler {
        public func userContentController(_: WKUserContentController, didReceive _: WKScriptMessage) {
            // No-op: iOS 13 cannot reply, so JS sees the rejected Promise described above.
        }
    }
#endif

/// Type for conforming to ModuleEventMetadata.
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

/// Type for conforming to ModuleEventData.
public struct WebViewInstrumentationData: ModuleEventData {}
