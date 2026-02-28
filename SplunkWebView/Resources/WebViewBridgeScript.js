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

if (window.SplunkRumNative && window.SplunkRumNative._isInitialized) {
    console.log("[SplunkRumNative] Already initialized; skipping.");
} else {
    window.SplunkRumNative = (function() {
        const staleAfterDurationMs = 5000;
        const self = {
            cachedSessionId: __SESSION_ID__,
            _isInitialized: false,
            _lastCheckTime: Date.now(),
            _updateInProgress: false,
            onNativeSessionIdChanged: null,

            _fetchSessionId: function() {
                const handler =
                    window.webkit &&
                    window.webkit.messageHandlers &&
                    window.webkit.messageHandlers.__HANDLER_NAME__;
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
        const bridgeAvailable = Boolean(
            window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers.__HANDLER_NAME__
        );
        console.log("[SplunkRumNative] Bridge available:", bridgeAvailable);
        self._isInitialized = true;
        return self;
    }());
}
