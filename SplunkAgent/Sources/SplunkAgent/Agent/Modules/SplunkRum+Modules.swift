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
internal import CiscoSessionReplay
internal import SplunkAppStart
internal import SplunkAppState
internal import SplunkCustomTracking
internal import SplunkNavigation
internal import SplunkNetwork
internal import SplunkWebView
internal import SplunkNetworkMonitor
internal import SplunkInteractions
internal import SplunkSlowFrameDetector

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

#if canImport(WebKit)
    import WebKit
#endif


extension SplunkRum {

    // MARK: - Modules publish

    func registerModulePublish() {
        // Send events on data publish
        modulesManager?.onModulePublish(data: { metadata, data in
            self.eventManager?.publish(data: data, metadata: metadata) { success in
                if success {
                    self.modulesManager?.deleteModuleData(for: metadata)
                } else {
                    // TODO: MRUM_AC-1061 (post GA): Handle a case where data is not sent.
                }
            }
        })
    }


    // MARK: - Modules customization

    /// Perform specific pre-defined customizations for some modules.
    func customizeModules() {
        customizeCrashReports()
        customizeSessionReplay()
        customizeNavigation()
        customizeNetwork()
        customizeAppStart()
        customizeAppState()
        customizeNetworkMonitor()
        customizeCustomTracking()
        customizeInteractions()
        customizeWebView()
        customizeSlowFrameDetector()
    }

    /// Perform operations specific to the SessionReplay module.
    private func customizeSessionReplay() {
        let moduleType = CiscoSessionReplay.SessionReplay.self
        let sessionReplayModule = modulesManager?.module(ofType: moduleType)

        guard let sessionReplayModule else {
            return
        }

        guard agentConfiguration.endpoint.sessionReplayEndpoint != nil else {
            logger.log(level: .warn, isPrivate: false) {
                """
                Session Replay module was not installed (the valid URL for Session Replay \
                endpoint is missing in the Agent configuration).
                """
            }

            return
        }

        // By default, we turn off the default sensitivity for `WKWebView`
        #if canImport(WebKit)
            sessionReplayModule.sensitivity.set(WKWebView.self, nil)
        #endif

        // Initialize proxy API for this module
        sessionReplayProxy = SessionReplay(for: sessionReplayModule)
    }

    // Configure Navigation module.
    private func customizeNavigation() {
        let moduleType = SplunkNavigation.Navigation.self
        let navigationModule = modulesManager?.module(ofType: moduleType)

        guard let navigationModule else {
            return
        }

#if canImport(SplunkCrashReports)
        let crashReportsModule = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)
#endif

        navigationModule.agentVersion(sharedState.agentVersion)

        // Set up forwarding of screen name changes to runtime attributes.
        Task(priority: .userInitiated) {
            for await newValue in navigationModule.screenNameStream {
                runtimeAttributes.updateCustom(named: "screen.name", with: newValue)
                screenNameChangeCallback?(newValue)
#if canImport(SplunkCrashReports)
                crashReportsModule?.crashReportUpdateScreenName(newValue)
#endif
            }
        }

        // Initialize proxy API for this module
        navigationProxy = Navigation(for: navigationModule)
    }

    /// Configure Network module with shared state.
    private func customizeNetwork() {
        let networkModule = modulesManager?.module(ofType: SplunkNetwork.NetworkInstrumentation.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `sessionId` from the agent continuously.
        networkModule?.sharedState = sharedState

        // We need the endpoint url to manage trace exclusion logic
        var excludedEndpoints: [URL] = []
        if let traceUrl = agentConfiguration.endpoint.traceEndpoint {
            excludedEndpoints.append(traceUrl)
        }

        if let sessionReplayUrl = agentConfiguration.endpoint.sessionReplayEndpoint {
            excludedEndpoints.append(sessionReplayUrl)
        }

        networkModule?.excludedEndpoints = excludedEndpoints
    }

    /// Configure Crash Reports module with shared state.
    private func customizeCrashReports() {
    // swiftformat:disable indent
    #if canImport(SplunkCrashReports)
        let crashReportsModule = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `appState` from the agent in the instance of a crash.
        crashReportsModule?.sharedState = sharedState

        // Check if a crash ended the previous run of the app
        crashReportsModule?.reportCrashIfPresent()
    #endif
    // swiftformat:enable indent
    }

    /// Configure App start module with shared state.
    private func customizeAppStart() {
        let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self)

        appStartModule?.sharedState = sharedState
    }

    /// Configure App state module with shared state.
    private func customizeAppState() {
        let appStateModule = modulesManager?.module(ofType: SplunkAppState.AppStateModule.self)

        appStateModule?.sharedState = sharedState
    }

    /// Configure NetworkMonitor module
    private func customizeNetworkMonitor() {
        let networkMonitorModule = modulesManager?.module(ofType: SplunkNetworkMonitor.NetworkMonitor.self)

        networkMonitorModule?.sharedState = sharedState
    }

    /// Configure Interactions module
    private func customizeInteractions() {
        let interactionsModule = modulesManager?.module(ofType: SplunkInteractions.Interactions.self)

        guard let interactionsModule else {
            return
        }

        // Initialize proxy API for this module
        interactions = Interactions(for: interactionsModule)
    }

    /// Configure WebView Instrumentation module with shared state.
    private func customizeWebView() {
        if let webViewInstrumentationModule = modulesManager?.module(ofType: SplunkWebView.WebViewInstrumentation.self) {
            webViewProxy = WebView(module: webViewInstrumentationModule, sharedState: sharedState)
        } else {
            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module not installed."
            }
        }
    }

    /// Configure CustomTracking intrumentation module
    private func customizeCustomTracking() {
        if let customTrackingModule = modulesManager?.module(ofType: CustomTrackingInternal.self) {
            // Initialize proxy API for this module
            customTrackingProxy = CustomTracking(for: customTrackingModule)
        }
    }

    /// Configure SlowFrameDetector module
    private func customizeSlowFrameDetector() {
        if let slowFrameDetectorModule = modulesManager?.module(ofType: SplunkSlowFrameDetector.SlowFrameDetector.self) {
            // Initialize proxy API for this module
            slowFrameDetectorProxy = SlowFrameDetector(for: slowFrameDetectorModule)
        }
    }
}
