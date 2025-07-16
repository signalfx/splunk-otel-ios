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

internal import CiscoLogger
internal import SplunkCommon

#if canImport(WebKit)
    import WebKit
#endif

/// The class implementing WebView public API in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class WebViewNonOperational: WebViewInstrumentationModule {

    // MARK: - Private

    private let logger: DefaultLogAgent


    // MARK: - Initialization

    init() {
        logger = DefaultLogAgent(
            poolName: PackageIdentifier.nonOperationalInstance(),
            category: "WebView"
        )
    }


    // MARK: - Public

    #if canImport(WebKit)
        func integrateWithBrowserRum(_ view: WKWebView) {
            logAccess(toApi: #function)
        }
    #endif


    // MARK: - Logger

    func logAccess(toApi named: String) {
        logger.log(level: .notice) {
            """
            Attempt to access the API of a non-operational WebView module. \n
            API: `\(named)`
            """
        }
    }
}
