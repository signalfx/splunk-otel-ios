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


// MARK: - ErrorEventMetadata

struct ErrorEventMetadata: ModuleEventMetadata {

    // MARK: - Properties

    let timestamp: Date
    let id: String
    let errorType: String

    // MARK: - Initialization

    init(timestamp: Date = Date(), errorType: String) {
        self.timestamp = timestamp
        self.id = UUID().uuidString
        self.errorType = errorType
    }
}


// MARK: - Equatable Conformance

extension ErrorEventMetadata: Equatable {
    static func == (lhs: ErrorEventMetadata, rhs: ErrorEventMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

