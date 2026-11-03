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

    private static let resourceBundleName = "SplunkAgent_SplunkWebView"

    private static let scriptTemplate = loadScriptTemplate()

    static func scriptResourceURL(in bundles: [Bundle], packageBundleName: String = resourceBundleName) -> URL? {
        for bundle in bundles {
            if let url = bundle.url(forResource: "WebViewBridgeScript", withExtension: "js") {
                return url
            }

            let bundleLocations = [bundle.resourceURL, bundle.bundleURL].compactMap(\.self)
            for location in bundleLocations {
                let packageBundleURL = location.appendingPathComponent(packageBundleName + ".bundle")
                guard let packageBundle = Bundle(url: packageBundleURL) else {
                    continue
                }

                if let url = packageBundle.url(forResource: "WebViewBridgeScript", withExtension: "js") {
                    return url
                }
            }
        }

        return nil
    }

    private static func loadScriptTemplate() -> String? {
        #if DEBUG
            let resourceBundleOverride =
                ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_PATH"]
                ?? ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_URL"]
            if let resourceBundleOverride,
                let bundle = Bundle(url: URL(fileURLWithPath: resourceBundleOverride)),
                let url = scriptResourceURL(in: [bundle])
            {
                return loadScript(from: url)
            }
        #endif

        let candidateBundles = [Bundle(for: WebViewInstrumentation.self), Bundle.main]
        guard let url = scriptResourceURL(in: candidateBundles) else {
            return nil
        }

        return loadScript(from: url)
    }

    static func loadScript(from url: URL?) -> String? {
        guard let url else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Generates the complete JavaScript string to be injected into a web view.
    ///
    /// The script is loaded from the `WebViewBridgeScript.js` resource file, and placeholders
    /// for `sessionId`, `sessionMetadata`, and `handlerName` are replaced with their actual values.
    ///
    /// - Parameters:
    ///   - sessionId: The initial native session ID to be cached in the JavaScript context.
    ///   - sessionMetadata: The initial Base64-encoded session metadata string, or `nil` if unavailable.
    ///   - handlerName: The name of the `WKScriptMessageHandler` used for asynchronous communication.
    ///
    /// - Returns: A fully interpolated JavaScript string ready for injection, or `nil` if the resource is unavailable.
    static func generate(sessionId: String, sessionMetadata: String?, handlerName: String) -> String? {
        guard let scriptTemplate else {
            return nil
        }

        let metadataLiteral = sessionMetadata.map { "'\($0)'" } ?? "null"
        return
            scriptTemplate
            .replacingOccurrences(of: "__SESSION_ID__", with: "'\(sessionId)'")
            .replacingOccurrences(of: "__SESSION_METADATA__", with: metadataLiteral)
            .replacingOccurrences(of: "__HANDLER_NAME__", with: handlerName)
    }
}
