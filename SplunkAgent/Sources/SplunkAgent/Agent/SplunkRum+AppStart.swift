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

import Foundation
internal import SplunkAppStart

extension SplunkRum {

    /// Reports agent initialization metrics
    func reportAgentInitialization(start: Date, initializeEvents: [String: Date]) {
        var initializeEvents = initializeEvents

        // Fetch modules initialization times from the Modules manager
        modulesManager?.modulesInitializationTimes.forEach { moduleName, time in
            let moduleName = "\(moduleName)_initialized"
            initializeEvents[moduleName] = time
        }

        // Report initialize events to App Start module
        if let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self) {
            appStartModule.reportAgentInitialize(
                start: start,
                end: Date(),
                events: initializeEvents,
                configurationSettings: configurationSettings
            )
        }
    }

    private var configurationSettings: [String: String] {
        var settings = [String: String]()

        settings["enableDebugLogging"] = String(agentConfigurationHandler.configuration.enableDebugLogging)
        settings["sessionSamplingRate"] = String(agentConfigurationHandler.configuration.sessionSamplingRate)

        if let modulesConfigurations = modulesManager?.modulesConfigurationDescription {
            settings.merge(modulesConfigurations) { $1 }
        }

        return settings
    }
}
