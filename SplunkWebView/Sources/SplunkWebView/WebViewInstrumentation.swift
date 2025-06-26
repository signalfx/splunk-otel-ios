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
import WebKit

public final class WebViewInstrumentation: NSObject {

    // TODO: DEMRUM-2592: find a better solution to this duplicative workaround code.
    private var sessionDidResetNotificationPrivateCopy: Notification.Name {
        Notification.Name(
            PackageIdentifier.default(named: "session-did-reset")
        )
    }

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")
    private var instrumentedWebViews = NSHashTable<WKWebView>.weakObjects()
    public weak var sharedState: AgentSharedState?

    // NSObject conformance
    // swiftformat:disable:next modifierOrder
    public override init() {
        super.init()
        /// Listen for session changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidReset(_:)),
            name: sessionDidResetNotificationPrivateCopy,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - Internal Methods

    // MARK: - Notification handler for session resets.

    @objc private func sessionDidReset(_ notification: Notification) {
        // Extract new session ID from the notification's object.
        guard let newId = notification.object as? String else {
            logger.log(level: .warn) { "sessionDidResetNotification received without a valid session ID." }
            return
        }

        logger.log(level: .info) { "Received sessionDidResetNotification. Pushing new session ID to web views." }

        notifySessionIdChanged(newId: newId)
    }

    private func notifySessionIdChanged(newId: String) {
        let script = "window.SplunkRumNative?._setNativeSessionId('\(newId)');"

        // NSHashTable must be accessed on the main thread.
        DispatchQueue.main.async {
            for webView in self.instrumentedWebViews.allObjects {
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }

    private func contentController(forName name: String, forWebView webView: WKWebView) -> WKUserContentController {
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: name)
        contentController.addScriptMessageHandler(self, contentWorld: .page, name: name)
        return contentController
    }


    // MARK: - Public Methods

    // swiftlint:disable function_body_length
    public func injectSessionId(into webView: WKWebView) {

        instrumentedWebViews.add(webView)

        logger.log(level: .notice, isPrivate: false) {
            "WebViewInstrumentation injecting SessionId."
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
}

// MARK: - WKScriptMessageHandlerWithReply

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

// Type for conforming to ModuleEventMetadata
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

// Type for conforming to ModuleEventData
public struct WebViewInstrumentationData: ModuleEventData {}
