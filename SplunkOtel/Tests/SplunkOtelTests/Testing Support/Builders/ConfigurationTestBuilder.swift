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

import CiscoRUM
import Foundation

final class ConfigurationTestBuilder {

    // MARK: - Static constants

    public static let endpointUrl = URL(string: "http://sampledomain.com/tenant")


    // MARK: - Basic builds

    public static func buildDefault() throws -> Configuration {
        // Default configuration for unit testing
        var configuration = Configuration(url: endpointUrl!)
        configuration.appName = "DevelApp (Tests)"
        configuration.appVersion = "1.0.0"

        return configuration
    }
}
