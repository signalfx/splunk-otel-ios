//
//  WebDemoHTML.swift
//  DevelApp
//

import WebKit

public struct WebDemoHTML {

    public static func loadWebViewContent(for webView: WKWebView, scriptContent: String) {
        let initialContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
            #extra-height {
              height: 200px;
              background-color: transparent;
            }
            body {
                font-size: 48px;
                font-family: sans-serif;
                background: #fafaff;
                word-wrap: break-word;
            }
            </style>
            <script>
                \(scriptContent)
            </script>
        </head>
        <body>
            <p style="font-size: 36px; font-variant: small-caps;">- web content -</p>
            <h4>Current Native Session ID:</h4>
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

    public static func loadCallbackTestWebViewContent(for webView: WKWebView) {
        // Element 'callbackStatus' will show the callback's output.
        let initialContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
            body {
                font-size: 48px;
                font-family: sans-serif;
                background: #fafaff;
                word-wrap: break-word;
            }
            </style>
            <!-- Polling script intentionally removed for this test. -->
            <!-- Script 2: Our new logic to set the callback handler -->
            <script>
                \(WebDemoJS.callbackSetupScript())
            </script>
        </head>
        <body>
            <p style="font-size: 36px; font-variant: small-caps;">- web content -</p>
            <h4>Current Native Session ID:</h4>
            <p id="sessionId">No polling here. This will not update.</p>

            <!-- New section just for this test -->
            <h4>Callback Status:</h4>
            <div id="callbackStatus" style="font-size: 48px;">Not called yet.</div>
        </body>
        </html>
        """
        webView.loadHTMLString(initialContent, baseURL: nil)
    }

    // Does work, but currently not used in the demo. Use with demo code helper `brumScript()` and edit the SwiftUI content to add a section for using this.
    public static func loadWebViewContentWithBRUM(for webView: WKWebView, scriptContent: String) {
        let initialContent = """
        <!DOCTYPE html>
        <html>
        <head>
            \(WebDemoJS.brumScript())
            <script>
                \(scriptContent)
            </script>
        </head>
        <body style="font-size: 48px; font-family: sans-serif">
            <h4>Current Native Session ID:</h4>
            <p id="sessionId">unknown</p>
            <p>Above session ID is not from BRUM's detection. To see whether BRUM picked up the session ID, watch the traffic over the wire as reported in the Xcode Console while tethered to Xcode (such as when running in the iOS Simulator).
        </body>
        </html>
        """
        webView.loadHTMLString(initialContent, baseURL: nil)
    }
}
