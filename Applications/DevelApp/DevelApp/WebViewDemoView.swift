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
    @State private var subscription: AnyCancellable?

    var body: some View {
        VStack {
            Text("WebView Demo").font(.title).padding()
            DemoHeaderView()
            WebViewRepresentable(webView: webView, injected: injected)
                .frame(height: 200)
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
            observeSessionIdChanges()
        }
        .onDisappear {
            subscription?.cancel()
        }
        .navigationTitle("WebView Demo")
    }

    private func loadWebViewContent() {
        // Load a simple HTML page with a placeholder for the session ID
        let initialContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>WebView Demo</title>
                <script>
                    function updateSessionId() {
                        // Fetch the session ID from the native layer
                        const sessionId = window.SplunkRumNative.getNativeSessionId();
                        document.getElementById('sessionId').innerText = sessionId;
                    }

                    // Update the session ID every 1 second
                    setInterval(updateSessionId, 1000);
                </script>
            </head>
            <body>
                <h1>WebView Demo</h1>
                <p>Current Session ID:</p>
                <p id="sessionId">unknown</p>
            </body>
            </html>
        """
        webView.loadHTMLString(initialContent, baseURL: nil)
    }

    private func injectJavaScript() {
        // This integrates the web view with SplunkRum
        SplunkRum.webView.integrateWithBrowserRum(webView)
        injected = true
    }

    private func observeSessionIdChanges() {
        // Observe changes to the session ID and reload the web view content if needed
        subscription = NotificationCenter.default
            .publisher(for: NSNotification.Name("com.splunk.rum.session-id-did-change"))
            .sink { _ in
                print("Session ID changed. WebView should now reflect the updated value.")
            }
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
