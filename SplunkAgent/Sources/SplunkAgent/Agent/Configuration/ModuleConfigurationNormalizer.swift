//
/*
Copyright 2026 Splunk Inc.

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
internal import SplunkAppStart
internal import SplunkAppState
internal import SplunkCommon
internal import SplunkCustomTracking
internal import SplunkInteractions
internal import SplunkNavigation
internal import SplunkNetwork
internal import SplunkNetworkMonitor
internal import SplunkSessionReplayProxy
internal import SplunkSlowFrameDetector
internal import SplunkWebView

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

/// Converts public SplunkAgent configuration wrappers to the exact internal
/// module configuration types used by `DefaultModulesManager`.
protocol AgentModuleConfigurationConvertible {

    // MARK: - Internal module configuration

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? { get }
}

extension SplunkRum {

    // MARK: - Module configuration normalization

    static func normalizeModuleConfigurations(_ moduleConfigurations: [Any]?) -> [Any]? {
        guard let moduleConfigurations else {
            return nil
        }

        return moduleConfigurations.compactMap { configuration in
            if let convertible = configuration as? AgentModuleConfigurationConvertible {
                return convertible.moduleConfiguration
            }

            return configuration
        }
    }
}

extension IgnoreURLs {

    // MARK: - Internal conversion

    var networkIgnoreURLs: SplunkNetwork.IgnoreURLs? {
        try? SplunkNetwork.IgnoreURLs(patterns: Set(getAllPatterns()))
    }
}

extension NavigationConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkNavigation.NavigationConfiguration(
            isEnabled: isEnabled,
            enableAutomatedTracking: enableAutomatedTracking
        )
    }
}

extension NetworkInstrumentationConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkNetwork.NetworkInstrumentationConfiguration(
            isEnabled: isEnabled,
            ignoreURLs: ignoreURLs?.networkIgnoreURLs,
            injectTraceHeaders: injectTraceHeaders,
            capturedRequestHeaders: capturedRequestHeaders,
            capturedResponseHeaders: capturedResponseHeaders
        )
    }
}

extension NetworkMonitorConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkNetworkMonitor.NetworkMonitorConfiguration(isEnabled: isEnabled)
    }
}

extension SlowFrameDetectorConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkSlowFrameDetector.SlowFrameDetectorConfiguration(isEnabled: isEnabled)
    }
}

extension CrashReportsConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        #if canImport(SplunkCrashReports)
            SplunkCrashReports.CrashReportsConfiguration(isEnabled: isEnabled)
        #else
            nil
        #endif
    }
}

extension SessionReplayConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkSessionReplayProxy.SessionReplayConfiguration(
            enabled: enabled,
            samplingRate: samplingRate
        )
    }
}

extension InteractionsConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkInteractions.InteractionsConfiguration(isEnabled: isEnabled)
    }
}

extension WebViewInstrumentationConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkWebView.WebViewInstrumentationConfiguration()
    }
}

extension AppStartConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkAppStart.AppStartConfiguration()
    }
}

extension AppStateConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkAppState.AppStateConfiguration()
    }
}

extension CustomTrackingConfiguration: AgentModuleConfigurationConvertible {

    var moduleConfiguration: (any SplunkCommon.ModuleConfiguration)? {
        SplunkCustomTracking.CustomTrackingConfiguration()
    }
}
