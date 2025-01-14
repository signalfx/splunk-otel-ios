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

@_implementationOnly import MRUMSharedProtocols

#if canImport(MRUMCrashReports)
    @_implementationOnly import MRUMCrashReports
#endif

#if canImport(MRUMNetwork)
    @_implementationOnly import MRUMNetwork
#endif

#if canImport(CiscoSessionReplay)
    @_implementationOnly import CiscoSessionReplay
    @_implementationOnly import MRUMSessionReplayProxy
#endif

#if canImport(MRUMSlowFrameDetector)
    @_implementationOnly import MRUMSlowFrameDetector
#endif


/// The class implements the default pool of available modules.
class DefaultModulesPool: AgentModulesPool {

    static var `default`: [any Module.Type] {
        var knownModules = [any Module.Type]()

        // Crash reports
        #if canImport(MRUMCrashReports)
            knownModules.append(CrashReports.self)
        #endif

        // Session Replay
        #if canImport(CiscoSessionReplay)
            knownModules.append(CiscoSessionReplay.SessionReplay.self)
        #endif

        // Network Instrumentation
        #if canImport(MRUMNetwork)
            knownModules.append(NetworkInstrumentation.self)
        #endif

        // Network Instrumentation
        #if canImport(MRUMSlowFrameDetector)
            knownModules.append(SlowFrameDetector.self)
        #endif

        return knownModules
    }
}
