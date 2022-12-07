//
/*
Copyright 2021 Splunk Inc.

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

import Foundation
import WebKit

class WebViewInstrumentation: NSObject, WKScriptMessageHandler {
    let view: WKWebView
    var lastSetSessionId: String
    init(view: WKWebView) {
        self.view = view
        lastSetSessionId = getRumSessionId()
    }
    func integrate() {
        let ucc = view.configuration.userContentController
        // part 1: message handler for updates
        ucc.add(self, name: "SplunkRumNativeUpdate")

        // window.webkit.messageHandlers.logging.postMessage(
        // part 2: initial script
        lastSetSessionId = getRumSessionId()
        let js = """
            if (!window.SplunkRumNative) {
                window.SplunkRumNative = {
                    cachedSessionId: '\(lastSetSessionId)',
                    getNativeSessionId: function() {
                        try {
                            window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage('').catch(function() {});
                        } catch (e) {
                            // ignored
                        }
                        return window.SplunkRumNative.cachedSessionId;
                    },
                };
            }
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(script)
    }

    // called when browser calls window.webkit.messageHandlers.SplunkRumNativeUpdate.postMessage();
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let newSessionId = getRumSessionId()
        if newSessionId == lastSetSessionId {
            return
        }
        let js = """
            window.SplunkRumNative.cachedSessionId = '\(newSessionId)';
        """
        view.evaluateJavaScript(js)
        lastSetSessionId = newSessionId
    }
}

func integrateWebViewWithBrowserRum(view: WKWebView) {
    let inst = WebViewInstrumentation(view: view)
    inst.integrate()
}
