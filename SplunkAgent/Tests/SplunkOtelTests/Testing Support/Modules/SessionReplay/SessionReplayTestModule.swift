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
import SplunkSharedProtocols

/// A dummy module skeleton for testing logic around modules.
class SessionReplayTestModule {

    // MARK: - Private

    private var subscriberReceive: ((SessionReplayTestMetadata, SessionReplayTestData) -> Void)?
    private var moduleInitialized = false


    // MARK: - Public

    var dataGenerationInterval: Double = 5

    private(set) var configuration: SessionReplayTestConfiguration?
    private(set) var remoteConfiguration: SessionReplayTestRemoteConfiguration?

    private(set) var publishedMetadata: SessionReplayTestMetadata?
    private(set) var publishedData: SessionReplayTestData?


    // MARK: - Initialization

    required init() {
        // Start a perpetual random data generator
        _ = Task {
            repeat {
                if moduleInitialized {
                    emitRandomData()
                }

                let sleepInterval = UInt64(dataGenerationInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepInterval)
            } while !Task.isCancelled
        }
    }


    // MARK: - Implementation

    func emitRandomData() {
        let metadata = SessionReplayTestMetadata(id: .uniqueIdentifier())

        let value = "Module: SessionReplayTestModule, Value: \(UUID().uuidString)"
        let data = SessionReplayTestData(value: value)

        // We keep the latest data for test evaluation
        publishedMetadata = metadata
        publishedData = data

        // Emit some random Metadata and Data
        emit(metadata: metadata, data: data)
    }

    func emit(metadata: SessionReplayTestMetadata, data: SessionReplayTestData) {
        subscriberReceive?(metadata, data)
    }
}


// MARK: - Module conformation

extension SessionReplayTestModule: Module {

    // MARK: - Module types

    typealias Configuration = SessionReplayTestConfiguration
    typealias RemoteConfiguration = SessionReplayTestRemoteConfiguration

    typealias EventMetadata = SessionReplayTestMetadata
    typealias EventData = SessionReplayTestData


    // MARK: - Protocol compliance

    func install(with configuration: (any ModuleConfiguration)?,
                 remoteConfiguration: (any RemoteModuleConfiguration)?) {

        // The configurations obtained are stored for later evaluation
        self.configuration = configuration as? SessionReplayTestConfiguration
        self.remoteConfiguration = remoteConfiguration as? SessionReplayTestRemoteConfiguration

        // We can start generating data
        moduleInitialized = true
    }

    func onPublish(data block: @escaping (SessionReplayTestMetadata, SessionReplayTestData) -> Void) {
        subscriberReceive = block
    }

    func deleteData(for metadata: any ModuleEventMetadata) {
        let requestMetadata = metadata as? SessionReplayTestMetadata

        // Just linear delete for mimics functional internal logic
        if requestMetadata == publishedMetadata {
            publishedMetadata = nil
            publishedData = nil
        }
    }
}
