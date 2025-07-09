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

internal import SplunkCommon

#if canImport(SplunkAppStart)
    internal import SplunkAppStart
#endif

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

#if canImport(SplunkNavigation)
    internal import SplunkNavigation
#endif

#if canImport(SplunkNetwork)
    internal import SplunkNetwork
#endif

#if canImport(SplunkNetworkMonitor)
    internal import SplunkNetworkMonitor
#endif

#if canImport(CiscoSessionReplay)
    internal import CiscoSessionReplay
    internal import SplunkSessionReplayProxy
#endif

#if canImport(SplunkSlowFrameDetector)
    internal import SplunkSlowFrameDetector
#endif

#if canImport(SplunkWebView)
    internal import SplunkWebView
#endif

#if canImport(SplunkCustomTracking)
    internal import SplunkCustomTracking
#endif

#if canImport(SplunkInteractions)
    internal import SplunkInteractions
#endif


/// The class implements the default pool of available modules.
class DefaultModulesPool: AgentModulesPool {

    static var `default`: [any Module.Type] {
        var knownModules = [any Module.Type]()

        // Crash reports
        #if canImport(SplunkCrashReports)
            knownModules.append(CrashReports.self)
        #endif

        // App Start
        #if canImport(SplunkAppStart)
            knownModules.append(AppStart.self)
        #endif

        // Session Replay
        #if canImport(CiscoSessionReplay)
            knownModules.append(CiscoSessionReplay.SessionReplay.self)
        #endif

        // Navigation Instrumentation
        #if canImport(SplunkNavigation)
            knownModules.append(SplunkNavigation.Navigation.self)
        #endif

        // Network Instrumentation
        #if canImport(SplunkNetwork)
            knownModules.append(NetworkInstrumentation.self)
        #endif

        // Network Monitor
        #if canImport(SplunkNetworkMonitor)
            knownModules.append(NetworkMonitor.self)
        #endif

        // Slow Frame Detector
        #if canImport(SplunkSlowFrameDetector)
        knownModules.append(SplunkSlowFrameDetector.SlowFrameDetector.self)
        #endif

        // Web View Instrumentation
        #if canImport(SplunkWebView)
            knownModules.append(WebViewInstrumentation.self)
        #endif

        // Custom Tracking
        #if canImport(SplunkCustomTracking)
            knownModules.append(CustomTrackingInternal.self)
        #endif

        // Interactions
        #if canImport(SplunkInteractions)
            knownModules.append(SplunkInteractions.Interactions.self)
        #endif

        return knownModules
    }
}
