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
internal import SplunkNetwork
internal import SplunkNetworkInfo

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

internal import SplunkWebView
internal import SplunkWebViewProxy

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
        customizeNetwork()
        customizeAppStart()
        customizeNetworkInfo()
        customizeWebViewInstrumentation()
    }

    /// Perform operations specific to the SessionReplay module.
    private func customizeSessionReplay() {
        let moduleType = CiscoSessionReplay.SessionReplay.self
        let sessionReplayModule = modulesManager?.module(ofType: moduleType)

        guard let sessionReplayModule else {
            return
        }

        // Initialize proxy API for this module
        sessionReplayProxy = SessionReplay(for: sessionReplayModule)
    }

    /// Configure Network module with shared state.
    private func customizeNetwork() {
        let networkModule = modulesManager?.module(ofType: SplunkNetwork.NetworkInstrumentation.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `sessionID` from the agent continuously.
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

    /// Configure App start module
    private func customizeAppStart() {
        let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self)

        appStartModule?.sharedState = sharedState
    }

    /// Configure NetworkInfo module
    private func customizeNetworkInfo() {
        let networkInfoModule = modulesManager?.module(ofType: SplunkNetworkInfo.NetworkInfo.self)

        networkInfoModule?.sharedState = sharedState
    }

    /// Configure WebView intrumentation module
    private func customizeWebViewInstrumentation() {
        // Get WebViewInstrumentation module, set its sharedState
        if let webViewInstrumentationModule = modulesManager?.module(ofType: SplunkWebView.WebViewInstrumentationInternal.self) {
            WebViewInstrumentationInternal.instance.sharedState = sharedState
            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module installed."
            }
        } else {
            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module not installed."
            }
        }
    }
}
