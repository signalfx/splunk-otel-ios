//
/*
Copyright 2026 Splunk Inc.

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

enum OTLPSessionReplayMetadata {

    // MARK: - Constants

    static let displayWireframe = "displayWireframe"
    private static let reactNativeVersion = "app.framework.rn.version"
    private static let flutterVersion = "app.framework.flutter.version"


    // MARK: - Utilities

    static func isHybridFramework(_ globalAttributes: [String: AttributeValue]) -> Bool {
        globalAttributes[reactNativeVersion] != nil || globalAttributes[flutterVersion] != nil
    }

    static func metadataByAddingDisplayWireframe(
        to metadata: String,
        globalAttributes: [String: AttributeValue]
    ) -> String? {
        guard
            isHybridFramework(globalAttributes),
            let metadataData = metadata.data(using: .utf8),
            var metadataObject = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            return nil
        }

        metadataObject[displayWireframe] = false

        guard
            JSONSerialization.isValidJSONObject(metadataObject),
            let updatedMetadataData = try? JSONSerialization.data(withJSONObject: metadataObject),
            let updatedMetadata = String(data: updatedMetadataData, encoding: .utf8)
        else {
            return nil
        }

        return updatedMetadata
    }
}
