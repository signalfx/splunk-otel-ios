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
    @State private var modernWebViewWithLegacyCall = WKWebView()
    @State private var legacyWebView = WKWebView()
    @State private var legacyWebViewWithLegacyCall = WKWebView()

    // Store the script content in variables
    private let modernScriptContent = modernScriptExample()
    private let legacyScriptContent = legacyScriptExample()
    private let colorForSync = Color(red: 0.80, green: 0.92, blue: 0.85)
    private let colorForAsync = Color(red: 0.85, green: 0.82, blue: 0.95)


    var body: some View {
        ScrollView {

            VStack {
                DemoHeaderView()

                DemoNote()

                // Legacy WebView Section
                WebViewSectionView(
                    caption: "Current BRUM-style sync JavaScript API",
                    webView: legacyWebView,
                    buttonText: "Inject JavaScript and demo getNativeSessionId()",
                    backgroundColor: colorForSync,
                    scriptContent: legacyScriptContent,
                    injectAction: injectIntoLegacyWebView
                )

                // Modern WebView Section
                WebViewSectionView(
                    caption: "Optional async JavaScript API",
                    webView: modernWebView,
                    buttonText: "Inject JavaScript and demo getNativeSessionIdAsync()",
                    backgroundColor: colorForAsync,
                    scriptContent: modernScriptContent,
                    injectAction: injectIntoModernWebView
                )

                // Legacy WebView, Legacy Call Section
                WebViewSectionView(
                    caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with current  sync JavaScript API",
                    webView: legacyWebViewWithLegacyCall,
                    buttonText: "Inject JavaScript and demo getNativeSessionId() using legacy call",
                    backgroundColor: colorForSync,
                    scriptContent: legacyScriptContent,
                    injectAction: injectIntoLegacyWebViewWithLegacyCall
                )

                // Modern WebView, Legacy Call Section
                WebViewSectionView(
                    caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with modern async JavaScript API",
                    webView: modernWebViewWithLegacyCall,
                    buttonText: "Inject JavaScript and demo getNativeSessionIdAsync() using legacy call",
                    backgroundColor: colorForAsync,
                    scriptContent: modernScriptContent,
                    injectAction: injectIntoModernWebViewWithLegacyCall
                )
                Spacer()
            }
            .onAppear {
                loadWebViewContent(for: legacyWebView, scriptContent: legacyScriptContent)
                loadWebViewContent(for: modernWebView, scriptContent: modernScriptContent)
                loadWebViewContent(for: modernWebViewWithLegacyCall, scriptContent: modernScriptContent)
                loadWebViewContent(for: legacyWebViewWithLegacyCall, scriptContent: legacyScriptContent)
            }
        }
        .navigationTitle("WebView Demo")
    }

    struct DemoNote: View {
        var body: some View {
            (
                Text("Note about the demo: ")
                    .bold()
                +
                Text("These webviews use timers to poll the sessionId. Your first thought might be: ")
                +
                Text("this is not a model for how BRUM should work. ")
                    .italic()
                +
                Text("But it demonstrates that if a JavaScript process wants to get the updated native sessionId, it can.")
            )
            .padding()
        }
    }

    // Currently not used in the demo pending better infrastructure for handling tokens vis-a-vis git commits.
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

    // This provides an optional async version of the call, `getNativeSessionIdAsync()`, for BRUM when BRUM is ready to use that.
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

    // This is the default case today. Here "legacy" (not to be confused with "legacy call" which is about how the integration is done in the iOS code) refers to the BRUM agent using `getNativeSessionId()`, a sync function, as it currently does. Non-legacy would be a different hypothetical future rev of the BRUM agent that wants an async call; they would call `await getNativeSessionAsync()` as seen elsewhere in the "modern" examples.
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
            <style>
            #extra-height {
              height: 200px;
              background-color: transparent;
            }
            </style>
            <script>
                \(scriptContent)
            </script>
        </head>
        <body style="font-size: 48px; font-family: sans-serif; background: #fafaff;">
            <p style="font-size: 36px; font-variant: small-caps;">- web content -</p>
            <h3>Current Native Session ID:</h3>
            <p id="sessionId">unknown</p>
            <div id="extra-height"></div>
        </body>
        </html>
        """
        webView.loadHTMLString(initialContent, baseURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.scrollView.flashScrollIndicators()
        }
    }

    // Does work, but currently not used in the demo. Use with demo code helper `brumScript()` and edit the SwiftUI content to add a section for using this.
    private func loadWebViewContentWithBRUM(for webView: WKWebView, scriptContent: String) {
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
        SplunkRum.shared.webView.integrateWithBrowserRum(modernWebView)
    }

    // "Legacy call" refers to a call to the inject API done directly off the SplunkRum namespace. Provided for compatibility for now. Deprecation warning in Xcode here is expected. Here we use the JavaScript async API.
    private func injectIntoModernWebViewWithLegacyCall() {
        SplunkRum.integrateWithBrowserRum(modernWebViewWithLegacyCall)
    }

    // "Legacy call" refers to a call to the inject API done directly off the SplunkRum namespace. Provided for compatibility. Deprecation warning in Xcode here is expected. Here we use the JavaScript sync API.
    private func injectIntoLegacyWebViewWithLegacyCall() {
        SplunkRum.integrateWithBrowserRum(legacyWebViewWithLegacyCall)
    }

    private func injectIntoLegacyWebView() {
        SplunkRum.shared.webView.integrateWithBrowserRum(legacyWebView)
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
