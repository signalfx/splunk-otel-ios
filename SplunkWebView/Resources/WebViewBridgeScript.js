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
            nativeSessionMetadata: __SESSION_METADATA__,
            _isInitialized: false,
            _lastCheckTime: Date.now(),
            _updateInProgress: false,
            _fetchCount: 0,
            _pushCount: 0,
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
                    .then((r) => ({ sessionId: r.sessionId, sessionMetadata: r.sessionMetadata }))
                    .catch( function(error) {
                        console.error("[SplunkRumNative] Failed to fetch native session info:", error);
                        throw error;
                    });
            },
            // Called by the SDK on session creation, rotation and end; not for pages to call.
            // A push also restarts the staleness window of the synchronous getter.
            _setNativeSession: function(newId, newMetadata) {
                self._pushCount++;
                self._lastCheckTime = Date.now();
                self._storeNativeSession(newId, newMetadata);
            },
            // Stores a fetch reply, unless a push arrived after the request was sent. Native computed
            // such a reply before the push, so it can be older than the pushed session.
            _storeReply: function(pushCountAtRequest, reply) {
                if (pushCountAtRequest !== self._pushCount) {
                    return;
                }
                self._storeNativeSession(reply.sessionId, reply.sessionMetadata);
            },
            _storeNativeSession: function(newId, newMetadata) {
                self.nativeSessionMetadata = (newMetadata !== undefined) ? newMetadata : null;
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
                        console.error("[SplunkRumNative] Error in the Browser RUM callback for onNativeSessionIdChanged:", error);
                    }
                }
            },
            // Starts a fetch from native and stores the reply. A fetch that has not settled within
            // staleAfterDurationMs no longer blocks a new one, so a lost reply cannot stop all refreshes.
            _refreshFromNative: function() {
                const now = Date.now();
                if (self._updateInProgress && (now - self._lastCheckTime) <= staleAfterDurationMs) {
                    return;
                }
                const fetchNumber = ++self._fetchCount;
                const pushCountAtRequest = self._pushCount;
                self._updateInProgress = true;
                self._lastCheckTime = now;
                self._fetchSessionId()
                    .then( function(reply) {
                        self._storeReply(pushCountAtRequest, reply);
                    })
                    .catch( function(error) {
                        console.error("[SplunkRumNative] Failed to fetch session info from native:", error);
                    })
                    .finally( function() {
                        if (fetchNumber === self._fetchCount) {
                            self._updateInProgress = false;
                        }
                    });
            },
            // This must be synchronous for legacy BRUM compatibility.
            getNativeSessionId: function() {
                if ((Date.now() - self._lastCheckTime) > staleAfterDurationMs) {
                    self._refreshFromNative();
                }
                // Here we finish before the refresh is fulfilled, and
                // return cached ID immediately for legacy compatibility.
                return self.cachedSessionId;
            },
            // Recommended for BRUM use in new agents going forward.
            getNativeSessionIdAsync: async function() {
                try {
                    const pushCountAtRequest = self._pushCount;
                    const reply = await self._fetchSessionId();
                    self._storeReply(pushCountAtRequest, reply);
                    // After a newer push, this is the pushed ID rather than the reply's.
                    return self.cachedSessionId;
                } catch (error) {
                    console.error("[SplunkRumNative] Failed to fetch native session info asynchronously:", error);
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
        // The session baked into this script can be older than native's current one, so ask at once.
        if (bridgeAvailable) {
            self._refreshFromNative();
        }
        // A page restored from the back-forward cache runs no user scripts and missed any push, so ask again.
        window.addEventListener("pageshow", function(event) {
            if (event.persisted) {
                self._refreshFromNative();
            }
        });
        self._isInitialized = true;
        return self;
    }());
}
