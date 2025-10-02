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
import OpenTelemetryApi
import SplunkAgent

extension MutableAttributes {

    // MARK: - Computed properties

    var attributesDictionary: [String: AttributeValueObjC] {
        let attributes: [String: AttributeValue] = getAll()
        var attributesDictionary: [String: AttributeValueObjC] = [:]

        // Map OpenTelemetry attributes to Objective-C
        for (key, value) in attributes {
            attributesDictionary[key] = AttributeValueObjC(with: value)
        }

        return attributesDictionary
    }


    // MARK: - Conversion init

    convenience init(with attributesDictionary: [String: AttributeValueObjC]) {
        // Map Objective-C dictionary to OpenTelemetry attributes
        let attributes: [String: AttributeValue] = attributesDictionary.reduce(into: [:]) { result, element in
            if let attributeValue = element.value.otelAttributeValue {
                result[element.key] = attributeValue
            }
        }

        self.init(dictionary: attributes)
    }
}
