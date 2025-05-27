//
/*
Copyright 2024 Splunk Inc.

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

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

#if canImport(SplunkNetwork)
    internal import SplunkNetwork
#endif

#if canImport(CiscoSessionReplay)
    internal import CiscoSessionReplay
    internal import SplunkSessionReplayProxy
#endif

#if canImport(SplunkSlowFrameDetector)
    internal import SplunkSlowFrameDetector
#endif

#if canImport(SplunkAppStart)
    internal import SplunkAppStart
#endif

#if canImport(SplunkWebView)
    internal import SplunkWebView
    internal import SplunkWebViewProxy
#endif

#if canImport(SplunkCustomTracking)
    internal import SplunkCustomTracking
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

        // Network Instrumentation
        #if canImport(SplunkNetwork)
            knownModules.append(NetworkInstrumentation.self)
        #endif

        // Slow Frame Detector
        #if canImport(SplunkSlowFrameDetector)
            knownModules.append(SlowFrameDetector.self)
        #endif

        // Web View Instrumentation
        #if canImport(SplunkWebView)
            knownModules.append(WebViewInstrumentationInternal.self)
        #endif

        // Custom Tracking
        #if canImport(SplunkCustomTracking)
            knownModules.append(SplunkCustomTracking.CustomTracking.self)
        #endif

        return knownModules
    }
}
