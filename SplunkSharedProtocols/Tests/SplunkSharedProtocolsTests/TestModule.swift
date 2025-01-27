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

@testable import SplunkSharedProtocols
import XCTest

// MARK: - Configuration, Metadata and Data

struct TestModuleConfiguration: ModuleConfiguration {}

public struct TestModuleRemoteConfiguration: RemoteModuleConfiguration {
    public var enabled = true

    public init?(from data: Data) {
        nil
    }
}

struct TestEventMetadata: ModuleEventMetadata {
    var timestamp = Date()
    let id: String
}

struct TestEventData: ModuleEventData {
    let value: String
}


// MARK: - Test Module

class TestModule: Module {

    // MARK: - Module types

    typealias Configuration = TestModuleConfiguration
    typealias RemoteConfiguration = TestModuleRemoteConfiguration

    typealias EventMetadata = TestEventMetadata
    typealias EventData = TestEventData


    // MARK: - Protocol compliance

    required init() {
        // Nothing to do...
    }

    func install(with configuration: (any ModuleConfiguration)?,
                 remoteConfiguration: (any RemoteModuleConfiguration)?) {
        // Nothing to do...
    }

    func onPublish(data block: @escaping (TestEventMetadata, TestEventData) -> Void) {
        subscriberReceive = block
    }

    func deleteData(for metadata: any ModuleEventMetadata) {
        let metadata = metadata as? EventMetadata
        XCTAssertEqual(metadata, publishedMetadata)
    }


    // MARK: - Implementation

    private var publishedMetadata: EventMetadata?
    private var publishedData: EventData?

    private var subscriberReceive: ((EventMetadata, EventData) -> Void)?

    func emit(metadata: EventMetadata, data: EventData) throws {
        publishedData = data
        publishedMetadata = metadata

        let subscriberReceive = try XCTUnwrap(subscriberReceive)

        subscriberReceive(metadata, data)
    }
}
