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
import SplunkSharedProtocols


// MARK: - Remote Configuration

public struct CustomTrackingRemoteConfiguration: RemoteModuleConfiguration {


    // MARK: - Internal Decoding

    private struct Tracking: Decodable {
        let enabled: Bool
        let maxBufferSize: Int?
        let maxBufferAgeSeconds: Double?
    }

    private struct Configuration: Decodable {
        let tracking: Tracking
    }

    private struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Public Properties

    public var enabled: Bool
    public var maxBufferSize: Int?
    public var maxBufferAge: TimeInterval?


    // MARK: Initialization

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }
        self.enabled = root.configuration.tracking.enabled
        self.maxBufferSize = root.configuration.tracking.maxBufferSize
        self.maxBufferAge = root.configuration.tracking.maxBufferAgeSeconds.map { TimeInterval($0) }
    }
}
