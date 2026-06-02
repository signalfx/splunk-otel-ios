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
import XCTest

@testable import SplunkAgent

final class ConfigurationHandlerTests: XCTestCase {

    func testInternalStore() throws {
        let storeConfiguration = try RawMockDataBuilder.build(mockFile: .alternativeRemoteConfiguration)

        let storage = UserDefaultsStorage()
        storage.keysPrefix = "com.splunk.rum.test.testInternalStore."
        try storage.update(storeConfiguration, forKey: ConfigurationHandler.configurationStoreKey)

        let defaultConfig = try ConfigurationTestBuilder.buildDefault()
        let apiClient = try APIClientTestBuilder.buildError()

        let configurationHandler = ConfigurationHandler(
            for: defaultConfig,
            apiClient: apiClient,
            storage: storage
        )

        XCTAssertEqual(configurationHandler.configurationData, storeConfiguration)
        XCTAssertEqual(configurationHandler.configuration.maxSessionLength, 111)
    }

    func testApiLoadSuccess() throws {
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "testApiLoadSuccess")

        let dataResponse = try RawMockDataBuilder.build(mockFile: .alternativeRemoteConfiguration)

        try? storage.delete(forKey: ConfigurationHandler.configurationStoreKey)

        let defaultConfig = try ConfigurationTestBuilder.buildDefault()

        let apiClient = try APIClientTestBuilder.build(with: "config", response: dataResponse)

        let configurationHandler = ConfigurationHandler(
            for: defaultConfig,
            apiClient: apiClient,
            storage: storage
        )

        waitForRemoteConfiguration(
            configurationHandler,
            storage: storage,
            expectedData: dataResponse,
            expectedMaxSessionLength: 111
        )

        XCTAssertEqual(configurationHandler.configurationData, dataResponse)
        XCTAssertEqual(configurationHandler.configuration.maxSessionLength, 111)

        let storedData: Data? = try? storage.read(forKey: ConfigurationHandler.configurationStoreKey)
        XCTAssertEqual(storedData, dataResponse)
    }


    // MARK: - Private

    private func waitForRemoteConfiguration(
        _ configurationHandler: ConfigurationHandler,
        storage: KeyValueStorage,
        expectedData: Data,
        expectedMaxSessionLength: TimeInterval,
        timeout: TimeInterval = 5
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let storedData: Data? = try? storage.read(forKey: ConfigurationHandler.configurationStoreKey)

            if configurationHandler.configurationData == expectedData,
                configurationHandler.configuration.maxSessionLength == expectedMaxSessionLength,
                storedData == expectedData
            {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
