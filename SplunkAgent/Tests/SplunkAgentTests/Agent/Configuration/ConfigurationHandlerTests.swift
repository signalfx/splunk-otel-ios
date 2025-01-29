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

@testable import SplunkAgent
import XCTest

class ConfigurationHandlerTests: XCTestCase {

    func testInternalStore() throws {
        let storeConfiguration = try RawMockDataBuilder.build(mockFile: .alternativeRemoteConfiguration)

        let storage = UserDefaultsStorage()
        storage.keysPrefix = "com.splunk.rum.test."
        try storage.update(storeConfiguration, forKey: ConfigurationHandler.configurationStoreKey)

        let defaultConfig = try ConfigurationTestBuilder.buildDefault()

        let configurationHandler = ConfigurationHandler(
            for: defaultConfig,
            apiClient: APIClientTestBuilder.buildError(),
            storage: storage
        )

        XCTAssertEqual(configurationHandler.configurationData, storeConfiguration)
        XCTAssertEqual(configurationHandler.configuration.maxSessionLength, 111)
    }

    func testApiLoadSuccess() throws {

        let expectation = XCTestExpectation(description: "Delayed execution")

        let storage = UserDefaultsStorage()
        storage.keysPrefix = "com.splunk.rum.test."

        let defaultConfig = try ConfigurationTestBuilder.buildDefault()
        let dataResponse = try RawMockDataBuilder.build(mockFile: .alternativeRemoteConfiguration)

        let configurationHandler = ConfigurationHandler(
            for: defaultConfig,
            apiClient: APIClientTestBuilder.build(with: "config", response: dataResponse),
            storage: storage
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            XCTAssertEqual(configurationHandler.configurationData, dataResponse)
            XCTAssertEqual(configurationHandler.configuration.maxSessionLength, 111)

            let storedData: Data? = try? storage.read(forKey: ConfigurationHandler.configurationStoreKey)
            XCTAssertEqual(storedData, dataResponse)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }
}
