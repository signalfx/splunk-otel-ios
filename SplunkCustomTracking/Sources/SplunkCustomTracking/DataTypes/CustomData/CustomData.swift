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


struct CustomData: SplunkTrackable {
    var typeName: String
    var attributes: [String: String]

    init(name: String, attributes: [String: String]) {
        self.typeName = name
        self.attributes = attributes
    }

    // Convert attributes to EventAttributeValue
    func toEventAttributes() -> [String: EventAttributeValue] {
        return attributes.mapValues { .string($0) }
    }
}
