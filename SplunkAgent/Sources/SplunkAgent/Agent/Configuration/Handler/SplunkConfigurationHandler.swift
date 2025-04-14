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

/// A default Splunk configuration handler. It is used as an in-place source for default module enablement until a proper remote configuration is implemented in the O11y backend.
final class SplunkConfigurationHandler: AgentConfigurationHandler {

    // MARK: - Raw configuration data

    /// Raw configuration data. This is a temporary source of thruth for default modules manager enablement and any configuration defaults.
    private let rawConfiguration = """
    {
        "configuration": {
            "mrum": {
                "enabled": true,
                "maxSessionLength": \(ConfigurationDefaults.maxSessionLength),
                "sessionTimeout": \(ConfigurationDefaults.sessionTimeout),
                "sessionReplay": {
                    "enabled": true
                },
                "crashReporting": {
                    "enabled": true
                },
                "networkTracing": {
                    "enabled": true
                },
                "slowFrameDetector": {
                    "enabled": true,
                    "slowFrameDetectorThresholdMilliseconds": 1000.0,
                    "frozenFrameDetectorThresholdMilliseconds": 5000.0
                },
                "appStart": {
                    "enabled": true
                }
            }
        }
    }
    """

    // MARK: - Configuration

    var configurationData: Data? {
        return rawConfiguration.data(using: .utf8)
    }

    let configuration: any AgentConfigurationProtocol


    // MARK: - Intialization

    init(for configuration: AgentConfigurationProtocol) {
        self.configuration = configuration
    }
}
