//
/*
Copyright 2026 Splunk Inc.

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

import SplunkCommon
import SplunkLifecycle
import XCTest

final class LifecycleModuleTests: XCTestCase {

    // MARK: - Installation

    func testInstallUsesDefaultConfigurationWhenNoConfigurationIsProvided() {
        let module = Lifecycle()

        module.install(with: nil, remoteConfiguration: nil)

        XCTAssertTrue(module.configuration.isEnabled)
        XCTAssertEqual(module.configuration.allowedEvents, LifecycleAction.mainLifecycleEvents)
    }

    func testInstallStoresProvidedConfiguration() {
        let module = Lifecycle()
        let configuration = LifecycleConfiguration(
            isEnabled: false,
            allowedEvents: [.stopped]
        )

        module.install(with: configuration, remoteConfiguration: nil)

        XCTAssertFalse(module.configuration.isEnabled)
        XCTAssertEqual(module.configuration.allowedEvents, [.stopped])
    }

    func testRemoteConfigurationIsNotParsedUntilRemoteConfigContractExists() {
        let data = Data("{}".utf8)

        XCTAssertNil(LifecycleRemoteConfiguration(from: data))
    }
}
