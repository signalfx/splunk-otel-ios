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
internal import SplunkCommon
@_spi(SplunkInternal) internal import SplunkWebView

#if canImport(WebKit)
    import WebKit
#endif

/// The public-facing proxy class that forwards calls to the internal WebView module.
///
/// It also forwards session changes to the module, which pushes the new session into instrumented web views.
final class WebView: WebViewInstrumentationModule {

    /// Holds the *real* module instance from the SplunkWebView module.
    private let module: SplunkWebView.WebViewInstrumentation

    /// The center that the agent's session posts `sessionDidResetNotification` on.
    private let notificationCenter: NotificationCenter

    /// Removed in `deinit`, so the center stops calling the module once the proxy is gone.
    private let sessionDidResetObserver: NSObjectProtocol

    init(
        module: SplunkWebView.WebViewInstrumentation,
        sharedState: AgentSharedState,
        notificationCenter: NotificationCenter = .default
    ) {
        module.sharedState = sharedState
        self.module = module
        self.notificationCenter = notificationCenter

        // The module reads the new session from the shared state and pushes it into the open pages.
        sessionDidResetObserver = notificationCenter.addObserver(
            forName: DefaultSession.sessionDidResetNotification,
            object: nil,
            queue: nil
        ) { [module] _ in
            module.nativeSessionDidChange()
        }
    }

    deinit {
        notificationCenter.removeObserver(sessionDidResetObserver)
    }

    #if canImport(WebKit)
        func integrateWithBrowserRum(_ view: WKWebView) {
            module.injectSessionId(into: view)
        }
    #endif
}
