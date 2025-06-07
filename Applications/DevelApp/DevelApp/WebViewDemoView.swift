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

import Combine
import Foundation
import SplunkAgent
import SwiftUI
import WebKit

struct WebViewDemoView: View {
    @State private var webView = WKWebView()
    @State private var injected = false

    var body: some View {
        VStack {
            DemoHeaderView()
            WebViewRepresentable(webView: webView, injected: injected)
                .frame(height: 300)
                .border(Color.gray)
                .padding()

            Button("Inject JavaScript") {
                injectJavaScript()
            }
            .padding()
            Spacer()
        }
        .onAppear {
            loadWebViewContent()
        }
        .navigationTitle("WebView Demo")
    }

    /// Load initial HTML content into the WebView
    private func loadWebViewContent() {
        let initialContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <script>
                // This pre-existing script is not needed in a user's
                // webView. It is just a demo stand-in for the BRUM agent.
                //
                // As the agent would, it gracefully handles the absence
                // of the API prior to injection, and after injection
                // it makes use of the API.
                async function updateSessionId() {
                    try {
                        const response = await window.SplunkRumNative.getNativeSessionId();
                        document.getElementById('sessionId').innerText = response;
                    } catch (error) {
                        document.getElementById('sessionId').innerText = 'Error getting native Session ID';
                    }
                }

                // Likewise, the timer represents the initiative of the
                // BRUM agent. In real usage, the agent would of course
                // be free to access the API on demand.
                setInterval(updateSessionId, 1000); // pull every 1 second
            </script>
        </head>
        <body style="font-size: 48px; font-family: sans-serif">
            <h3>Current Native Session ID:</h3>
            <p id="sessionId">unknown</p>
        </body>
        </html>
        """
        webView.loadHTMLString(initialContent, baseURL: nil)
    }

    /// Inject the JavaScript bridge into the WebView
    private func injectJavaScript() {
        SplunkRum.webView.integrateWithBrowserRum(webView)
        injected = true
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    let injected: Bool

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to do here
    }
}
