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
    @State private var modernWebView = WKWebView()
    @State private var legacyWebView = WKWebView()

    // Store the script content in variables
    private let modernScriptContent = modernScriptExample()
    private let legacyScriptContent = legacyScriptExample()

    var body: some View {
        VStack {
            DemoHeaderView()

            // Legacy WebView Section
            WebViewSectionView(
                caption: "WebView using current BRUM legacy API",
                webView: legacyWebView,
                buttonText: "Inject JavaScript (legacy, sync)",
                backgroundColor: Color(red: 0.9, green: 0.93, blue: 1.0),
                scriptContent: legacyScriptContent,
                injectAction: injectIntoLegacyWebView
            )

            // Modern WebView Section
            WebViewSectionView(
                caption: "WebView using future BRUM async API",
                webView: modernWebView,
                buttonText: "Inject JavaScript (modern, async)",
                backgroundColor: Color(red: 0.88, green: 1.0, blue: 0.88),
                scriptContent: modernScriptContent,
                injectAction: injectIntoModernWebView
            )

            Spacer()
        }
        .onAppear {
            loadWebViewContent(for: modernWebView, scriptContent: modernScriptContent)
            loadWebViewContent(for: legacyWebView, scriptContent: legacyScriptContent)
        }
        .navigationTitle("WebView Demo")
    }

    private static func brumScript() -> String {
        return """
        <script src="https://cdn.signalfx.com/o11y-gdi-rum/latest/splunk-otel-web.js" crossorigin="anonymous">
        </script>
        <script>
            SplunkRum.init(
            {
                realm: '<realm>',
                rumAccessToken: '<token>',
                applicationName: 'com.splunk.rum.DevelApp',
                version: '1.0'
            });
        </script>
        <script type="module">
            import { trace } from 'https://cdn.jsdelivr.net/npm/@opentelemetry/api@1.5.0/build/esm/index.js';
            async function reportPeriodically() {
                const tracer = trace.getTracer('testingDevelApp');
                const span = tracer.startSpan('report');
                span.setAttribute('testNativeSessionId', window.SplunkRumNative.getNativeSessionId());
                span.end();
            }
            setInterval(reportPeriodically, 60000);
        </script>
        """
    }

    private static func modernScriptExample() -> String {
        return """
        async function updateSessionId() {
            try {
                const response = await window.SplunkRumNative.getNativeSessionIdAsync();
                document.getElementById('sessionId').innerText = response;
            } catch (error) {
                document.getElementById('sessionId').innerText = "unknown";
                console.log(`Error getting native Session ID: ${error.message}`);
            }
        }
        setInterval(updateSessionId, 1000);
        """
    }

    private static func legacyScriptExample() -> String {
        return """
        function updateSessionId() {
            try {
                const sessionId = window.SplunkRumNative.getNativeSessionId();
                document.getElementById('sessionId').innerText = sessionId;
            } catch (error) {
                document.getElementById('sessionId').innerText = "unknown";
                console.log(`Error getting native Session ID: ${error.message}`);
            }
        }
        setInterval(updateSessionId, 1000);
        """
    }

    private func loadWebViewContent(for webView: WKWebView, scriptContent: String) {
        let initialContent = """
        <!DOCTYPE html>
        <html>
        <head>
            \(WebViewDemoView.brumScript())
            <script>
                \(scriptContent)
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

    private func injectIntoModernWebView() {
        SplunkRum.webView.integrateWithBrowserRum(modernWebView)
    }

    private func injectIntoLegacyWebView() {
        SplunkRum.webView.integrateWithBrowserRum(legacyWebView)
    }
}

struct WebViewSectionView: View {
    let caption: String
    let webView: WKWebView
    let buttonText: String
    let backgroundColor: Color
    let scriptContent: String
    let injectAction: () -> Void

    var body: some View {
        VStack {
            Text(caption)
                .font(.footnote)
                .padding(.top)
            WebViewRepresentable(webView: webView)
                .frame(height: 150)
                .border(Color.gray)
                .padding(.horizontal)
            Button(buttonText) {
                injectAction()
            }
            .padding()
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .padding()
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to do here
    }
}

