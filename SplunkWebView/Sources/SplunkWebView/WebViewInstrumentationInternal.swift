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

public final class WebViewInstrumentationInternal {

    public static var instance = WebViewInstrumentationInternal()

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")

    public var sharedState: AgentSharedState?

    // Module conformance
    public required init() {}

    // MARK: - Internal Methods

    public func injectSessionId(into webView: WKWebView) {
        guard let sessionId = sharedState?.sessionId else {
            logger.log(level: .warn) {
                "Session ID not available."
            }
            return
        }

        // Extracted JavaScript template for better readability and maintainability
        let script = """
        if (!window.SplunkRumNative) {
            window.SplunkRumNative = {
                cachedSessionId: '\(sessionId)',
                getNativeSessionId: function() {
                    try {
                        window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage('').catch(function() {});
                    } catch (e) {
                        console.error('Error in getNativeSessionId:', e); // Improved error handling
                    }
                    return window.SplunkRumNative.cachedSessionId;
                },
            };
        } else {
            window.SplunkRumNative.cachedSessionId = '\(sessionId)';
        }
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                self.logger.log(level: .error) {
                    "Error injecting JavaScript: \(error)"
                }
            } else {
                self.logger.log(level: .debug) {
                    "JavaScript injected successfully."
                }
            }
        }
    }
}

// Type for conforming to ModuleEventMetadata
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

// Type for conforming to ModuleEventData
public struct WebViewInstrumentationData: ModuleEventData {}

