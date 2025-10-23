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

    // MARK: - Private

    private static let isBrumDemoEnabled = false


    // MARK: - State Variables for WebViews

    @State
    private var modernWebView = WKWebView()

    @State
    private var modernWebViewWithLegacyCall = WKWebView()

    @State
    private var legacyWebView = WKWebView()

    @State
    private var legacyWebViewWithLegacyCall = WKWebView()

    @State
    private var callbackTestWebView = WKWebView()

    @State
    private var brumWebView = WKWebView()


    // MARK: - Background Colors

    private let colorForSync = Color(red: 0.80, green: 0.92, blue: 0.85)
    private let colorForAsync = Color(red: 0.85, green: 0.82, blue: 0.95)
    private let colorForCallback = Color(red: 0.95, green: 0.90, blue: 0.80)
    private let colorForBrum = Color(red: 0.85, green: 0.95, blue: 0.95)

    // swiftlint:disable closure_body_length
    var body: some View {
        ScrollView {

            VStack(alignment: .leading, spacing: 12) {

                DemoHeaderView()

                Text(
                    """
                    These webviews use timers present in the pre-injection web content to poll and show that the updated native sessionId is available.
                    The callback demo is an exception, using no polling or timer. And for all webviews, the JavaScript injected by the native agent
                    does not contain polling or timers.
                    """
                )
                .padding()

                if Self.isBrumDemoEnabled {
                    WebViewSectionView(
                        caption: "Full BRUM Integration Demo",
                        webView: brumWebView,
                        backgroundColor: colorForBrum,
                        buttons: [
                            WebDemoButton(label: "Inject and Demo with Full BRUM") {
                                SplunkRum.shared.webViewNativeBridge.integrateWithBrowserRum(brumWebView)
                                WebDemoHTML.loadWebViewContentWithBRUM(for: brumWebView, scriptContent: WebDemoJS.legacyScriptExample())
                            }
                        ]
                    )
                }
                else {
                    PlaceholderSectionView(
                        caption: "Full BRUM Integration Demo",
                        explanation: """
                            This section is disabled by default. Use `isBrumDemoEnabled` in WebViewDemoView.swift to enable it.
                            You'll also need to set the token and realm in the brumScript() function in WebDemoJS.swift.
                            """
                    )
                }

                // Standard WebViewSectionView Sections
                ForEach(getSections(), id: \.caption) { section in
                    section
                }

                // Callback Test Section
                WebViewSectionView(
                    caption: "(Disabled) Callback Test with Session Reset",
                    webView: callbackTestWebView,
                    backgroundColor: colorForCallback,
                    buttons: [
                        WebDemoButton(label: "Inject and Test Callback (No Polling)") {
                            SplunkRum.shared.webViewNativeBridge.integrateWithBrowserRum(callbackTestWebView)
                        },
                        WebDemoButton(label: "Reset Session ID") {
                            // SplunkRum.poc_forceNewSession()
                        }
                    ]
                )
                .disabled(true)
                .opacity(0.6)
            }
            .padding()
            .onAppear {
                loadWebViewContent()
            }
        }
        .navigationBarTitle("WebViewNativeBridge")
    }

    // swiftlint:enable closure_body_length


    // MARK: - Load WebView Content

    private func loadWebViewContent() {
        WebDemoHTML.loadWebViewContent(for: legacyWebView, scriptContent: WebDemoJS.legacyScriptExample())
        WebDemoHTML.loadWebViewContent(for: modernWebView, scriptContent: WebDemoJS.modernScriptExample())
        WebDemoHTML.loadWebViewContent(for: modernWebViewWithLegacyCall, scriptContent: WebDemoJS.modernScriptExample())
        WebDemoHTML.loadWebViewContent(for: legacyWebViewWithLegacyCall, scriptContent: WebDemoJS.legacyScriptExample())
        WebDemoHTML.loadCallbackTestWebViewContent(for: callbackTestWebView)
    }


    // MARK: - Standard Sections

    private func getSections() -> [WebViewSectionView] {
        [
            WebViewSectionView(
                caption: "Current BRUM-style sync JavaScript API",
                webView: legacyWebView,
                backgroundColor: colorForSync,
                buttons: createWebDemoButton(isAsync: false, isLegacy: false, webView: legacyWebView)
            ),
            WebViewSectionView(
                caption: "Future-proof async JavaScript API",
                webView: modernWebView,
                backgroundColor: colorForAsync,
                buttons: createWebDemoButton(isAsync: true, isLegacy: false, webView: modernWebView)
            ),
            WebViewSectionView(
                caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with current sync JavaScript API",
                webView: legacyWebViewWithLegacyCall,
                backgroundColor: colorForSync,
                buttons: createWebDemoButton(isAsync: false, isLegacy: true, webView: legacyWebViewWithLegacyCall)
            ),
            WebViewSectionView(
                caption: "Legacy SplunkRum.integrateWithBrowserRum(_:) call with modern async JavaScript API",
                webView: modernWebViewWithLegacyCall,
                backgroundColor: colorForAsync,
                buttons: createWebDemoButton(isAsync: true, isLegacy: true, webView: modernWebViewWithLegacyCall)
            )
        ]
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


// MARK: - WebView Section Data Model

struct WebViewSectionView: View {
    let caption: String
    let webView: WKWebView
    let backgroundColor: Color
    let buttons: [WebDemoButton]

    var body: some View {
        VStack {
            Text(caption)
                .font(.footnote)
                .padding(.top)
            WebViewRepresentable(webView: webView)
                .frame(height: buttons.count == 2 ? 200 : 150)
                .background(Color(red: 0.95, green: 0.95, blue: 0.98)) // Light gray with blue tint
                .cornerRadius(8)
                .border(Color.gray)
                .padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(buttons.indices, id: \.self) { index in
                    buttons[index]
                    if buttons.count > 1, index < buttons.count - 1 {
                        Text("—")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
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


// MARK: - WebDemoButton Model

struct WebDemoButton: View, Identifiable {
    let id = UUID()
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity)
        }
    }
}


// MARK: - Helper Function for Button Creation

func createWebDemoButton(
    isAsync: Bool,
    isLegacy: Bool,
    webView: WKWebView
) -> [WebDemoButton] {
    var buttons: [WebDemoButton] = []

    // Dynamic label based on parameters
    let legacyPart = isLegacy ? " using legacy call" : ""
    let label = "Inject JavaScript and demo getNativeSessionId\(isAsync ? "Async" : "")()\(legacyPart)"

    // Button action
    let action: () -> Void = {
        if isLegacy {
            SplunkRum.integrateWithBrowserRum(webView)
        }
        else {
            SplunkRum.shared.webViewNativeBridge.integrateWithBrowserRum(webView)
        }
    }

    // Create and return the button
    buttons.append(WebDemoButton(label: label, action: action))

    return buttons
}


// MARK: - UIKit SwiftUI Wrapper

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context _: Context) -> WKWebView {
        webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        // Nothing to do here
    }
}
