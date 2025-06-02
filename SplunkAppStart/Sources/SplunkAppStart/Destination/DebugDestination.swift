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

internal import CiscoLogger
import Foundation
import SplunkCommon

/// Stores results for testing purposes and prints results.
class DebugDestination: AppStartDestination {

    // MARK: - Private

    // Stored app start
    var storedAppStart: AppStartSpanData?

    // Stored initialize
    var storedInitialize: AgentInitializeSpanData?

    // Internal Logger
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "AppStart")


    // MARK: - Sending

    func send(appStart: AppStartSpanData, agentInitialize: AgentInitializeSpanData?, sharedState: (any AgentSharedState)?) {
        storedAppStart = appStart
        storedInitialize = agentInitialize

        let appStartDuration = appStart.end.timeIntervalSince(appStart.start)

        logger.log(level: .info) {
            var string = """
            App start span:
                type: \(appStart.type),
                start: \(appStart.start),
                end: \(appStart.end),
                duration: \(String(format: "%.3lfms", appStartDuration * 1000.0)),
            """

            string += "\n\tEvents:\n"
            appStart.events?.forEach { event in
                let timeIntervalMs = event.timestamp.timeIntervalSince(appStart.start) * 1000.0
                string += String(format: "\t\t%@ +%.3lfms\n", event.name, timeIntervalMs)
            }

            return string
        }

        if let agentInitialize {
            let initializeDuration = agentInitialize.end.timeIntervalSince(agentInitialize.start)
            var configSettings = ""

            for configurationSetting in agentInitialize.configurationSettings {
                if configSettings.count > 0 {
                    configSettings.append(", ")
                }
                configSettings.append("\(configurationSetting.key): \(configurationSetting.value)")
            }

            let configSettingsText = configSettings

            logger.log(level: .info) {
                var string = """
                Initialize span:
                    start: \(agentInitialize.start),
                    end: \(agentInitialize.end),
                    duration: \(String(format: "%.3lfms", initializeDuration * 1000.0)),
                    config settings: \(configSettingsText)
                """

                string += "\n\tEvents:\n"
                agentInitialize.events?.forEach { event in
                    let timeIntervalMs = event.timestamp.timeIntervalSince(agentInitialize.start) * 1000.0
                    string += String(format: "\t\t%@ +%.3lfms\n", event.name, timeIntervalMs)
                }

                return string
            }
        }
    }
}
