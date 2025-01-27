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

public struct SessionReplayTestConfiguration: ModuleConfiguration, Equatable {}

public struct SessionReplayTestRemoteConfiguration: RemoteModuleConfiguration, Equatable {

    // MARK: - Internal decoding

    struct SessionReplay: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let sessionReplay: SessionReplay
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Protocol compliance

    public var enabled = true

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.sessionReplay.enabled
    }
}


public struct SessionReplayTestMetadata: ModuleEventMetadata {

    // MARK: - Protocol compliance

    public let id: String
    public var timestamp = Date()
}

public struct SessionReplayTestData: ModuleEventData {

    // MARK: - Protocol compliance

    let value: String
}
