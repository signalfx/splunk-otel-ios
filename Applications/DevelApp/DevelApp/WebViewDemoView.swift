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

    private static let isBrumDemoEnabled = true

    @State private var modernWebView = WKWebView()
    @State private var modernWebViewWithLegacyCall = WKWebView()
    @State private var legacyWebView = WKWebView()
    @State private var legacyWebViewWithLegacyCall = WKWebView()
    @State private var callbackTestWebView = WKWebView()
    @State private var brumWebView = WKWebView()

    // Store the script content in variables
    private let modernScriptContent = WebDemoJS.modernScriptExample()
    private let legacyScriptContent = WebDemoJS.legacyScriptExample()
    private let colorForSync = Color(red: 0.80, green: 0.92, blue: 0.85)
    private let colorForAsync = Color(red: 0.85, green: 0.82, blue: 0.95)
    private let colorForCallback = Color(red: 0.95, green: 0.90, blue: 0.80)
    private let colorForBrum = Color(red: 0.85, green: 0.95, blue: 0.95)

    var changeSessionIdButton: WebDemoButton {
        WebDemoButton(label: "Change Native Session ID") {
            SplunkRum.poc_forceNewSession()
        }
    }

    var callbackTestButton: WebDemoButton {
        WebDemoButton(label: "Inject SplunkRumNative and Test Callback") {
            SplunkRum.shared.webView.integrateWithBrowserRum(callbackTestWebView)
        }
    }

    var brumWebViewButton: WebDemoButton {
        WebDemoButton(label: "Inject and Demo with Full BRUM") {
            SplunkRum.shared.webView.integrateWithBrowserRum(brumWebView)
        }
    }

    var legacyWebViewButton: WebDemoButton {
        WebDemoButton(label: "Inject JavaScript and demo getNativeSessionId()") {
            SplunkRum.shared.webView.integrateWithBrowserRum(legacyWebView)
        }
    }

    var modernWebViewButton: WebDemoButton {
        WebDemoButton(label: "Inject JavaScript and demo getNativeSessionIdAsync()") {
            SplunkRum.shared.webView.integrateWithBrowserRum(modernWebView)
        }
    }

    var legacyWebViewWithLegacyCallButton: WebDemoButton {
        // "Legacy call" refers to a call to the inject API done directly off the SplunkRum namespace. Provided for compatibility. Deprecation warning in Xcode here is expected. Here we use the JavaScript sync API.

        WebDemoButton(label: "Inject JavaScript and demo getNativeSessionId() using legacy call") {
            SplunkRum.integrateWithBrowserRum(legacyWebViewWithLegacyCall)
        }
    }

    var modernWebViewWithLegacyCallButton: WebDemoButton {
        // "Legacy call" refers to a call to the inject API done directly off the SplunkRum namespace. Provided for compatibility for now. Deprecation warning in Xcode here is expected. Here we use the JavaScript async API.
        WebDemoButton(label: "Inject JavaScript and demo getNativeSessionIdAsync() using legacy call") {
            SplunkRum.integrateWithBrowserRum(modernWebViewWithLegacyCall)
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                DemoHeaderView()

                DemoNote()

                if WebViewDemoView.isBrumDemoEnabled {
                    WebViewSectionView(
                        caption: "Full BRUM Integration Demo",
                        webView: brumWebView,
                        backgroundColor: colorForBrum,
                        buttons: [brumWebViewButton]
                    )
                } else {
                    PlaceholderSectionView(
                        caption: "Full BRUM Integration Demo",
                        explanation: "This section is disabled by default. Use `isBrumDemoEnabled` in WebViewDemoView.swift to enable it. You'll also need to set the token and realm in the brumScript() function in WebDemoJS.swift."
                    )
                }

                WebViewSectionView(
                    caption: "Current BRUM-style sync JavaScript API",
                    webView: legacyWebView,
                    backgroundColor: colorForSync,
                    buttons: [legacyWebViewButton]
                )

                WebViewSectionView(
                    caption: "Optional async JavaScript API",
                    webView: modernWebView,
                    backgroundColor: colorForAsync,
                    buttons: [modernWebViewButton]
                )

                WebViewSectionView(
                    caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with current  sync JavaScript API",
                    webView: legacyWebViewWithLegacyCall,
                    backgroundColor: colorForSync,
                    buttons: [legacyWebViewWithLegacyCallButton]
                )

                WebViewSectionView(
                    caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with modern async JavaScript API",
                    webView: modernWebViewWithLegacyCall,
                    backgroundColor: colorForAsync,
                    buttons: [modernWebViewWithLegacyCallButton]
                )

                WebViewSectionView(
                    caption: "Callback Test: onNativeSessionIdChanged",
                    webView: callbackTestWebView,
                    backgroundColor: colorForCallback,
                    buttons: [callbackTestButton, changeSessionIdButton],
                    height: 200
                )
                Spacer()
            }
            .onAppear {
                WebDemoHTML.loadWebViewContentWithBRUM(
                    for: brumWebView,
                    scriptContent: legacyScriptContent
                )
                WebDemoHTML.loadWebViewContent(for: legacyWebView, scriptContent: legacyScriptContent)
                WebDemoHTML.loadWebViewContent(for: modernWebView, scriptContent: modernScriptContent)
                WebDemoHTML.loadWebViewContent(for: modernWebViewWithLegacyCall, scriptContent: modernScriptContent)
                WebDemoHTML.loadWebViewContent(for: legacyWebViewWithLegacyCall, scriptContent: legacyScriptContent)
                WebDemoHTML.loadCallbackTestWebViewContent(for: callbackTestWebView)
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
}

// MARK: - WebDemoButton

struct WebDemoButton: View, Identifiable {
    let id = UUID()
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .cornerRadius(8)
    }
}


// MARK: - WebViewSectionView

struct WebViewSectionView: View {
    let caption: String
    let webView: WKWebView
    let backgroundColor: Color
    let buttons: [WebDemoButton]
    let height: CGFloat

    init(caption: String, webView: WKWebView, backgroundColor: Color, buttons: [WebDemoButton], height: CGFloat = 150) {
        self.caption = caption
        self.webView = webView
        self.backgroundColor = backgroundColor
        self.buttons = buttons
        self.height = height
    }

    var body: some View {
        VStack {
            Text(caption)
                .font(.footnote)
                .padding(.top)
            WebViewRepresentable(webView: webView)
                .frame(height: height)
                .border(Color.gray)
                .padding(.horizontal)
            VStack(spacing: 0) {
                ForEach(buttons) { button in
                    button
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .padding()
    }
}

// MARK: - PlaceholderSectionView

struct PlaceholderSectionView: View {
    let caption: String
    let explanation: String

    var body: some View {
        VStack(spacing: 12) {
            Text(caption)
                .font(.footnote)
                .foregroundColor(.secondary)

            Text(explanation)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding()
    }
}
// MARK: - UIKit SwiftUI wrapper

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to do here
    }
}
