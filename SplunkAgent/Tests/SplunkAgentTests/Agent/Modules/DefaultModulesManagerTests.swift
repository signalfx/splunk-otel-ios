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
import SplunkSharedProtocols
import XCTest

final class DefaultModulesManagerTests: XCTestCase {

    // MARK: - Private

    private let modulesPool = TestModulesPool.self


    // MARK: - Basic logic

    func testInitialization() throws {
        // Perform initialization
        let modulesManager = try DefaultModulesManagerTestBuilder.build(for: modulesPool)


        // After initialization, the same number of modules
        // defined via AgentModulesPool should be initialized.
        let modulesCount = modulesManager.modules.count
        let poolCount = modulesPool.default.count

        // It should also be the right module types
        let modulesType: [any Module.Type] = modulesManager.modules.map { module in
            type(of: module)
        }


        XCTAssertEqual(poolCount, modulesCount)

        for moduleType in modulesType {
            let isInPool = modulesPool.default.contains {
                $0 == moduleType
            }

            XCTAssertTrue(isInPool)
        }
    }


    // MARK: - Business logic

    func testModuleConfiguration() throws {
        // Load raw configuration mock
        let rawConfiguration = try RawMockDataBuilder.build(mockFile: .remoteConfiguration)

        // Define local module configuration for one module
        let crashConfiguration = CrashReportsTestConfiguration(disableLocalProcessing: true)
        let moduleConfigurations = [crashConfiguration]

        // Perform initialization
        let modulesManager = try DefaultModulesManagerTestBuilder.build(
            rawConfiguration: rawConfiguration,
            moduleConfigurations: moduleConfigurations,
            for: modulesPool
        )


        // One of the modules defined by the pool (SessionReplay)
        // will not be initialized because the remote configuration disables it.
        let modulesCount = modulesManager.modules.count
        let poolCount = modulesPool.default.count

        // The SessionReplay module should not be initialized
        let isSessionReplayInitialized = modulesManager.modules.contains {
            type(of: $0) == SessionReplayTestModule.self
        }

        // The CrashReports module should have assigned both of configurations
        let crashReportsModule = modulesManager.module(ofType: CrashReportsTestModule.self)
        let moduleConfiguration = crashReportsModule?.configuration
        let remoteModuleConfiguration = crashReportsModule?.remoteConfiguration


        XCTAssertEqual(poolCount - 1, modulesCount)
        XCTAssertFalse(isSessionReplayInitialized)

        XCTAssertEqual(moduleConfiguration, crashConfiguration)
        XCTAssertNotNil(remoteModuleConfiguration)
    }

    func testModuleConnection() throws {
        // Load raw configuration mock
        let rawConfiguration = try RawMockDataBuilder.build(mockFile: .remoteConfiguration)

        // Perform initialization
        let modulesManager = try DefaultModulesManagerTestBuilder.build(
            rawConfiguration: rawConfiguration,
            for: modulesPool
        )


        // One of the modules defined by the pool (SessionReplay)
        // will not be initialized because the remote configuration disables it.
        //
        // We try to add this module later with `connect` method.
        let sessionReplayModule = SessionReplayTestModule()

        modulesManager.connect(
            modules: [sessionReplayModule],
            with: [],
            remoteConfigurations: []
        )

        // The SessionReplay module should be initialized
        let isSessionReplayInitialized = modulesManager.modules.contains {
            type(of: $0) == SessionReplayTestModule.self
        }


        // Re-Adding same module twice into managed modules is not allowed
        let anotherSessionReplayModule = SessionReplayTestModule()

        modulesManager.connect(
            modules: [anotherSessionReplayModule],
            with: [],
            remoteConfigurations: []
        )

        let addedSessionReplayModules = modulesManager.modules.filter { module in
            type(of: module) == SessionReplayTestModule.self
        } as? [SessionReplayTestModule]

        let managedSessionReplayModule = try XCTUnwrap(addedSessionReplayModules?.first)
        let isOriginalInstance = (sessionReplayModule === managedSessionReplayModule)


        XCTAssertTrue(isSessionReplayInitialized)
        XCTAssertEqual(addedSessionReplayModules?.count, 1)
        XCTAssertTrue(isOriginalInstance)
    }

    func testDataPublication() throws {
        // Perform initialization
        let modulesManager = try DefaultModulesManagerTestBuilder.buildDefault()

        // Get connected module
        let crashReportsModule = modulesManager.module(ofType: CrashReportsTestModule.self)


        let dataExpectation = expectation(description: "Data from module not be delivered.")

        // We simulate taking and deleting data from modules
        modulesManager.onModulePublish { metadata, data in
            // At this point we interested only for data from CrashReports module
            guard
                let metadata = metadata as? CrashReportsTestMetadata,
                let data = data as? CrashReportsTestData
            else {
                return
            }


            // The returned data matches the last data returned by the module
            let moduleData = crashReportsModule?.publishedData
            XCTAssertEqual(data, moduleData)
            XCTAssertEqual(metadata, crashReportsModule?.publishedMetadata)

            // After a request to delete data, the corresponding data should be deleted
            modulesManager.deleteModuleData(for: metadata)

            XCTAssertNil(crashReportsModule?.publishedData)
            XCTAssertNil(crashReportsModule?.publishedMetadata)

            dataExpectation.fulfill()
        }

        // We need to wait for data delivery
        waitForExpectations(timeout: 25, handler: nil)
    }
}
