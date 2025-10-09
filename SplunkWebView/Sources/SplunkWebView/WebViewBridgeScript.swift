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

import Foundation

/// A utility for generating the JavaScript bridge script injected into `WKWebView` instances.
enum WebViewBridgeScript {

    private static let scriptTemplate: String = {
        guard let url = Bundle.module.url(forResource: "WebViewBridgeScript", withExtension: "js") else {
            preconditionFailure("WebViewBridgeScript.js not found in bundle.")
        }
        guard let script = try? String(contentsOf: url) else {
            preconditionFailure("Could not read WebViewBridgeScript.js from bundle.")
        }
        return script
    }()

    /// Generates the complete JavaScript string to be injected into a web view.
    ///
    /// The script is loaded from the `WebViewBridgeScript.js` resource file, and placeholders
    /// for `sessionId` and `handlerName` are replaced with their actual values.
    ///
    /// - Parameters:
    ///   - sessionId: The initial native session ID to be cached in the JavaScript context.
    ///   - handlerName: The name of the `WKScriptMessageHandler` used for asynchronous communication.
    /// - Returns: A fully interpolated JavaScript string ready for injection.
    static func generate(sessionId: String, handlerName: String) -> String {
        scriptTemplate
            .replacingOccurrences(of: "__SESSION_ID__", with: "'\(sessionId)'")
            .replacingOccurrences(of: "__HANDLER_NAME__", with: handlerName)
    }
}
