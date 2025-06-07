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

public final class WebViewInstrumentationInternal: NSObject {

    public static var instance = WebViewInstrumentationInternal()

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "SplunkWebView")

    public var sharedState: AgentSharedState?

    // Module conformance
    public override required init() {}

    // MARK: - Internal Methods

    public func injectSessionId(into webView: WKWebView) {

        guard let sessionId = sharedState?.sessionId else {
            logger.log(level: .warn) {
                "Native Session ID not available for webview injection."
            }
            return
        }

        let javaScript = """
        if (!window.SplunkRumNative) {
            window.SplunkRumNative = {};
        }

        window.SplunkRumNative.getNativeSessionId = () => {
            return window.webkit.messageHandlers.sessionBridge
                .postMessage({})
                .then(r => r.sessionId);
        };
        """

        let userScript = WKUserScript(
            source: javaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        contentController(
            forName: "sessionBridge",
            forWebView: webView
        ).addUserScript(userScript)

        // Needed at first load only; user script will persist across reloads and navigation
        webView.evaluateJavaScript(javaScript)
    }

    private func contentController(forName name: String, forWebView webView: WKWebView) -> WKUserContentController {
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: name)
        contentController.addScriptMessageHandler(self, contentWorld: .page, name: name)
        return contentController
    }
}

// MARK: - WKScriptMessageHandlerWithReply

extension WebViewInstrumentationInternal: WKScriptMessageHandlerWithReply {

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

