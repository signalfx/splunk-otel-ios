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

enum RawMockDataTestBuilderError: Error {
    case fileNotLocated
}

final class RawMockDataBuilder {

    // MARK: - Static constants

    enum FileName: String {

        // Remote configurations
        case remoteConfiguration = "RemoteConfiguration"
        case alternativeRemoteConfiguration = "AlternativeRemoteConfiguration"

        // API client
        case remoteError = "RemoteError"
    }


    // MARK: - Basic builds

    public static func build(mockFile: FileName) throws -> Data {
        let currentBundle = Bundle(for: self)
        let mockFilePath = currentBundle.path(forResource: mockFile.rawValue, ofType: "json")

        // File must exist
        guard let mockFilePath else {
            throw RawMockDataTestBuilderError.fileNotLocated
        }

        return try Data(contentsOf: URL(fileURLWithPath: mockFilePath))
    }
}
