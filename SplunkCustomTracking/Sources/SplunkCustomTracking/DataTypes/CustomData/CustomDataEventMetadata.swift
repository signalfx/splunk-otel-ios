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



// TODO: - This is currently not used. Maybe not needed?


import Foundation
import SplunkSharedProtocols


// MARK: - CustomDataEventMetadata

struct CustomDataEventMetadata: ModuleEventMetadata {

    // MARK: - Properties

    let timestamp: Date
    let id: String
    let dataType: String
    let category: String // This might be the only reason to have this type... TBD

    // MARK: - Initialization

    init(timestamp: Date = Date(), dataType: String, category: String = "") {
        self.timestamp = timestamp
        self.id = UUID().uuidString
        self.dataType = dataType
        self.category = category
    }
}


// MARK: - Equatable Conformance

extension CustomDataEventMetadata: Equatable {
    static func == (lhs: CustomDataEventMetadata, rhs: CustomDataEventMetadata) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}
