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

internal import SplunkSharedProtocols

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


/// The class implements the default pool of available modules.
class DefaultModulesPool: AgentModulesPool {

    static var `default`: [any Module.Type] {
        var knownModules = [any Module.Type]()

        // Crash reports
        #if canImport(SplunkCrashReports)
            knownModules.append(CrashReports.self)
        #endif

        // Session Replay
        #if canImport(CiscoSessionReplay)
            knownModules.append(CiscoSessionReplay.SessionReplay.self)
        #endif

        // Network Instrumentation
        #if canImport(SplunkNetwork)
            knownModules.append(NetworkInstrumentation.self)
        #endif

        // Network Instrumentation
        #if canImport(SplunkSlowFrameDetector)
            knownModules.append(SlowFrameDetector.self)
        #endif

        return knownModules
    }
}
