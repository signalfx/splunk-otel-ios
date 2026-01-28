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
@testable import SplunkAgent

final class DefaultModulesManagerTestBuilder {

    // MARK: - Basic builds

    static func buildDefault() throws -> DefaultModulesManager {
        // Load raw configuration mock
        let rawConfiguration = try RawMockDataBuilder.build(mockFile: .remoteConfiguration)

        // We tests with dummy modules
        let modulesPool = TestModulesPool.self

        return try build(
            rawConfiguration: rawConfiguration,
            for: modulesPool
        )
    }

    static func build(
        rawConfiguration: Data? = nil,
        moduleConfigurations: [Any]? = nil,
        for pool: AgentModulesPool.Type
    ) throws -> DefaultModulesManager {

        // Build modules manager with preconfigured pool and configurations
        DefaultModulesManager(
            rawConfiguration: rawConfiguration,
            moduleConfigurations: moduleConfigurations,
            for: pool
        )
    }
}
