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
internal import SplunkAppStart

extension SplunkRum {

    /// Reports agent initialization metrics.
    func reportAgentInitialization(start: Date, initializeEvents: [String: Date]) {
        guard let initialization = makeAgentInitialization(start: start, initializeEvents: initializeEvents) else {
            return
        }

        // Report initialize events to App Start module
        if let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self) {
            appStartModule.reportAgentInitialize(
                start: initialization.start,
                end: initialization.end,
                events: initialization.events,
                configurationSettings: initialization.configurationSettings
            )
        }
    }

    /// Collects the agent initialization interval, its events and configuration settings.
    ///
    /// Module initialization times are added as `<module>_initialized` events. Returns `nil`
    /// before the modules manager exists.
    func makeAgentInitialization(start: Date, initializeEvents: [String: Date]) -> AgentInitialization? {
        guard let modulesManager else {
            return nil
        }

        var initializeEvents = initializeEvents

        // Fetch modules initialization times from the Modules manager
        for (moduleName, time) in modulesManager.modulesInitializationTimes {
            let moduleName = "\(moduleName)_initialized"
            initializeEvents[moduleName] = time
        }

        return AgentInitialization(
            start: start,
            end: Date(),
            events: initializeEvents,
            configurationSettings: configurationSettings
        )
    }

    private var configurationSettings: [String: String] {
        var settings: [String: String] = [:]

        settings["enableDebugLogging"] = String(agentConfigurationHandler.configuration.enableDebugLogging)
        settings["sessionSamplingRate"] = String(agentConfigurationHandler.configuration.session.samplingRate)

        if let modulesConfigurations = modulesManager?.modulesConfigurationDescription {
            settings.merge(modulesConfigurations) { $1 }
        }

        return settings
    }
}
