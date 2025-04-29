import WebKit
import CiscoLogger
import SplunkCommon

public final class WebViewInstrumentation {

    public static var instance = WebViewInstrumentation()

    private let internalLogger = CiscoLogger(configuration: .default(subsystem: "SplunkWebView", category: "Instrumentation"))

    public unowned var sharedState: AgentSharedState? = nil

    // Module conformance
    public required init() {}

    // MARK: - Internal Methods

    public func injectSessionId(into webView: WKWebView) {

        guard let sessionId = sharedState?.sessionId else {
            internalLogger.error("Session ID not available.")
            return
        }

        // Use legacy implementation JavaScript code
        let script = """
        if (!window.SplunkRumNative) {
            window.SplunkRumNative = {
                cachedSessionId: '\(sessionId)',
                getNativeSessionId: function() {
                    try {
                        window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage('').catch(function() {});
                    } catch (e) {
                        // ignored
                    }
                    return window.SplunkRumNative.cachedSessionId;
                },
            };
        } else {
            window.SplunkRumNative.cachedSessionId = '\(sessionId)';
        }
        """

        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                self.internalLogger.error("Error injecting JavaScript: \(error)")
            } else {
                self.internalLogger.debug("JavaScript injected successfully.")
            }
        }
    }
}
